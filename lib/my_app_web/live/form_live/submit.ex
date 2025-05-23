defmodule MyAppWeb.FormLive.Submit do
  use MyAppWeb, :live_view
  # 确保 Logger 被引入
  require Logger

  alias MyApp.Forms
  alias MyApp.Responses
  alias MyApp.Upload
  alias MyAppWeb.FormTemplateRenderer
  # Phoenix.LiveView已经在use MyAppWeb, :live_view中导入了
  # 不需要重复导入Phoenix.LiveView.Upload

  # 表单组件已通过模板渲染器使用
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

    # 加载表单模板
    form_template = FormTemplateRenderer.load_form_template(form)

    # --- 新增：在 mount 时就将模板逻辑合并到 form_items ---
    form_items_with_logic =
      if form_template && form_template.structure do
        template_structure = form_template.structure || []

        Enum.map(form_items, fn item ->
          template_item =
            Enum.find(template_structure, fn struct_item ->
              template_id = struct_item["id"] || struct_item[:id]
              to_string(template_id) == to_string(item.id)
            end)

          if template_item &&
               (Map.has_key?(template_item, "logic") || Map.has_key?(template_item, :logic)) do
            logic = template_item["logic"] || template_item[:logic]
            Logger.info("[Mount] Attaching logic to item #{item.id}: #{inspect(logic)}")
            # Add logic to the item struct
            Map.put(item, :logic, logic)
          else
            # Return item as is if no logic found
            item
          end
        end)
      else
        Logger.info("[Mount] No form template or structure found, using raw form items.")
        # No template, use raw items
        form_items
      end

    # --- 结束新增逻辑 ---

    Logger.info(
      "[FormLive.Submit] Existing files map for form #{form.id}: #{inspect(existing_files_map)}"
    )

    # 初始化上传配置 - 简化版本
    {socket, upload_names} =
      form_items_with_logic
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
    # 使用带有逻辑的 items 来获取页面项
    # Pass modified items
    page_items = get_page_items(%{form | items: form_items_with_logic}, current_page)
    current_page_idx = 0

    # 构建表单项映射，便于后续验证和查询 - 使用带有逻辑的 items
    # Build map from items with logic
    items_map = build_items_map(form_items_with_logic)

    # 初始化基本 assigns
    socket =
      assign(socket, %{
        current_step: 1,
        current_page: current_page,
        current_page_idx: current_page_idx,
        pages_status: initialize_pages_status(form.pages || []),
        form: form,
        form_template: form_template,
        # <--- Assign items WITH logic here
        form_items: form_items_with_logic,
        # Page items derived from items with logic
        page_items: page_items,
        form_data: %{},
        form_state: %{},
        upload_names: upload_names,
        # Map built from items with logic
        items_map: items_map,
        # 添加时间戳用于强制视图更新
        form_updated_at: System.system_time(:millisecond),
        changeset: MyApp.Responses.Response.changeset(%MyApp.Responses.Response{}, %{}),
        current_user: current_user,
        errors: %{},
        submitted: false,
        existing_files_map: existing_files_map,
        # 初始化跳转状态
        jump_state: %{active: false, target_id: nil},
        # 初始化通知组件状态
        notification: nil,
        notification_type: nil,
        notification_timer: nil
      })

    # Keep temporary assign as is
    {:ok, socket, temporary_assigns: [form_items: []]}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    # 不再需要处理URL参数中的文件信息
    # 文件信息已经通过Upload上下文直接从数据库获取
    
    # 订阅表单相关的PubSub主题
    if connected?(socket) do
      form_id = socket.assigns.form.id
      Phoenix.PubSub.subscribe(MyApp.PubSub, "form:#{form_id}")
    end
    
    {:noreply, socket}
  end
  
  # 处理PubSub通知消息
  @impl true
  def handle_info({:form_submitted, response_id}, socket) do
    # 可以在这里处理表单提交成功的通知
    # 例如更新页面状态或显示新的通知
    Logger.info("Received form submission notification for response: #{response_id}")
    {:noreply, socket}
  end
  
  # 处理通知组件的消息
  @impl true
  def handle_info(:clear_notification, socket) do
    {:noreply,
     socket
     |> assign(:notification, nil)
     |> assign(:notification_timer, nil)}
  end

  # ===========================================
  # 表单验证事件处理
  # ===========================================
  
  @impl true
  def handle_event("highlight_errors", %{"errors" => _errors}, socket) do
    # 直接传递错误信息到前端 (暂时未使用errors变量，添加下划线前缀)
    {:noreply, socket}
  end

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
     |> assign(:districts, [])}
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
    Logger.info("Handling validate event with form_response")
    changeset = MyApp.Responses.Response.changeset(%MyApp.Responses.Response{}, response_params)

    # 这里不需要手动处理 @uploads, LiveView 会自动验证
    {:noreply, assign(socket, changeset: changeset)}
  end


  # 保留此处理器作为后备，以确保兼容性
  @impl true
  def handle_event(
        "update_blank",
        %{"field" => field_id, "blank" => blank_idx, "value" => value},
        socket
      ) do
    blank_idx = String.to_integer(blank_idx)

    # 获取当前表单状态
    form_state = socket.assigns.form_state || %{}

    # 记录操作到日志
    Logger.info("通过旧方式更新填空题 #{field_id} 的第#{blank_idx}个空，值: #{value}")

    # 从表单状态中获取当前字段的值（应该是JSON格式的数组）
    current_values =
      case Map.get(form_state, field_id) do
        nil -> "[]"
        val when is_binary(val) -> val
        _ -> "[]"
      end

    # 解析JSON字符串为Elixir列表
    values_list =
      case Jason.decode(current_values) do
        {:ok, list} when is_list(list) -> list
        _ -> []
      end

    # 确保值列表长度足够
    padded_list =
      if length(values_list) <= blank_idx do
        values_list ++ List.duplicate("", blank_idx - length(values_list) + 1)
      else
        values_list
      end

    # 更新特定索引的值
    updated_list = List.replace_at(padded_list, blank_idx, value)

    # 将更新后的列表转换回JSON字符串
    updated_json = Jason.encode!(updated_list)

    # 更新表单状态
    form_state = Map.put(form_state, field_id, updated_json)
    
    # 记录更新后的状态
    Logger.info("填空题 #{field_id} 更新后的值: #{updated_json}")

    # 直接更新socket状态
    socket = assign(socket, :form_state, form_state)

    {:noreply, socket}
  end

  # 处理带有_target参数的update_blank事件
  @impl true
  def handle_event("update_blank", %{"_target" => _target} = params, socket) do
    Logger.info("收到不完整的update_blank事件: #{inspect(params)}")
    # 简单地返回socket，不做处理
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", params, socket) do
    # 通用验证处理
    Logger.info("Received validate event: #{inspect(params)}")
    
    # 获取当前表单状态 - 已存在的数据
    current_form_state = socket.assigns.form_state || %{}
    
    # 提取表单数据 - 支持不同格式的参数
    form_data = params["form_data"] || %{}
    
    # 处理填空题的特殊数据格式（每个空位单独提交的情况）
    updated_form_data = handle_fill_in_blank_values(form_data, current_form_state)
    
    # 合并到当前表单状态
    updated_form_state = Map.merge(current_form_state, updated_form_data)
    socket = assign(socket, :form_state, updated_form_state)
    
    # 查找目标字段ID (如果有)
    target_field_id = 
      case params["_target"] do
        ["form_data", item_id] when is_binary(item_id) -> item_id
        _ -> nil
      end
    
    if target_field_id do
      # 如果有特定字段，验证该字段
      item = Map.get(socket.assigns.items_map, target_field_id)
      
      if item && item.required && is_field_empty?(updated_form_state, item) do
        # 如果字段为必填且为空，显示错误
        Logger.info("Required field #{target_field_id} is empty, adding error")
        errors = Map.put(socket.assigns.errors || %{}, target_field_id, "此字段为必填项")
        {:noreply, assign(socket, :errors, errors)}
      else
        # 如果字段已填写或不是必填项，清除该字段的错误
        Logger.info("Field #{target_field_id} validated, clearing error")
        updated_errors = Map.drop(socket.assigns.errors || %{}, [target_field_id])
        {:noreply, assign(socket, :errors, updated_errors)}
      end
    else
      # 没有特定字段，只更新表单状态
      {:noreply, socket}
    end
  end
  
  # 处理填空题的值，将各个空位的值整合成JSON数组格式
  defp handle_fill_in_blank_values(form_data, current_form_state) do
    # 先找出所有是填空题空位的字段（形如：id_blank_0, id_blank_1, ...）
    blank_fields = form_data 
      |> Enum.filter(fn {key, _} -> 
        String.match?(key, ~r/^[a-f0-9-]+_blank_\d+$/)
      end)
    
    if Enum.empty?(blank_fields) do
      # 如果没有填空题字段，直接返回原始数据
      form_data
    else
      # 按主字段ID分组，整理成map结构： %{field_id => %{index => value}}
      blanks_by_field = Enum.reduce(blank_fields, %{}, fn {key, value}, acc ->
        [field_id, _blank, index_str] = String.split(key, "_", parts: 3)
        index = String.to_integer(index_str)
        
        field_blanks = Map.get(acc, field_id, %{})
        updated_field_blanks = Map.put(field_blanks, index, value)
        Map.put(acc, field_id, updated_field_blanks)
      end)
      
      # 为每个填空题字段创建或更新JSON数组
      updated_data = Enum.reduce(blanks_by_field, form_data, fn {field_id, blanks_map}, acc ->
        # 获取当前字段已有的JSON数据
        current_json = Map.get(current_form_state, field_id, "[]")
        
        # 解析现有的值数组
        current_values = case Jason.decode(current_json) do
          {:ok, list} when is_list(list) -> list
          _ -> []
        end
        
        # 更新数组，确保长度足够
        max_index = Enum.max(Map.keys(blanks_map))
        padded_list = if length(current_values) <= max_index do
          current_values ++ List.duplicate("", max_index - length(current_values) + 1)
        else
          current_values
        end
        
        # 用新值更新数组
        updated_list = Enum.reduce(blanks_map, padded_list, fn {index, value}, list ->
          List.replace_at(list, index, value)
        end)
        
        # 转换回JSON并放入结果
        updated_json = Jason.encode!(updated_list)
        Logger.info("Updated fill-in-blank field #{field_id} value: #{updated_json}")
        
        # 移除个别空位的键，只保留主字段JSON数据
        acc = Enum.reduce(blanks_map, acc, fn {index, _}, map ->
          Map.delete(map, "#{field_id}_blank_#{index}")
        end)
        
        # 添加整合后的JSON数据
        Map.put(acc, field_id, updated_json)
      end)
      
      updated_data
    end
  end

  
  @impl true
  def handle_event("validate_upload", %{"field-id" => field_id}, socket) do
    # 从映射中获取上传引用，虽然这里不直接使用，但在前端JS中会用到
    _upload_ref = get_upload_ref(socket, field_id)

    # 验证上传
    {:noreply, socket}
  end
  
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
  def handle_event(
        "matrix_change",
        %{"field-id" => field_id, "row-idx" => row_idx, "col-idx" => col_idx} = params,
        socket
      ) do
    form_state = socket.assigns.form_state || %{}
    item = Map.get(socket.assigns.items_map, field_id)

    # 根据矩阵类型处理
    updated_form_state =
      if item && item.matrix_type == :multiple do
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
      
      # 记录当前表单状态到日志以便调试
      Logger.info("[下一页] 保留表单状态: #{inspect(Map.keys(form_state))}, 当前页面项目: #{length(page_items)}")
      
      # 查找是否有填空题
      fill_in_blank_items = Enum.filter(page_items, fn item -> item.type == :fill_in_blank end)
      
      if !Enum.empty?(fill_in_blank_items) do
        Logger.info("[下一页] 当前页面包含#{length(fill_in_blank_items)}个填空题")
        Enum.each(fill_in_blank_items, fn item ->
          value = Map.get(form_state, item.id, "[]")
          Logger.info("[下一页] 填空题 #{item.id} 值: #{inspect(value)}")
        end)
      end

      # 先更新socket以保留表单状态
      socket = socket
        |> assign(:current_page_idx, next_idx)
        |> assign(:current_page, next_page)
        |> assign(:page_items, next_page_items)
        |> assign(:pages_status, updated_status)
        # 确保表单状态被保留 - 直接使用当前的表单状态
        |> assign(:form_state, form_state)
        # 清除错误信息
        |> assign(:errors, %{})
      
      {:noreply, socket}
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
    
    # 记录当前表单状态到日志以便调试
    Logger.info("[上一页] 保留表单状态: #{inspect(Map.keys(form_state))}")
    
    # 获取填空题状态
    current_page = Enum.at(pages, current_idx)
    current_page_items = get_page_items(form, current_page)
    fill_in_blank_items = Enum.filter(current_page_items, fn item -> item.type == :fill_in_blank end)
    
    if !Enum.empty?(fill_in_blank_items) do
      Logger.info("[上一页] 当前页面包含#{length(fill_in_blank_items)}个填空题")
      Enum.each(fill_in_blank_items, fn item ->
        value = Map.get(form_state, item.id, "[]")
        Logger.info("[上一页] 离开填空题 #{item.id} 值: #{inspect(value)}")
      end)
    end
    
    # 检查上一页是否含填空题
    prev_fill_in_blank_items = Enum.filter(prev_page_items, fn item -> item.type == :fill_in_blank end)
    if !Enum.empty?(prev_fill_in_blank_items) do
      Logger.info("[上一页] 目标页面包含#{length(prev_fill_in_blank_items)}个填空题")
      Enum.each(prev_fill_in_blank_items, fn item ->
        value = Map.get(form_state, item.id, "[]")
        Logger.info("[上一页] 返回到填空题 #{item.id} 值: #{inspect(value)}")
      end)
    end

    # 先构建新socket以便保留表单状态
    socket = socket
      |> assign(:current_page_idx, prev_idx)
      |> assign(:current_page, prev_page)
      |> assign(:page_items, prev_page_items)
      # 确保表单状态被保留 - 直接使用现有的表单状态
      |> assign(:form_state, form_state)
      
    {:noreply, socket}
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


  # 处理表单提交事件 - 完全依赖后端验证
  @impl true
  def handle_event("submit_form", params, socket) do
    Logger.info("Handling submit_form event: #{inspect(params)}")

    # 从socket.assigns中构建表单响应数据
    form_state = socket.assigns.form_state || %{}
    
    # 合并params中可能的表单数据
    form_data = params["form_data"] || %{}
    updated_form_state = Map.merge(form_state, form_data)
    
    # 更新socket以保留表单状态
    socket = assign(socket, :form_state, updated_form_state)
    
    form_id = socket.assigns.form.id
    current_user = socket.assigns.current_user
    user_id = if current_user, do: current_user.id, else: nil

    # 执行全面验证 - 检查所有必填项
    required_items = 
      socket.assigns.form_items
      |> Enum.filter(fn item -> item.required end)
    
    # 检查是否有必填项未填
    missing_items = Enum.filter(required_items, fn item ->
      is_field_empty?(updated_form_state, item)
    end)
    
    if Enum.empty?(missing_items) do
      # 所有必填项都已填写，构造完整的响应参数并继续提交
      Logger.info("All required fields filled, proceeding with submission")
      
      # 将表单状态转换为Responses模块期望的格式
      # 每个答案需要包装成 %{"value" => value} 格式
      wrapped_answers = 
        updated_form_state
        |> Enum.map(fn {key, value} -> 
          {key, %{"value" => value}}
        end)
        |> Enum.into(%{})
      
      # 添加基本响应信息
      response_params = Map.merge(wrapped_answers, %{
        "form_id" => form_id,
        "submitted_at" => DateTime.utc_now(),
        "user_id" => user_id
      })

      Logger.info("Prepared response params: #{inspect(Map.keys(response_params))}")

      # 处理文件上传(如果有)
      {socket, _files_data, upload_errors} = handle_file_uploads(socket)
      
      # 检查上传错误
      if !Enum.empty?(upload_errors) do
        # 有文件上传错误
        Logger.error("Upload errors encountered: #{inspect(upload_errors)}")
        errors = Enum.reduce(upload_errors, %{}, fn %{item_id: id, error: msg}, acc ->
          Map.put(acc, id, "文件上传失败: #{msg}")
        end)
        
        # 使用通知组件显示错误
        socket = MyAppWeb.NotificationComponent.notify(socket, "文件上传失败，请检查错误信息", :error)
        
        {:noreply, 
          socket
          |> assign(:errors, errors)}
      else
        # 正常提交处理流程
        case Responses.create_response(form_id, wrapped_answers, %{"user_id" => user_id}) do
          {:ok, response} ->
            Logger.info("Response created successfully: #{response.id}")

            # 关联文件到响应
            associate_files_with_response(updated_form_state, form_id, response.id)
            
            # 使用PubSub通知其他组件表单已提交
            Phoenix.PubSub.broadcast(
              MyApp.PubSub,
              "form:#{form_id}",
              {:form_submitted, response.id}
            )
            
            # 成功提交 - 重定向到专门的成功页面
            {:noreply,
             socket
             |> assign(submitted: true)
             |> push_navigate(to: ~p"/forms/#{form_id}/success")}

          {:error, error_changeset} ->
            Logger.error("Error creating response: #{inspect(error_changeset)}")
            
            # 提取changeset中的错误信息
            errors = format_changeset_errors(error_changeset)
            
            # 使用通知组件显示错误
            socket = MyAppWeb.NotificationComponent.notify(socket, "表单提交失败，请检查错误信息", :error)
            
            # 返回错误信息，但保留表单状态
            {:noreply, 
              socket 
              |> assign(:errors, errors)}
        end
      end
    else
      # 有必填项未填写，生成错误信息并阻止提交
      errors = Enum.reduce(missing_items, %{}, fn item, acc ->
        Map.put(acc, item.id, "此字段为必填项")
      end)
      
      # 返回错误信息，阻止提交，但保留表单状态
      Logger.warning("Form submission blocked due to missing required fields: #{inspect(Enum.map(missing_items, & &1.id))}")
      
      # 使用通知组件显示错误
      socket = MyAppWeb.NotificationComponent.notify(socket, "请完成所有必填项后再提交表单", :error)
      
      # 更新错误状态并显示消息
      {:noreply, 
        socket
        |> assign(:errors, errors)}
    end
  end
  
  # 辅助函数：从changeset中格式化错误信息
  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
  
  # 辅助函数：关联文件到响应
  defp associate_files_with_response(form_state, form_id, response_id) do
    # 提取文件数据（如果有）
    file_items = 
      form_state
      |> Enum.filter(fn {_key, value} -> 
        is_list(value) && Enum.any?(value, &(is_map(&1) && Map.has_key?(&1, "id")))
      end)
    
    # 关联每个表单项的文件到响应
    Enum.each(file_items, fn {item_id, file_entries} ->
      if !Enum.empty?(file_entries) do
        Logger.info(
          "Associating #{length(file_entries)} files for item #{item_id} with response #{response_id}"
        )
        
        Upload.associate_files_with_response(form_id, item_id, response_id)
      end
    end)
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

    # 确保当前表单状态被完全保留 - 直接使用socket中的form_state
    form_state = socket.assigns.form_state || %{}
    
    # 记录当前表单状态到日志以便调试
    Logger.info("[页面跳转] 保留表单状态: #{inspect(Map.keys(form_state))}")

    # 先更新socket的基本属性
    socket = socket
      |> assign(:current_page_idx, target_idx)
      |> assign(:current_page, target_page)
      |> assign(:page_items, target_page_items)
      |> assign(:pages_status, updated_status)
      # 确保表单状态被保留 - 直接赋值而不是创建新对象
      |> assign(:form_state, form_state)
      # 清除错误信息
      |> assign(:errors, %{})
    
    {:noreply, socket}
  end

  # 辅助函数：在表单状态更新后进行验证和跳转逻辑评估
  defp maybe_validate_form(socket, current_form_data) do
    require Logger

    # 执行基本验证
    errors = validate_form_data(current_form_data, socket.assigns.items_map)

    # 计算跳转状态 - 从模板获取逻辑
    form_template = socket.assigns.form_template
    template_structure = if form_template, do: form_template.structure || [], else: []

    # 检查处理的数据中是否有填空题
    current_page = socket.assigns.current_page
    page_items = get_page_items(socket.assigns.form, current_page)
    fill_in_blank_items = Enum.filter(page_items, fn item -> item.type == :fill_in_blank end)
    
    if !Enum.empty?(fill_in_blank_items) do
      Logger.info("[验证] 页面包含#{length(fill_in_blank_items)}个填空题")
      Enum.each(fill_in_blank_items, fn item ->
        value = Map.get(current_form_data, item.id, "[]")
        Logger.info("[验证] 填空题 #{item.id} 值: #{inspect(value)}")
      end)
    end

    # 评估跳转条件，确定是否激活跳转
    active_jump =
      Enum.find_value(template_structure, %{active: false}, fn template_item ->
        # 检查模板项是否有跳转逻辑
        logic = template_item["logic"] || Map.get(template_item, :logic)
        logic_type = if logic, do: logic["type"] || Map.get(logic, :type), else: nil

        if logic && logic_type == "jump" do
          source_id = template_item["id"] || Map.get(template_item, :id)
          condition = Map.get(logic, "condition") || Map.get(logic, :condition) || %{}
          target_id = Map.get(logic, "target_id") || Map.get(logic, :target_id)
          operator = Map.get(condition, "operator") || Map.get(condition, :operator)
          value_to_match = Map.get(condition, "value") || Map.get(condition, :value)

          unless target_id do
            Logger.warning("跳转逻辑缺少目标ID: 源=#{source_id}")
            nil
          else
            # 从表单数据获取源字段的当前值
            source_value = Map.get(current_form_data, source_id)

            # 条件评估
            condition_met =
              case operator do
                "equals" ->
                  "#{source_value}" == "#{value_to_match}"

                "not_equals" ->
                  "#{source_value}" != "#{value_to_match}"

                "contains" ->
                  is_binary(source_value) &&
                    String.contains?("#{source_value}", "#{value_to_match}")

                _ ->
                  false
              end

            # 条件满足则激活跳转
            if condition_met do
              %{active: true, source_id: source_id, target_id: target_id}
            else
              nil
            end
          end
        else
          nil
        end
      end)

    # 确保直接更新:form_state，而不是让它被中间步骤覆盖
    # 这是修复保留填空题答案的关键一步
    socket = socket |> assign(:form_state, current_form_data)
    
    # 更新视图状态
    socket
    |> assign(:errors, errors)
    |> assign(:jump_state, active_jump)
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

  # 判断字段是否可见 - 必填项验证专用
  defp is_field_visible(_form_state, _item, _items_map) do
    # 现在我们不依赖 visibility_condition，直接返回 true
    # 表单项的可见性完全由模板逻辑控制
    # 此函数仅用于 validate_form_data 以确保必填项检查
    true
  end

  # 条件评估和操作符评估功能已移至其他模块
  # 这里保留函数签名注释供参考

  # 以下评估条件和操作符的函数已被弃用或移至其他模块:
  #
  # evaluate_condition(%{"type" => "compound", ...}, form_state, items_map)
  # evaluate_condition(%{"type" => "simple", ...}, form_state, items_map)
  # evaluate_operator("equals", source, target, type)
  # evaluate_operator("not_equals", source, target, type)
  # evaluate_operator("contains", source, target, type)
  # evaluate_operator("not_contains", source, target, type)
  # evaluate_operator("greater_than", source, target, type)
  # evaluate_operator("less_than", source, target, type)
  # evaluate_operator("greater_than_or_equal", source, target, type)
  # evaluate_operator("less_than_or_equal", source, target, type)
  #
  # 如需重新启用这些函数，请从版本控制系统恢复完整实现。

  # 基础字段验证 - 简化版本
  defp validate_form_data(form_data, items_map) do
    # 验证必填项，不考虑可见性条件（表单渲染器将处理可见性）
    items_map
    |> Enum.filter(fn {_, item} ->
      item.required
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
      Enum.reduce(upload_names, {%{}, upload_errors, socket}, fn {item_id, upload_name},
                                                                 {acc_data, acc_errors,
                                                                  acc_socket} ->
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
              {:ok, file} =
                Upload.save_uploaded_file(form_id, item_id, %{
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
            updated_errors = [
              %{item_id: item_id, error: "上传文件处理失败: #{inspect(reason)}"} | acc_errors
            ]

            {acc_data, updated_errors, acc_socket}
        end
      end)

    {updated_socket, files_data, errors}
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

  # 矩阵处理已移至模板渲染器

  # 辅助函数 - 深度更新嵌套映射中的值
  defp deep_put_in(map, [key], value) do
    Map.put(map, key, value)
  end

  defp deep_put_in(map, [key | rest], value) do
    existing = Map.get(map, key, %{})
    Map.put(map, key, deep_put_in(existing, rest, value))
  end
end
