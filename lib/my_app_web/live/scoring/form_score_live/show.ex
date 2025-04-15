defmodule MyAppWeb.Scoring.FormScoreLive.Show do
  use MyAppWeb, :live_view

  alias MyApp.Scoring
  alias MyApp.Scoring.FormScore
  alias MyAppWeb.NotificationComponent

  @impl true
  def mount(%{"form_id" => form_id}, _session, socket) do
    form = Scoring.get_form(form_id)
    form_score_config = Scoring.get_form_score_config(form_id)

    # 如果没有配置，创建一个默认配置
    form_score = form_score_config || %FormScore{
      form_id: form_id,
      total_score: 100,
      passing_score: 60,
      auto_score: true,
      score_visibility: :public
    }

    form_changeset = FormScore.changeset(form_score, %{})

    {:ok,
     socket
     |> assign(:form, form)
     |> assign(:form_id, form_id)
     |> assign(:form_score, form_score)
     |> assign(:form_changeset, form_changeset)
     |> assign(:page_title, "评分配置 - #{form.title}")
     |> assign(:has_rules, has_active_rules?(form_id))
     |> assign(:notification, nil)
     |> assign(:notification_type, nil)
     |> assign(:notification_timer, nil)}
  end

  @impl true
  def handle_event("validate", %{"form_score" => form_score_params}, socket) do
    form_changeset =
      socket.assigns.form_score
      |> FormScore.changeset(form_score_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form_changeset, form_changeset)}
  end

  @impl true
  def handle_event("save", %{"form_score" => form_score_params}, socket) do
    # 正确处理auto_score参数：表单提交"on"值需要转换为true
    form_score_params = form_score_params
    |> handle_checkbox_value("auto_score")

    # 直接调用setup_form_scoring，无需预验证
    case Scoring.setup_form_scoring(socket.assigns.form_id, form_score_params, socket.assigns.current_user) do
      {:ok, form_score} ->
        # 成功情况显示成功通知
        socket = NotificationComponent.notify(socket, "评分配置已保存成功", :info)
        {:noreply,
         socket
         |> assign(:form_score, form_score)
         |> assign(:form_changeset, FormScore.changeset(form_score, %{}))}

      {:error, %Ecto.Changeset{} = form_changeset} ->
        # 数据验证失败显示错误通知
        socket = NotificationComponent.notify(socket, "保存失败，请检查输入", :error)
        {:noreply, assign(socket, :form_changeset, form_changeset)}

      {:error, :unauthorized} ->
        # 权限错误显示相应通知
        socket = NotificationComponent.notify(socket, "您没有权限修改此表单的评分配置", :error)
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("go_to_rules", _, socket) do
    {:noreply, push_navigate(socket, to: ~p"/forms/#{socket.assigns.form_id}/scoring/rules")}
  end

  @impl true
  def handle_event("go_to_results", _, socket) do
    {:noreply, push_navigate(socket, to: ~p"/forms/#{socket.assigns.form_id}/scoring/results")}
  end

  # 处理复选框值转换：将"on"转换为true，缺失值转换为false
  defp handle_checkbox_value(params, field) do
    case Map.get(params, field) do
      "on" -> Map.put(params, field, true)
      nil -> Map.put(params, field, false)
      val -> Map.put(params, field, val)
    end
  end

  # 检查表单是否有活跃的评分规则
  defp has_active_rules?(form_id) do
    form_id
    |> Scoring.get_score_rules_for_form()
    |> Enum.any?(& &1.is_active)
  end

  # 处理通知组件的清除消息
  @impl true
  def handle_info(:clear_notification, socket) do
    {:noreply,
     socket
     |> assign(:notification, nil)
     |> assign(:notification_timer, nil)}
  end
end
