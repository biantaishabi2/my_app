defmodule MyAppWeb.FormLive.Statistics do
  use MyAppWeb, :live_view

  alias MyApp.Forms
  alias MyApp.Responses.GroupedStatistics

  @impl true
  def mount(%{"id" => form_id}, _session, socket) do
    # 获取表单和属性列表
    case Forms.get_form(form_id) do
      nil ->
        {:ok, socket |> put_flash(:error, "表单不存在") |> redirect(to: ~p"/forms")}

      form ->
        # 获取表单的回答者属性设置
        respondent_attributes = form.respondent_attributes || []

        {:ok,
         socket
         |> assign(:form, form)
         |> assign(:form_id, form_id)
         |> assign(:respondent_attributes, respondent_attributes)
         |> assign(:selected_attribute_id, nil)
         |> assign(:selected_attribute_label, nil)
         |> assign(:grouped_statistics, nil)
         |> assign(:loading, false)
         |> assign(:has_no_attributes, Enum.empty?(respondent_attributes))
         |> assign(:has_no_responses, false)}
    end
  end

  @impl true
  def handle_event("select_attribute", %{"attribute_id" => attribute_id}, socket) do
    form_id = socket.assigns.form_id

    # 查找属性标签
    attribute =
      Enum.find(socket.assigns.respondent_attributes, fn attr ->
        attr_id = Map.get(attr, :id) || Map.get(attr, "id")
        attr_id == attribute_id
      end)

    attribute_label =
      if attribute,
        do: Map.get(attribute, :label) || Map.get(attribute, "label"),
        else: attribute_id

    # 标记加载状态
    socket = assign(socket, :loading, true)

    # 获取分组统计数据
    case GroupedStatistics.get_grouped_statistics(form_id, attribute_id) do
      {:ok, stats} ->
        has_no_responses =
          Enum.empty?(stats) || Enum.all?(stats, fn group -> group.count == 0 end)

        {:noreply,
         socket
         |> assign(:loading, false)
         |> assign(:selected_attribute_id, attribute_id)
         |> assign(:selected_attribute_label, attribute_label)
         |> assign(:grouped_statistics, stats)
         |> assign(:has_no_responses, has_no_responses)}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:loading, false)
         |> put_flash(:error, "获取统计数据失败: #{reason}")}
    end
  end

  @impl true
  def handle_event("export_grouped_statistics", %{"attribute_id" => attribute_id}, socket) do
    form_id = socket.assigns.form_id

    # 导出分组统计数据
    case GroupedStatistics.export_statistics_by_attribute(form_id, attribute_id) do
      {:ok, csv_data} ->
        {:noreply,
         socket
         |> put_flash(:info, "导出成功")
         |> push_event("download", %{
           filename: "grouped_statistics_#{form_id}_by_#{attribute_id}.csv",
           content: csv_data
         })}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "导出失败: #{reason}")}
    end
  end

  # 获取属性类型的显示名称
  defp humanize_attribute_type("text"), do: "文本"
  defp humanize_attribute_type("email"), do: "邮箱"
  defp humanize_attribute_type("phone"), do: "电话"
  defp humanize_attribute_type("select"), do: "下拉选择"
  defp humanize_attribute_type("date"), do: "日期"
  defp humanize_attribute_type(type) when is_binary(type), do: type
  defp humanize_attribute_type(_), do: "未知类型"
end
