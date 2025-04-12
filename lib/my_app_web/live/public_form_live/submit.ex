defmodule MyAppWeb.PublicFormLive.Submit do
  use MyAppWeb, :live_view
  import MyAppWeb.FormLive.ItemRendererComponent

  alias MyApp.Forms
  alias MyApp.Forms.Form
  alias MyApp.Responses
  alias MyApp.FormLogic

  # LiveView上传功能在LiveView模块中

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    # 获取表单（仅已发布的表单）
    case get_published_form(id) do
      {:ok, form} ->
        # 初始化表单数据和错误
        form_data = %{}
        page_index = 0

        # 初始化表单页面
        pages = form.pages

        # 获取当前页面
        current_page = if Enum.empty?(pages), do: nil, else: Enum.at(pages, page_index)

        # 获取当前页面的表单项
        current_page_items =
          if current_page do
            form.items
            |> Enum.filter(fn item -> item.page_id == current_page.id end)
            |> Enum.sort_by(& &1.order)
          else
            form.items |> Enum.sort_by(& &1.order)
          end

        # 初始化socket
        socket =
          socket
          |> assign(:form, form)
          |> assign(:pages, pages)
          |> assign(:page_index, page_index)
          |> assign(:total_pages, length(pages))
          |> assign(:current_page, current_page)
          |> assign(:current_page_items, current_page_items)
          |> assign(:form_data, form_data)
          |> assign(:errors, %{})
          |> assign(:page_title, "填写表单 - #{form.title}")
          |> assign(:respondent_info, %{"name" => "", "email" => ""})

        # 初始化文件上传配置
        socket =
          Enum.reduce(form.items, socket, fn item, acc ->
            if item.type == :file_upload do
              # 每个文件上传控件都有自己的上传配置
              max_files_value = if item.multiple_files, do: item.max_files || 1, else: 1
              # 确保 accept 参数总是有值，不能为空列表
              allowed_extensions =
                item.allowed_extensions || [".jpg", ".jpeg", ".png", ".pdf", ".doc", ".docx"]

              allowed_extensions =
                if Enum.empty?(allowed_extensions),
                  do: [".jpg", ".jpeg", ".png", ".pdf", ".doc", ".docx"],
                  else: allowed_extensions

              # 为每个文件上传控件注册一个上传配置
              # 使用固定前缀加序号的方式来命名上传配置，避免创建过多的atom
              upload_index = System.unique_integer([:positive])
              upload_name = :"file_upload_#{upload_index}"

              # 在socket中存储item_id到upload_name的映射，以便后续使用
              upload_names = Map.get(acc.assigns, :upload_names, %{})
              acc = assign(acc, :upload_names, Map.put(upload_names, item.id, upload_name))

              # 注册上传配置 - 直接传递参数而不是用map
              Phoenix.LiveView.allow_upload(acc, upload_name,
                max_entries: max_files_value,
                max_file_size: (item.max_file_size || 5) * 1024 * 1024,
                accept: allowed_extensions
              )
            else
              acc
            end
          end)

        {:ok, socket}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "表单不存在或未发布")
         |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def handle_event(
        "save",
        %{"form_data" => form_data, "respondent_info" => respondent_info},
        socket
      ) do
    # 从socket获取数据
    form = socket.assigns.form

    # 合并表单数据
    updated_form_data = Map.merge(socket.assigns.form_data, form_data)

    # 验证当前页面
    current_page_items = socket.assigns.current_page_items
    errors = validate_form_data(current_page_items, updated_form_data, form)

    if Enum.empty?(errors) do
      # 保存数据并前进到下一页或提交
      socket =
        socket
        |> assign(:form_data, updated_form_data)
        |> assign(:respondent_info, respondent_info)
        |> assign(:errors, %{})

      # 检查是否为最后一页
      is_last_page = socket.assigns.page_index == socket.assigns.total_pages - 1

      if is_last_page do
        # 提交表单
        case submit_form_response(socket) do
          {:ok, _response} ->
            {:noreply,
             socket
             |> put_flash(:info, "表单提交成功！")
             |> push_navigate(to: ~p"/public/forms/#{form.id}/success")}

          {:error, reason} ->
            {:noreply,
             socket
             |> put_flash(:error, "表单提交失败: #{error_message(reason)}")
             |> assign(:errors, errors_from_reason(reason, %{}))}
        end
      else
        # 进入下一页
        {:noreply, goto_next_page(socket)}
      end
    else
      # 返回错误
      {:noreply,
       socket
       |> assign(:errors, errors)
       |> assign(:form_data, updated_form_data)
       |> assign(:respondent_info, respondent_info)}
    end
  end

  @impl true
  def handle_event("prev_page", _params, socket) do
    {:noreply, goto_prev_page(socket)}
  end

  @impl true
  def handle_event(
        "next_page",
        %{"form_data" => form_data, "respondent_info" => respondent_info},
        socket
      ) do
    # 保存当前页数据
    updated_form_data = Map.merge(socket.assigns.form_data, form_data)

    # 验证当前页面
    current_page_items = socket.assigns.current_page_items
    errors = validate_form_data(current_page_items, updated_form_data, socket.assigns.form)

    if Enum.empty?(errors) do
      # 更新数据并前进到下一页
      socket =
        socket
        |> assign(:form_data, updated_form_data)
        |> assign(:respondent_info, respondent_info)
        |> assign(:errors, %{})

      {:noreply, goto_next_page(socket)}
    else
      # 返回错误
      {:noreply,
       socket
       |> assign(:errors, errors)
       |> assign(:form_data, updated_form_data)
       |> assign(:respondent_info, respondent_info)}
    end
  end

  @impl true
  def handle_event(
        "change",
        %{"form_data" => form_data, "respondent_info" => respondent_info},
        socket
      ) do
    # 合并表单数据
    updated_form_data = Map.merge(socket.assigns.form_data, form_data)

    # 更新socket
    {:noreply,
     socket
     |> assign(:form_data, updated_form_data)
     |> assign(:respondent_info, respondent_info)}
  end

  @impl true
  def handle_event("validate", %{"_target" => [_ref]}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    # 取消特定的文件上传
    {upload_name, _entry_ref} =
      ref
      |> String.split("-", parts: 2)
      |> then(fn [name, ref] -> {String.to_existing_atom(name), ref} end)

    {:noreply, Phoenix.LiveView.cancel_upload(socket, upload_name, ref)}
  end

  # 获取已发布的表单及其表单项和选项
  defp get_published_form(id) do
    case Forms.get_form(id) do
      nil ->
        {:error, :not_found}

      %Form{status: :published} = form ->
        # 预加载表单项和选项（已包含页面加载）
        form = Forms.preload_form_items_and_options(form)

        # 如果没有页面，创建一个默认页面
        form =
          if Enum.empty?(form.pages) do
            # 在内存中创建一个虚拟页面，不保存到数据库
            %{form | pages: [%{id: "default", title: "默认页面", order: 1}]}
          else
            form
          end

        {:ok, form}

      %Form{} ->
        {:error, :not_found}
    end
  end

  # 提交表单响应
  defp submit_form_response(socket) do
    form = socket.assigns.form
    form_data = socket.assigns.form_data
    respondent_info = socket.assigns.respondent_info

    # 过滤掉辅助字段（如地区选择的辅助字段）
    filtered_form_data =
      form_data
      |> Enum.filter(fn {key, _value} ->
        # 过滤掉以下模式的键
        not (is_binary(key) and
               (String.ends_with?(key, "_province") or
                  String.ends_with?(key, "_city") or
                  String.ends_with?(key, "_district")))
      end)
      |> Enum.into(%{})

    # 调用Responses上下文创建响应
    Responses.create_response(form.id, filtered_form_data, respondent_info)
  end

  # 验证表单数据
  defp validate_form_data(items, form_data, _form) do
    items
    |> Enum.filter(fn item ->
      # 检查条件可见性
      is_visible =
        case item.visibility_condition do
          nil ->
            true

          condition ->
            FormLogic.evaluate_condition(condition, form_data)
        end

      # 检查条件必填
      is_required =
        if item.required do
          case item.required_condition do
            nil ->
              true

            condition ->
              FormLogic.evaluate_condition(condition, form_data)
          end
        else
          false
        end

      # 只验证可见且必填的项目
      is_visible && is_required && is_empty_value?(item, form_data)
    end)
    |> Enum.map(fn item -> {item.id, "此项为必填项"} end)
    |> Enum.into(%{})
  end

  # 检查表单项值是否为空
  defp is_empty_value?(item, form_data) do
    value = Map.get(form_data, item.id, nil)

    case item.type do
      :checkbox ->
        is_nil(value) || (is_list(value) && Enum.empty?(value))

      _ ->
        is_nil(value) || value == ""
    end
  end

  # 转到下一页
  defp goto_next_page(socket) do
    current_index = socket.assigns.page_index
    total_pages = socket.assigns.total_pages

    if current_index < total_pages - 1 do
      # 计算新页索引
      new_index = current_index + 1

      # 获取新页面和对应的表单项
      new_page = Enum.at(socket.assigns.pages, new_index)

      # 获取当前页面的表单项
      new_page_items =
        socket.assigns.form.items
        |> Enum.filter(fn item -> item.page_id == new_page.id end)
        |> Enum.sort_by(& &1.order)

      # 更新socket
      socket
      |> assign(:page_index, new_index)
      |> assign(:current_page, new_page)
      |> assign(:current_page_items, new_page_items)
      |> assign(:errors, %{})
    else
      # 已经是最后一页，不变
      socket
    end
  end

  # 转到上一页
  defp goto_prev_page(socket) do
    current_index = socket.assigns.page_index

    if current_index > 0 do
      # 计算新页索引
      new_index = current_index - 1

      # 获取新页面和对应的表单项
      new_page = Enum.at(socket.assigns.pages, new_index)

      # 获取当前页面的表单项
      new_page_items =
        socket.assigns.form.items
        |> Enum.filter(fn item -> item.page_id == new_page.id end)
        |> Enum.sort_by(& &1.order)

      # 更新socket
      socket
      |> assign(:page_index, new_index)
      |> assign(:current_page, new_page)
      |> assign(:current_page_items, new_page_items)
      |> assign(:errors, %{})
    else
      # 已经是第一页，不变
      socket
    end
  end

  # 错误消息转换
  defp error_message(:validation_failed), do: "表单验证失败，请检查所有必填项"
  defp error_message(:invalid_answer), do: "表单回答无效，请检查填写内容"
  defp error_message(:not_published), do: "表单未发布，无法提交"
  defp error_message(:not_found), do: "表单不存在"
  defp error_message({:invalid_answer, _item_id}), do: "表单中存在无效答案"
  defp error_message(_), do: "提交过程中发生错误"

  # 从错误原因转换为表单错误
  defp errors_from_reason({:invalid_answer, item_id}, errors) do
    Map.put(errors, item_id, "此选项的回答无效")
  end

  defp errors_from_reason(_, errors), do: errors
end
