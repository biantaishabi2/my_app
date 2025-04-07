defmodule MyAppWeb.FormLive.Submit do
  use MyAppWeb, :live_view
  require Logger # 确保 Logger 被引入

  alias MyApp.Forms
  alias MyApp.Responses
  alias MyApp.Upload
  # Phoenix.LiveView已经在use MyAppWeb, :live_view中导入了
  # 不需要重复导入Phoenix.LiveView.Upload

  # 导入表单组件以使用自定义表单控件
  import MyAppWeb.FormComponents
  # 导入地区选择组件
  import MyAppWeb.Components.RegionSelect

  # 获取已发布的表单及其表单项和选项 - 与公开表单页面使用相同的方法
  defp get_published_form(id) do
    case Forms.get_form(id) do
      nil ->
        {:error, :not_found}

      %MyApp.Forms.Form{status: :published} = form ->
        # 预加载表单项和选项（已包含页面加载）
        form = Forms.preload_form_items_and_options(form)
        
        # --- 添加详细选项标签日志 (移动到 mount 函数中) ---
        # IO.puts("\\n===== Detailed Option Labels in Submit Mount =====")
        # ... (日志代码保持在原位，但可以在 mount 中访问 form)
        # IO.puts("===== Detailed Option Labels End =====\\n")
        # --- 详细选项标签日志结束 ---
        
        # 这个函数只负责获取和预加载表单，返回 {:ok, form}
        {:ok, form}

      %MyApp.Forms.Form{} ->
        {:error, :not_published}
    end
  end

  @impl true
  def mount(%{"id" => id}, session, socket) do
    Logger.info("Mounting FormLive.Submit for form ID: #{id}")
    
    form = Forms.get_form!(id)
    form_items = Forms.list_form_items_by_form_id(id)
    current_user = session["current_user"]

    # 获取已存在的上传文件信息 (使用Upload上下文)
    existing_files_map = Upload.get_files_for_form(form.id)
    Logger.info("[FormLive.Submit] Existing files map for form #{form.id}: #{inspect(existing_files_map)}")

    # 初始化上传配置 - 简化版本
    {socket, upload_names} = 
      form_items
      |> Enum.filter(&(&1.type == :file_upload))
      |> Enum.reduce({socket, %{}}, fn item, {acc_socket, acc_names} ->
          # 使用标准化方式创建上传引用名称 
          upload_name = String.to_atom("upload_#{item.id}")
          Logger.info("Allowing upload for item #{item.id} with name: #{upload_name}")
          
          # 使用更安全的默认值
          accepts = if Enum.empty?(item.allowed_extensions), do: :any, else: parse_allowed_extensions(item.allowed_extensions) 
          max_entries = if item.multiple_files, do: item.max_files || 3, else: 1
          max_size = (item.max_file_size || 5) * 1_000_000
          
          # 配置文件上传 - 添加进度处理回调
          updated_socket = allow_upload(acc_socket, upload_name, 
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
    socket = assign(socket, %{
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
  def handle_event("validate", %{"form_response" => response_params}, socket) do
    Logger.info("Handling validate event")
    changeset = MyApp.Responses.Response.changeset(%MyApp.Responses.Response{}, response_params)
    
    # 这里不需要手动处理 @uploads, LiveView 会自动验证
    {:noreply, assign(socket, changeset: changeset)}
  end

  @impl true
  def handle_event("submit_form", %{"form_response" => response_params}, socket) do
    Logger.info("Handling submit_form event")
    form_id = socket.assigns.form.id
    form_items = socket.assigns.form_items

    # 1. 处理文件上传 (在验证和保存之前)
    {socket, files_data, upload_errors} = handle_file_uploads(socket)

    # 如果上传出错, 直接返回错误
    if !Enum.empty?(upload_errors) do
      Logger.error("Upload errors encountered: #{inspect(upload_errors)}")
      # 可以考虑将错误添加到 changeset 或 flash 中显示给用户
      # 这里暂时只记录日志
      {:noreply, assign(socket, changeset: MyApp.Responses.Response.changeset(%MyApp.Responses.Response{}, response_params))}
    else

    # 2. 合并文件数据和表单数据
    all_data = Map.merge(response_params, files_data)

    # 3. 验证表单 (包含上传的文件信息)
    changeset = MyApp.Responses.Response.changeset(%MyApp.Responses.Response{}, all_data)
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
              Logger.info("Associating #{length(file_entries)} files for item #{item_id} with response #{response.id}")
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

  # ===========================================
  # 表单控件事件处理
  # ===========================================

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

  # ===========================================
  # 处理地区选择联动
  # ===========================================

  # 处理省份选择变化，使用纯 LiveView 方式
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
        _ -> nil
      end

    form_data = params["form"] || %{}
    province = form_data["#{field_id}_province"]
    
    Logger.info("Received handle_province_change event for field '#{field_id}' with province: #{inspect(province)}")

    # 更新表单状态
    form_state = socket.assigns.form_state || %{}
    
    # 清空相关的城市和区县选择
    updated_form_state = form_state
      |> Map.put("#{field_id}_province", province)
      |> Map.put("#{field_id}_city", nil)
      |> Map.put("#{field_id}_district", nil)
      |> Map.put(field_id, province) # 更新隐藏字段的值

    {:noreply, 
      socket
      |> assign(:form_state, updated_form_state)
      |> maybe_validate_form(updated_form_state)}
  end

  # 处理城市选择变化，使用纯 LiveView 方式
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
        _ -> nil
      end
    
    form_data = params["form"] || %{}
    city = form_data["#{field_id}_city"]
    
    # 从表单状态获取省份
    form_state = socket.assigns.form_state || %{}
    province = Map.get(form_state, "#{field_id}_province")
    
    Logger.info("Received handle_city_change event for field '#{field_id}' with province: #{inspect(province)} and city: #{inspect(city)}")
    
    # 更新表单状态
    # 清空区县选择，保留省份和城市选择
    updated_form_state = form_state
      |> Map.put("#{field_id}_city", city)
      |> Map.put("#{field_id}_district", nil)
      |> Map.put(field_id, "#{province}-#{city}") # 更新隐藏字段的值

    {:noreply, 
      socket
      |> assign(:form_state, updated_form_state)
      |> maybe_validate_form(updated_form_state)}
  end

  # 处理区县选择变化，使用纯 LiveView 方式
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
        _ -> nil
      end
    
    form_data = params["form"] || %{}
    district = form_data["#{field_id}_district"]
    
    Logger.info("Received handle_district_change event for field '#{field_id}' with district: #{inspect(district)}")
    
    # 更新表单状态
    form_state = socket.assigns.form_state || %{}
    
    # 获取已选择的省份和城市
    province = Map.get(form_state, "#{field_id}_province")
    city = Map.get(form_state, "#{field_id}_city")
    
    # 更新区县选择和完整的地区值
    updated_form_state = form_state
      |> Map.put("#{field_id}_district", district)
      |> Map.put(field_id, "#{province}-#{city}-#{district}") # 更新隐藏字段的值

    {:noreply, 
      socket
      |> assign(:form_state, updated_form_state)
      |> maybe_validate_form(updated_form_state)}
  end

  # 辅助函数：在表单状态更新后进行验证
  defp maybe_validate_form(socket, form_data) do
    # 执行基本验证（必填项）
    errors = validate_form_data(form_data, socket.assigns.items_map)
    assign(socket, :errors, errors)
  end

  # ===========================================
  # 文件上传事件处理
  # ===========================================

  # 处理文件上传事件 - 文件选择
  @impl true
  def handle_event("select_files", %{"field-id" => field_id}, socket) do
    # 从映射中获取上传引用，虽然这里不直接使用，但在前端JS中会用到
    _upload_ref = get_upload_ref(socket, field_id)

    # 触发文件选择对话框
    # 实际上，这个空实现会导致使用JS hooks中的代码来处理
    {:noreply, socket}
  end

  # 处理文件上传验证
  @impl true
  def handle_event("validate_upload", %{"field-id" => field_id}, socket) do
    # 从映射中获取上传引用，虽然这里不直接使用，但在前端JS中会用到
    _upload_ref = get_upload_ref(socket, field_id)

    # 验证上传
    {:noreply, socket}
  end

  # 取消上传
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

  # 删除已上传的文件
  @impl true
  def handle_event("remove_file", %{"field-id" => field_id, "file-index" => index_str}, socket) do
    index = String.to_integer(index_str)
    form_state = socket.assigns.form_state

    # 获取字段的当前文件列表
    field_files = Map.get(form_state, field_id, [])

    # 移除指定索引的文件
    updated_files = List.delete_at(field_files, index)

    # 更新状态
    updated_form_state = Map.put(form_state, field_id, updated_files)

    {:noreply, assign(socket, :form_state, updated_form_state)}
  end

  # 辅助函数

  # 构建表单项映射，以便于验证和显示
  defp build_items_map(items) do
    Enum.reduce(items, %{}, fn item, acc ->
      Map.put(acc, item.id, item)
    end)
  end

  # 验证表单数据
  defp validate_form_data(form_data, items_map) do
    Enum.reduce(items_map, %{}, fn {id, item}, errors ->
      # 获取对应项的值（可能是nil）
      value = Map.get(form_data || %{}, "#{id}", "")

      # 如果是必填项且值为空，则添加错误
      if item.required && (is_nil(value) || value == "") do
        Map.put(errors, id, "此字段为必填项")
      else
        # 特定类型的额外验证
        case item.type do
          :date when not is_nil(value) and value != "" ->
            cond do
              item.min_date && Date.compare(parse_date(value), parse_date(item.min_date)) == :lt ->
                Map.put(errors, id, "日期不能早于 #{item.min_date}")

              item.max_date && Date.compare(parse_date(value), parse_date(item.max_date)) == :gt ->
                Map.put(errors, id, "日期不能晚于 #{item.max_date}")

              true ->
                errors
            end

          :time when not is_nil(value) and value != "" ->
            cond do
              item.min_time && compare_times(value, item.min_time) == :lt ->
                Map.put(errors, id, "时间不能早于 #{item.min_time}")

              item.max_time && compare_times(value, item.max_time) == :gt ->
                Map.put(errors, id, "时间不能晚于 #{item.max_time}")

              true ->
                errors
            end

          :region when item.required ->
            region_parts = parse_region_value(value)
            region_level = item.region_level || 3

            cond do
              region_level >= 1 &&
                  (is_nil(region_parts[:province]) || region_parts[:province] == "") ->
                Map.put(errors, id, "请选择省/直辖市")

              region_level >= 2 && (is_nil(region_parts[:city]) || region_parts[:city] == "") ->
                Map.put(errors, id, "请选择市")

              region_level >= 3 &&
                  (is_nil(region_parts[:district]) || region_parts[:district] == "") ->
                Map.put(errors, id, "请选择区/县")

              true ->
                errors
            end

          :matrix when item.required ->
            # 验证矩阵题是否完整填写
            matrix_data = if is_map(value), do: value, else: %{}
            rows = item.matrix_rows || []

            if Enum.count(matrix_data) < length(rows) do
              Map.put(errors, id, "请完成所有行的选择")
            else
              errors
            end

          :file_upload when item.required ->
            # 检查文件上传是否满足要求
            uploaded_files = if is_list(value), do: value, else: []

            cond do
              Enum.empty?(uploaded_files) ->
                Map.put(errors, id, "请上传文件")

              item.multiple_files && length(uploaded_files) > item.max_files ->
                Map.put(errors, id, "最多只能上传 #{item.max_files} 个文件")

              item.multiple_files && item.max_files > 1 && length(uploaded_files) < 1 ->
                Map.put(errors, id, "请至少上传一个文件")

              true ->
                errors
            end

          :image_choice when item.required ->
            # 检查图片选择是否满足要求
            selected_images =
              cond do
                is_binary(value) && value != "" -> [value]
                is_list(value) && !Enum.empty?(value) -> value
                true -> []
              end

            if Enum.empty?(selected_images) do
              Map.put(errors, id, "请选择至少一张图片")
            else
              errors
            end

          _ ->
            errors
        end
      end
    end)
  end

  # 用于将地区选择的三个字段组合成一个值
  def combine_region_value(province, city, district) do
    case {province, city, district} do
      {nil, _, _} ->
        ""

      {_, nil, _} when not is_nil(province) ->
        province

      {_, _, nil} when not is_nil(province) and not is_nil(city) ->
        "#{province}-#{city}"

      {_, _, _} when not is_nil(province) and not is_nil(city) and not is_nil(district) ->
        "#{province}-#{city}-#{district}"

      _ ->
        ""
    end
  end

  # 解析组合的地区值
  defp parse_region_value(nil), do: %{province: nil, city: nil, district: nil}
  defp parse_region_value(""), do: %{province: nil, city: nil, district: nil}

  defp parse_region_value(value) when is_binary(value) do
    parts = String.split(value, "-", trim: true)

    case length(parts) do
      1 -> %{province: Enum.at(parts, 0), city: nil, district: nil}
      2 -> %{province: Enum.at(parts, 0), city: Enum.at(parts, 1), district: nil}
      3 -> %{province: Enum.at(parts, 0), city: Enum.at(parts, 1), district: Enum.at(parts, 2)}
      _ -> %{province: nil, city: nil, district: nil}
    end
  end

  # 获取上传引用 - 从映射中获取item_id对应的upload_name
  defp get_upload_ref(socket, field_id) do
    upload_names = socket.assigns.upload_names || %{}
    case Map.get(upload_names, field_id) do
      nil ->
        # 如果找不到映射，返回nil并记录警告，而不是抛出错误
        Logger.warning("Upload name not found for field_id: #{inspect(field_id)}. Using default.")
        nil
      upload_name ->
        # 找到了有效的 upload_name
        upload_name
    end
  end

  # 解析日期字符串为Date结构
  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil

  defp parse_date(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  # 比较两个时间字符串
  defp compare_times(time1, time2) do
    [h1, m1] = String.split(time1, ":")
    [h2, m2] = String.split(time2, ":")

    {h1, _} = Integer.parse(h1)
    {m1, _} = Integer.parse(m1)
    {h2, _} = Integer.parse(h2)
    {m2, _} = Integer.parse(m2)

    cond do
      h1 < h2 -> :lt
      h1 > h2 -> :gt
      m1 < m2 -> :lt
      m1 > m2 -> :gt
      true -> :eq
    end
  end

  # 辅助函数：获取矩阵单选题的值
  def get_matrix_value(form_state, field_id, row_idx) do
    case form_state do
      %{^field_id => matrix_data} when is_map(matrix_data) ->
        Map.get(matrix_data, to_string(row_idx))

      _ ->
        nil
    end
  end

  # 辅助函数：获取矩阵多选题的值
  def get_matrix_value(form_state, field_id, row_idx, col_idx) do
    case form_state do
      %{^field_id => matrix_data} when is_map(matrix_data) ->
        row_data = Map.get(matrix_data, to_string(row_idx), %{})
        Map.get(row_data, to_string(col_idx), false)

      _ ->
        false
    end
  end

  # 获取指定页面的表单项
  defp get_page_items(form, page) do
    if is_nil(page) do
      # 如果没有页面，返回所有表单项
      form.items
    else
      # 查找属于当前页面的所有表单项
      Enum.filter(form.items, fn item ->
        item.page_id == page.id
      end)
    end
  end

  # 初始化页面状态
  defp initialize_pages_status(pages) do
    Enum.reduce(0..(length(pages) - 1), %{}, fn index, acc ->
      Map.put(acc, index, :incomplete)
    end)
  end

  # 更新页面状态
  defp update_page_status(pages_status, index, status) do
    Map.put(pages_status, index, status)
  end

  # 验证特定页面的表单项
  defp validate_page_items(form_data, page_items, items_map) do
    # 获取页面上表单项的ID列表
    page_item_ids = Enum.map(page_items, & &1.id)

    # 从items_map中筛选出页面上的表单项
    page_items_map = Map.take(items_map, page_item_ids)

    # 只验证当前页面的表单项
    validate_form_data(form_data, page_items_map)
  end

  # --- 新增辅助函数 ---
  defp format_bytes(nil), do: "0 B"
  defp format_bytes(bytes) when is_integer(bytes) and bytes >= 0 do
    cond do
      bytes >= 1_000_000_000 ->
        "#{Float.round(bytes / 1_000_000_000, 1)} GB"
      bytes >= 1_000_000 ->
        "#{Float.round(bytes / 1_000_000, 1)} MB"
      bytes >= 1_000 ->
        "#{Float.round(bytes / 1_000, 1)} KB"
      true ->
        "#{bytes} B"
    end
  end
  defp format_bytes(_), do: "N/A" # 处理非预期输入

  defp translate_upload_error(:too_large), do: "文件过大"
  defp translate_upload_error(:not_accepted), do: "不支持的文件类型"
  defp translate_upload_error(:too_many_files), do: "文件数量超出限制"
  defp translate_upload_error(_), do: "上传出错" # 其他未知错误
  # --- 辅助函数结束 ---

  # --- 重新添加被删除的辅助函数 ---

  # 验证所有页面的数据
  defp validate_all_pages(form, form_data, items_map) do
    form.pages
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {page, idx}, all_errors ->
      # 获取此页面的表单项
      page_items = get_page_items(form, page)

      # 验证此页面的表单项
      page_errors = validate_page_items(form_data, page_items, items_map)

      # 将此页面的错误与页面索引关联起来
      if Enum.empty?(page_errors) do
        all_errors
      else
        Map.put(all_errors, idx, page_errors)
      end
    end)
  end

  # 查找第一个有错误的页面
  defp find_first_error_page(_form, all_errors) do
    # 按页面索引排序
    sorted_errors =
      all_errors
      |> Enum.sort_by(fn {idx, _} -> idx end)

    # 返回第一个有错误的页面 {index, errors}
    # 如果 all_errors 为空，此函数不应被调用（因为外部有检查）
    Enum.at(sorted_errors, 0, {0, %{}}) # 提供默认值以防万一
  end

  # 检查之前所有页面的状态
  defp check_previous_pages_status(pages_status, current_idx) do
    # 检查之前的页面，确保它们都标记为完成
    Enum.reduce(0..(current_idx - 1), pages_status, fn idx, acc ->
      case Map.get(acc, idx) do
        # 如果已完成，保持不变
        :complete -> acc
        # 否则，标记为完成 (假设向前移动意味着完成)
        _ -> Map.put(acc, idx, :complete)
      end
    end)
  end

  # 处理所有文件上传字段
  defp handle_file_uploads(socket) do
    # 获取所有文件上传字段的 upload_name
    upload_names = Map.keys(socket.assigns.uploads)
                   |> Enum.filter(&is_atom/1)
                   |> Enum.filter(&(Atom.to_string(&1) |> String.starts_with?("upload_")))
    
    Logger.info("Processing uploads for names: #{inspect(upload_names)}")
    
    # 处理每个上传字段
    {socket, files_data, errors} = 
      Enum.reduce(upload_names, {socket, %{}, []}, fn upload_name, {current_socket, data, upload_errors} ->
        item_id = upload_name 
                 |> Atom.to_string() 
                 |> String.replace_prefix("upload_", "") 
        
        form_id = current_socket.assigns.form.id
        
        # 获取已完成的上传
        completed_entries = consume_uploaded_entries(current_socket, upload_name, fn %{path: path}, entry ->
          # 构建目标目录
          dest_dir = Path.join([
            :code.priv_dir(:my_app), 
            "static", 
            "uploads", 
            to_string(form_id), 
            to_string(item_id)
          ])
          File.mkdir_p!(dest_dir)
          
          # 生成唯一文件名
          ext = Path.extname(entry.client_name)
          filename = "#{Ecto.UUID.generate()}#{ext}"
          dest_path = Path.join(dest_dir, filename)
          
          # 复制文件
          File.cp!(path, dest_path)
          
          # 构建文件信息
          file_info = %{
            original_filename: entry.client_name,
            filename: filename,
            size: entry.client_size,
            content_type: entry.client_type,
            path: "/uploads/#{form_id}/#{item_id}/#{filename}"
          }
          
          # 保存文件信息到数据库
          case Upload.save_uploaded_file(form_id, item_id, file_info) do
            {:ok, file} ->
              # 返回文件信息，包含ID以便后续关联
              Map.put(file_info, :id, file.id)
              |> Map.put(:type, file_info.content_type) # 为了兼容旧代码，添加type字段
            {:error, changeset} ->
              Logger.error("Failed to save file record: #{inspect(changeset)}")
              # 保持原来的文件信息不变，但为了兼容旧代码，添加type字段
              Map.put(file_info, :type, file_info.content_type)
          end
        end)
        
        # 更新数据
        updated_data = Map.put(data, item_id, completed_entries)
        
        # 检查是否有错误
        entry_errors = current_socket.assigns.uploads[upload_name].errors
        updated_errors = upload_errors ++ entry_errors
        
        {current_socket, updated_data, updated_errors}
      end)
    
    {socket, files_data, errors}
  end

  # 新增：根据 ref 查找对应的 upload_name
  defp find_upload_name_by_ref(uploads_map, target_ref) do
    Enum.find_value(uploads_map, fn
      {_key, %Phoenix.LiveView.UploadConfig{entries: entries, name: name}} ->
        if Enum.any?(entries, &(&1.ref == target_ref)), do: name, else: nil
      _ -> nil
    end)
  end

  # 新增：将 upload_name (如 :upload_123) 转换为用于存储文件信息的 key (如 :uploaded_files_info_123)
  defp upload_name_to_info_key(upload_name) do
    String.to_atom("uploaded_files_info_" <> (Atom.to_string(upload_name) |> String.replace_prefix("upload_", "")))
  end
  
  # 新增：清理所有上传的文件信息 (提交成功后)
  defp clear_uploaded_files_info(socket) do
     Enum.reduce(Map.keys(socket.assigns), socket, fn key, acc_socket ->
       if Atom.to_string(key) |> String.starts_with?("uploaded_files_info_") do
         assign(acc_socket, key, [])
       else
         acc_socket
       end
     end)
  end
  # --- 重新添加结束 ---

  # 解析允许的文件扩展名
  defp parse_allowed_extensions(nil), do: :any
  defp parse_allowed_extensions([]), do: :any  # 添加对空列表的处理
  defp parse_allowed_extensions(extensions) when is_list(extensions) do
    # 确保每个扩展名都以点号开头
    Enum.map(extensions, fn ext ->
      ext = to_string(ext)
      if String.starts_with?(ext, "."), do: ext, else: "." <> ext
    end)
  end
  defp parse_allowed_extensions(_), do: :any
end
