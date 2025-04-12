defmodule MyAppWeb.FormLive.Submit do
  use MyAppWeb, :live_view
  # 确保 Logger 被引入
  require Logger

  alias MyApp.Forms
  alias MyApp.Responses
  alias MyApp.Upload
  # Phoenix.LiveView已经在use MyAppWeb, :live_view中导入了
  # 不需要重复导入Phoenix.LiveView.Upload

  # 导入表单组件以使用自定义表单控件
  import MyAppWeb.FormComponents
  # 导入地区选择组件

  # 获取已发布的表单及其表单项和选项 - 与公开表单页面使用相同的方法

  @impl true
  def mount(%{"id" => id}, session, socket) do
    Logger.info("Mounting FormLive.Submit for form ID: #{id}")

    form = Forms.get_form!(id)
    form_items = Forms.list_form_items_by_form_id(id)
    current_user = session["current_user"]

    # 获取已存在的上传文件信息 (使用Upload上下文)
    existing_files_map = Upload.get_files_for_form(form.id)

    Logger.info(
      "[FormLive.Submit] Existing files map for form #{form.id}: #{inspect(existing_files_map)}"
    )

    # 初始化上传配置 - 简化版本
    {socket, upload_names} =
      form_items
      |> Enum.filter(&(&1.type == :file_upload))
      |> Enum.reduce({socket, %{}}, fn item, {acc_socket, acc_names} ->
        # 使用标准化方式创建上传引用名称
        upload_name = String.to_atom("upload_#{item.id}")
        Logger.info("Allowing upload for item #{item.id} with name: #{upload_name}")

        # 使用更安全的默认值
        accepts =
          if Enum.empty?(item.allowed_extensions),
            do: :any,
            else: parse_allowed_extensions(item.allowed_extensions)

        max_entries = if item.multiple_files, do: item.max_files || 3, else: 1
        max_size = (item.max_file_size || 5) * 1_000_000

        # 配置文件上传 - 添加进度处理回调
        updated_socket =
          allow_upload(acc_socket, upload_name,
            accept: accepts,
            max_entries: max_entries,
            max_file_size: max_size,
            auto_upload: true
          )

        # 添加到名称映射
        updated_names = Map.put(acc_names, item.id, upload_name)

        {updated_socket, updated_names}
      end)

    # 获取当前页面的表单项（第一页或默认所有项目）
    current_page = List.first(form.pages || [])
    page_items = get_page_items(form, current_page)
    current_page_idx = 0

    # 构建表单项映射，便于后续验证和查询
    items_map = build_items_map(form_items)

    # 初始化基本 assigns
    socket =
      assign(socket, %{
        current_step: 1,
        current_page: current_page,
        current_page_idx: current_page_idx,
        pages_status: initialize_pages_status(form.pages || []),
        form: form,
        form_items: form_items,
        page_items: page_items,
        form_data: %{},
        form_state: %{},
        upload_names: upload_names,
        items_map: items_map,
        changeset: MyApp.Responses.Response.changeset(%MyApp.Responses.Response{}, %{}),
        current_user: current_user,
        errors: %{},
        submitted: false,
        existing_files_map: existing_files_map
      })

    {:ok, socket, temporary_assigns: [form_items: []]}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    # 不再需要处理URL参数中的文件信息
    # 文件信息已经通过Upload上下文直接从数据库获取
    {:noreply, socket}
  end

  # ===========================================
  # 表单验证事件处理
  # ===========================================

  @impl true
  def handle_event("handle_province_change", params, socket) do
    # 从_target中获取实际的字段ID
    field_id =
      case params["_target"] do
        [_, field_name] when is_binary(field_name) ->
          # 从字段名中提取field_id (例如 "022eb894-9eeb-429d-b5d7-6683a2e35864_province")
          field_name
          |> String.split("_province")
          |> List.first()

        _ ->
          nil
      end

    form_data = params["form"] || %{}
    province = form_data["#{field_id}_province"]

    Logger.info(
      "Received handle_province_change event for field '#{field_id}' with province: #{inspect(province)}"
    )

    # 获取城市列表
    cities = MyApp.Regions.get_cities(province)

    # 更新 socket assigns
    {:noreply,
      socket
      |> assign(:province_field_id, field_id)
      |> assign(:province, province)
      |> assign(:cities, cities)
      |> assign(:districts, [])
    }
  end
  
  @impl true
  def handle_event("handle_city_change", params, socket) do
    # 从_target中获取实际的字段ID
    field_id =
      case params["_target"] do
        [_, field_name] when is_binary(field_name) ->
          # 从字段名中提取field_id (例如 "022eb894-9eeb-429d-b5d7-6683a2e35864_city")
          field_name
          |> String.split("_city")
          |> List.first()

        _ ->
          nil
      end

    form_data = params["form"] || %{}
    city = form_data["#{field_id}_city"]

    # 从表单状态获取省份
    form_state = socket.assigns.form_state || %{}
    province = Map.get(form_state, "#{field_id}_province")

    Logger.info(
      "Received handle_city_change event for field '#{field_id}' with province: #{inspect(province)} and city: #{inspect(city)}"
    )

    # 更新表单状态
    # 清空区县选择，保留省份和城市选择
    updated_form_state =
      form_state
      |> Map.put("#{field_id}_city", city)
      |> Map.put("#{field_id}_district", nil)
      # 更新隐藏字段的值
      |> Map.put(field_id, "#{province}-#{city}")

    {:noreply,
     socket
     |> assign(:form_state, updated_form_state)
     |> maybe_validate_form(updated_form_state)}
  end
  
  @impl true
  def handle_event("handle_district_change", params, socket) do
    # 从_target中获取实际的字段ID
    field_id =
      case params["_target"] do
        [_, field_name] when is_binary(field_name) ->
          # 从字段名中提取field_id (例如 "022eb894-9eeb-429d-b5d7-6683a2e35864_district")
          field_name
          |> String.split("_district")
          |> List.first()

        _ ->
          nil
      end

    form_data = params["form"] || %{}
    district = form_data["#{field_id}_district"]

    # 从表单状态获取省份和城市
    form_state = socket.assigns.form_state || %{}
    province = Map.get(form_state, "#{field_id}_province")
    city = Map.get(form_state, "#{field_id}_city")

    Logger.info(
      "Received handle_district_change event for field '#{field_id}' with province: #{inspect(province)}, city: #{inspect(city)}, district: #{inspect(district)}"
    )

    # 更新表单状态
    updated_form_state =
      form_state
      |> Map.put("#{field_id}_district", district)
      # 更新隐藏字段的值
      |> Map.put(field_id, "#{province}-#{city}-#{district}")

    {:noreply,
     socket
     |> assign(:form_state, updated_form_state)
     |> maybe_validate_form(updated_form_state)}
  end

  @impl true
  def handle_event("validate", %{"form_response" => response_params}, socket) do
    Logger.info("Handling validate event")
    changeset = MyApp.Responses.Response.changeset(%MyApp.Responses.Response{}, response_params)

    # 这里不需要手动处理 @uploads, LiveView 会自动验证
    {:noreply, assign(socket, changeset: changeset)}
  end

  @impl true
  def handle_event("validate_upload", %{"field-id" => field_id}, socket) do
    # 从映射中获取上传引用，虽然这里不直接使用，但在前端JS中会用到
    _upload_ref = get_upload_ref(socket, field_id)

    # 验证上传
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    # 从 ref 中提取 upload_name
    upload_name = find_upload_name_by_ref(socket.assigns.uploads, ref)

    if upload_name do
      Logger.info("Canceling upload for ref: #{ref} under name: #{upload_name}")
      {:noreply, cancel_upload(socket, upload_name, ref)}
    else
      Logger.warning("Could not find upload name for cancel ref: #{ref}")
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete_file", %{"field-id" => field_id, "file-id" => file_id}, socket) do
    Logger.info("Handling delete_file event for field #{field_id}, file #{file_id}")

    # 从 socket.assigns.existing_files_map 中移除对应的文件
    existing_files_map = socket.assigns.existing_files_map
    field_files = Map.get(existing_files_map, field_id, [])

    updated_field_files = Enum.reject(field_files, fn file -> file["id"] == file_id end)

    # 更新 socket.assigns.existing_files_map
    updated_files_map =
      if Enum.empty?(updated_field_files) do
        Map.delete(existing_files_map, field_id)
      else
        Map.put(existing_files_map, field_id, updated_field_files)
      end

    # 实际删除文件（异步）
    Task.start(fn ->
      case Upload.delete_file(file_id) do
        {:ok, _} ->
          Logger.info("Successfully deleted file #{file_id}")
        {:error, reason} ->
          Logger.error("Failed to delete file #{file_id}: #{inspect(reason)}")
      end
    end)

    {:noreply, assign(socket, :existing_files_map, updated_files_map)}
  end
  
  @impl true
  def handle_event("submit_form", %{"form_response" => response_params}, socket) do
    Logger.info("Handling submit_form event")
    form_id = socket.assigns.form.id
    _form_items = socket.assigns.form_items

    # 1. 处理文件上传 (在验证和保存之前)
    {socket, files_data, upload_errors} = handle_file_uploads(socket)

    # 如果上传出错, 直接返回错误
    if !Enum.empty?(upload_errors) do
      Logger.error("Upload errors encountered: #{inspect(upload_errors)}")
      # 可以考虑将错误添加到 changeset 或 flash 中显示给用户
      # 这里暂时只记录日志
      {:noreply,
       assign(socket,
         changeset:
           MyApp.Responses.Response.changeset(%MyApp.Responses.Response{}, response_params)
       )}
    else
      # 2. 合并文件数据和表单数据
      all_data = Map.merge(response_params, files_data)

      # 3. 验证表单 (包含上传的文件信息)
      changeset =
        MyApp.Responses.Response.changeset(%MyApp.Responses.Response{}, all_data)
        |> Map.put(:action, :validate)

      if changeset.valid? do
        Logger.info("Form is valid, attempting to save.")
        # 4. 保存数据
        case Responses.create_response(all_data, form_id, socket.assigns.current_user.id) do
          {:ok, response} ->
            Logger.info("Response created successfully: #{response.id}")

            # 关联文件到响应
            Enum.each(files_data, fn {item_id, file_entries} ->
              # 对于每个文件上传字段，关联其文件到响应
              if !Enum.empty?(file_entries) do
                Logger.info(
                  "Associating #{length(file_entries)} files for item #{item_id} with response #{response.id}"
                )

                Upload.associate_files_with_response(form_id, item_id, response.id)
              end
            end)

            # 清理上传的文件信息
            socket = clear_uploaded_files_info(socket)

            {:noreply,
             socket
             |> assign(submitted: true)
             |> put_flash(:info, "表单提交成功!")}

          {:error, error_changeset} ->
            Logger.error("Error creating response: #{inspect(error_changeset)}")
            {:noreply, assign(socket, changeset: error_changeset)}
        end
      else
        Logger.warning("Form validation failed: #{inspect(changeset.errors)}")
        {:noreply, assign(socket, changeset: changeset)}
      end
    end
  end

  # 表单控件事件处理
  @impl true
  def handle_event("select_files", %{"field-id" => field_id}, socket) do
    # 从映射中获取上传引用，虽然这里不直接使用，但在前端JS中会用到
    _upload_ref = get_upload_ref(socket, field_id)

    # 触发文件选择对话框
    # 实际上，这个空实现会导致使用JS hooks中的代码来处理
    {:noreply, socket}
  end
  
  @impl true
  def handle_event("set_rating", %{"field-id" => field_id, "rating" => rating}, socket) do
    # 更新评分字段的值
    form_state = socket.assigns.form_state || %{}
    updated_form_state = Map.put(form_state, field_id, rating)

    # 重新验证
    errors = validate_form_data(updated_form_state, socket.assigns.items_map)

    {:noreply,
     socket
     |> assign(:form_state, updated_form_state)
     |> assign(:errors, errors)}
  end
  
  @impl true
  def handle_event("matrix_change", %{"field-id" => field_id, "row-idx" => row_idx, "col-idx" => col_idx} = params, socket) do
    form_state = socket.assigns.form_state || %{}
    item = Map.get(socket.assigns.items_map, field_id)
    
    # 根据矩阵类型处理
    updated_form_state = if item && item.matrix_type == :multiple do
      # 多选矩阵 - 每个单元格是复选框
      cell_value = params["value"] == "true"
      
      # 更新特定单元格的值
      path = [field_id, row_idx, col_idx]
      deep_put_in(form_state, path, cell_value)
    else
      # 单选矩阵 - 每行只能选一个
      path = [field_id, row_idx]
      deep_put_in(form_state, path, col_idx)
    end
    
    # 重新验证并更新状态
    {:noreply, 
     socket
     |> assign(:form_state, updated_form_state)
     |> maybe_validate_form(updated_form_state)}
  end

  # ===========================================
  # 分页导航事件处理
  # ===========================================

  @impl true
  def handle_event("next_page", _params, socket) do
    form = socket.assigns.form
    current_idx = socket.assigns.current_page_idx
    pages = form.pages || []

    # 验证当前页面
    current_page = Enum.at(pages, current_idx)
    page_items = get_page_items(form, current_page)

    page_errors =
      validate_page_items(socket.assigns.form_state, page_items, socket.assigns.items_map)

    if Enum.empty?(page_errors) do
      # 如果没有错误，切换到下一页
      next_idx = min(current_idx + 1, length(pages) - 1)
      next_page = Enum.at(pages, next_idx)

      # 获取下一页的表单项
      next_page_items = get_page_items(form, next_page)

      # 更新当前页面的状态为完成
      pages_status = update_page_status(socket.assigns.pages_status, current_idx, :complete)

      # 如果下一页是最后一页，检查之前所有页面是否都已完成
      updated_status =
        if next_idx == length(pages) - 1 do
          # 检查前面所有页面的状态
          check_previous_pages_status(pages_status, next_idx)
        else
          pages_status
        end

      # 保存表单状态以确保数据在页面导航时保留
      form_state = socket.assigns.form_state || %{}

      {:noreply,
       socket
       |> assign(:current_page_idx, next_idx)
       |> assign(:current_page, next_page)
       |> assign(:page_items, next_page_items)
       |> assign(:pages_status, updated_status)
       # 确保表单状态被保留
       |> assign(:form_state, form_state)
       # 清除错误信息
       |> assign(:errors, %{})}
    else
      # 如果有错误，保持在当前页面并显示错误
      {:noreply,
       socket
       |> assign(:errors, page_errors)
       |> put_flash(:error, "请完成当前页面上的所有必填项")}
    end
  end

  @impl true
  def handle_event("prev_page", _params, socket) do
    form = socket.assigns.form
    current_idx = socket.assigns.current_page_idx
    pages = form.pages || []

    # 切换到上一页
    prev_idx = max(current_idx - 1, 0)
    prev_page = Enum.at(pages, prev_idx)

    # 获取上一页的表单项
    prev_page_items = get_page_items(form, prev_page)

    # 保存表单状态以确保数据在页面导航时保留
    form_state = socket.assigns.form_state || %{}

    {:noreply,
     socket
     |> assign(:current_page_idx, prev_idx)
     |> assign(:current_page, prev_page)
     |> assign(:page_items, prev_page_items)
     # 确保表单状态被保留
     |> assign(:form_state, form_state)}
  end

  @impl true
  def handle_event("jump_to_page", %{"index" => index_str}, socket) do
    form = socket.assigns.form
    pages = form.pages || []
    current_idx = socket.assigns.current_page_idx

    # 转换为整数
    {target_idx, _} = Integer.parse(index_str)

    # 确保索引在有效范围内
    valid_index = max(0, min(target_idx, length(pages) - 1))

    # 如果要跳转到后面的页面，需要验证当前页面
    if valid_index > current_idx do
      # 验证当前页面
      current_page = Enum.at(pages, current_idx)
      page_items = get_page_items(form, current_page)

      page_errors =
        validate_page_items(socket.assigns.form_state, page_items, socket.assigns.items_map)

      if not Enum.empty?(page_errors) do
        # 当前页面有错误，无法跳转到后面的页面
        {:noreply,
         socket
         |> assign(:errors, page_errors)
         |> put_flash(:error, "请先完成当前页面上的所有必填项")}
      else
        # 当前页面验证通过，可以跳转
        process_page_jump(socket, form, valid_index)
      end
    else
      # 跳转到前面的页面，无需验证
      process_page_jump(socket, form, valid_index)
    end
  end

  # 处理页面跳转
  defp process_page_jump(socket, form, target_idx) do
    pages = form.pages || []
    current_idx = socket.assigns.current_page_idx
    target_page = Enum.at(pages, target_idx)

    # 获取目标页面的表单项
    target_page_items = get_page_items(form, target_page)

    # 如果是向前跳转，将当前页面标记为已完成
    updated_status =
      if target_idx > current_idx do
        # 将当前页面标记为完成
        update_page_status(socket.assigns.pages_status, current_idx, :complete)
      else
        socket.assigns.pages_status
      end

    # 保存表单状态以确保数据在页面导航时保留
    form_state = socket.assigns.form_state || %{}

    {:noreply,
     socket
     |> assign(:current_page_idx, target_idx)
     |> assign(:current_page, target_page)
     |> assign(:page_items, target_page_items)
     |> assign(:pages_status, updated_status)
     # 确保表单状态被保留
     |> assign(:form_state, form_state)
     # 清除错误信息
     |> assign(:errors, %{})}
  end


  # 辅助函数：在表单状态更新后进行验证
  defp maybe_validate_form(socket, form_data) do
    # 执行基本验证（必填项）
    errors = validate_form_data(form_data, socket.assigns.items_map)
    assign(socket, :errors, errors)
  end

  # ===========================================
  # 文件上传辅助函数
  # ===========================================

  # ===========================================
  # 辅助函数
  # ===========================================

  # 用于解析允许的文件扩展名列表
  defp parse_allowed_extensions(extensions) when is_list(extensions) do
    Enum.map(extensions, fn ext ->
      # 确保每个扩展名都以点号开头
      if String.starts_with?(ext, "."), do: ext, else: ".#{ext}"
    end)
  end

  defp parse_allowed_extensions(_), do: :any

  # 获取页面的表单项
  defp get_page_items(form, page) do
    if page do
      # 获取当前页面的表单项
      page.items || []
    else
      # 如果没有页面，返回所有表单项
      form.items || []
    end
  end

  # 初始化页面状态
  defp initialize_pages_status(pages) do
    pages
    |> Enum.with_index()
    |> Enum.map(fn {_page, idx} ->
      status = if idx == 0, do: :active, else: :pending
      {idx, status}
    end)
    |> Map.new()
  end

  # 更新页面状态
  defp update_page_status(pages_status, page_idx, new_status) do
    Map.put(pages_status, page_idx, new_status)
  end

  # 检查之前页面的状态
  defp check_previous_pages_status(pages_status, current_idx) do
    Enum.reduce(0..(current_idx - 1), pages_status, fn idx, acc ->
      case Map.get(acc, idx) do
        :pending -> Map.put(acc, idx, :complete)
        _ -> acc
      end
    end)
  end

  # 构建表单项映射
  defp build_items_map(form_items) do
    form_items
    |> Enum.reduce(%{}, fn item, acc ->
      Map.put(acc, item.id, item)
    end)
  end

  # 验证页面上的所有必填项
  defp validate_page_items(form_state, page_items, items_map) do
    # 过滤出当前页面上的必填项
    required_items =
      page_items
      |> Enum.filter(fn item ->
        # 检查表单项是否一定必填
        item.required && is_field_visible(form_state, item, items_map)
      end)

    # 验证每个必填项
    required_items
    |> Enum.reduce(%{}, fn item, errors ->
      if is_field_empty?(form_state, item) do
        Map.put(errors, item.id, "此字段不能为空")
      else
        errors
      end
    end)
  end

  # 判断字段是否为空
  defp is_field_empty?(form_state, item) do
    value = Map.get(form_state, item.id)

    cond do
      # 如果值是nil或空字符串，视为空
      is_nil(value) || value == "" ->
        true

      # 如果是多选类型，检查是否有选择
      item.type in [:checkbox, :image_choice] && item.selection_type == :multiple ->
        is_list(value) && Enum.empty?(value)

      # 如果是单选类型，检查是否为nil
      item.type in [:radio, :dropdown, :image_choice] ->
        is_nil(value) || value == ""

      # 如果是区域选择，检查是否为空或格式不完整
      item.type == :region && item.region_type == :province_city_district ->
        is_nil(value) || !String.contains?(value, "-")

      # 其他情况默认为非空
      true ->
        false
    end
  end

  # 判断字段是否可见（基于条件逻辑）
  defp is_field_visible(form_state, item, items_map) do
    # 如果没有可见性条件，则始终可见
    if is_nil(item.visibility_condition) do
      true
    else
      # 解析条件逻辑
      condition = Jason.decode!(item.visibility_condition)
      # 评估条件
      evaluate_condition(condition, form_state, items_map)
    end
  end

  # 处理复合条件
  defp evaluate_condition(%{"type" => "compound", "operator" => operator, "conditions" => conditions}, form_state, items_map) do
    results = Enum.map(conditions, &evaluate_condition(&1, form_state, items_map))

    case operator do
      "and" -> Enum.all?(results)
      "or" -> Enum.any?(results)
      _ -> false
    end
  end

  # 处理简单条件
  defp evaluate_condition(%{"type" => "simple", "source_item_id" => source_id, "operator" => operator, "value" => target}, form_state, items_map) do
    # 获取源字段的值
    source_value = Map.get(form_state, source_id)
    # 获取源字段的类型
    source_type = get_in(items_map, [source_id, :type])

    # 根据操作符和字段类型评估条件
    evaluate_operator(operator, source_value, target, source_type)
  end

  # 处理其他情况
  defp evaluate_condition(_, _, _), do: true

  # 定义不同操作符的评估逻辑
  defp evaluate_operator("equals", source, target, _), do: source == target
  defp evaluate_operator("not_equals", source, target, _), do: source != target
  defp evaluate_operator("contains", nil, _, _), do: false
  defp evaluate_operator("contains", source, target, _) when is_list(source), do: target in source
  defp evaluate_operator("contains", source, target, _), do: String.contains?(source, target)
  defp evaluate_operator("not_contains", source, target, type), do: !evaluate_operator("contains", source, target, type)
  defp evaluate_operator("greater_than", source, target, _) when is_binary(source) and is_binary(target) do
    case {Float.parse(source), Float.parse(target)} do
      {{source_num, _}, {target_num, _}} -> source_num > target_num
      _ -> false
    end
  end
  defp evaluate_operator("greater_than", source, target, _) when is_number(source) and is_binary(target) do
    case Float.parse(target) do
      {target_num, _} -> source > target_num
      _ -> false
    end
  end
  defp evaluate_operator("greater_than", source, target, _) when is_binary(source) and is_number(target) do
    case Float.parse(source) do
      {source_num, _} -> source_num > target
      _ -> false
    end
  end
  defp evaluate_operator("greater_than", source, target, _) when is_number(source) and is_number(target), do: source > target
  defp evaluate_operator("less_than", source, target, _) when is_binary(source) and is_binary(target) do
    case {Float.parse(source), Float.parse(target)} do
      {{source_num, _}, {target_num, _}} -> source_num < target_num
      _ -> false
    end
  end
  defp evaluate_operator("less_than", source, target, _) when is_number(source) and is_binary(target) do
    case Float.parse(target) do
      {target_num, _} -> source < target_num
      _ -> false
    end
  end
  defp evaluate_operator("less_than", source, target, _) when is_binary(source) and is_number(target) do
    case Float.parse(source) do
      {source_num, _} -> source_num < target
      _ -> false
    end
  end
  defp evaluate_operator("less_than", source, target, _) when is_number(source) and is_number(target), do: source < target
  defp evaluate_operator(_, _, _, _), do: false

  # 基础字段验证
  defp validate_form_data(form_data, items_map) do
    # 这里实现简单检查必填项
    items_map
    |> Enum.filter(fn {_, item} -> 
      item.required && is_field_visible(form_data, item, items_map)
    end)
    |> Enum.reduce(%{}, fn {id, item}, errors ->
      if is_field_empty?(form_data, item) do
        Map.put(errors, id, "此字段不能为空")
      else
        errors
      end
    end)
  end

  # 处理文件上传并返回文件数据
  defp handle_file_uploads(socket) do
    upload_names = socket.assigns.upload_names
    existing_files_map = socket.assigns.existing_files_map
    form_id = socket.assigns.form.id

    # 用于收集错误
    upload_errors = []

    # 处理每个文件上传字段
    {files_data, errors, updated_socket} =
      Enum.reduce(upload_names, {%{}, upload_errors, socket}, fn {item_id, upload_name}, {acc_data, acc_errors, acc_socket} ->
        try do
          uploaded_files = 
            consume_uploaded_entries(acc_socket, upload_name, fn %{path: path}, entry ->
              # 生成文件ID
              file_id = Ecto.UUID.generate()
              filename = "#{file_id}#{Path.extname(entry.client_name)}"
              
              # 确定目标路径 (确保目录存在)
              dest_dir = Path.join([:code.priv_dir(:my_app), "static", "uploads"])
              File.mkdir_p!(dest_dir)
              dest_path = Path.join(dest_dir, filename)
              
              # 复制上传的临时文件到目标位置
              File.cp!(path, dest_path)
              
              # 保存到数据库
              {:ok, file} = Upload.save_uploaded_file(form_id, item_id, %{
                id: file_id,
                original_filename: entry.client_name,
                filename: filename,
                path: "/uploads/#{filename}",
                content_type: entry.client_type,
                size: entry.client_size
              })
              
              # 返回处理结果
              %{
                "id" => file.id,
                "name" => entry.client_name,
                "path" => "/uploads/#{filename}",
                "size" => entry.client_size,
                "type" => entry.client_type
              }
            end)
          
          # 合并已有文件和新上传的文件
          existing_files = Map.get(existing_files_map, item_id, [])
          all_files = existing_files ++ uploaded_files
          
          # 只有在有文件时才添加到结果数据中
          updated_data = 
            if Enum.empty?(all_files) do
              acc_data
            else
              Map.put(acc_data, item_id, all_files)
            end
          
          {updated_data, acc_errors, acc_socket}
        catch
          kind, reason ->
            Logger.error("Error processing uploads for item #{item_id}: #{inspect(reason)}")
            stacktrace = __STACKTRACE__
            formatted_error = Exception.format(kind, reason, stacktrace)
            Logger.error("Stack trace: #{formatted_error}")
            
            # 添加到错误列表
            updated_errors = [%{item_id: item_id, error: "上传文件处理失败: #{inspect(reason)}"} | acc_errors]
            {acc_data, updated_errors, acc_socket}
        end
      end)

    {updated_socket, files_data, errors}
  end

  # 清理上传的文件信息
  defp clear_uploaded_files_info(socket) do
    # 清空 uploads 状态
    socket
  end

  # 通过引用查找上传名称
  defp find_upload_name_by_ref(uploads, ref) do
    Enum.find_value(uploads, fn {name, upload} ->
      if Enum.any?(upload.entries, &(&1.ref == ref)), do: name, else: nil
    end)
  end

  # 从上传名称映射中获取上传引用
  defp get_upload_ref(socket, field_id) do
    Map.get(socket.assigns.upload_names, field_id)
  end

  # 矩阵表单项辅助函数 - 获取单选矩阵值
  defp get_matrix_value(form_state, field_id, row_idx) do
    case get_in(form_state, [field_id, "#{row_idx}"]) do
      nil -> nil
      value -> value
    end
  end

  # 矩阵表单项辅助函数 - 获取多选矩阵值
  defp get_matrix_value(form_state, field_id, row_idx, col_idx) do
    case get_in(form_state, [field_id, "#{row_idx}", "#{col_idx}"]) do
      nil -> false
      "true" -> true
      true -> true
      _ -> false
    end
  end
  
  # 辅助函数 - 深度更新嵌套映射中的值
  defp deep_put_in(map, [key], value) do
    Map.put(map, key, value)
  end
  
  defp deep_put_in(map, [key | rest], value) do
    existing = Map.get(map, key, %{})
    Map.put(map, key, deep_put_in(existing, rest, value))
  end
end