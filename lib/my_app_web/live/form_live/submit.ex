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
        form_template: form_template,
        form_items: form_items,
        page_items: page_items,
        form_data: %{},
        form_state: %{},
        upload_names: upload_names,
        items_map: items_map,
        form_updated_at: System.system_time(:millisecond), # 添加时间戳用于强制视图更新
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
    Logger.info("Handling validate event with form_response")
    changeset = MyApp.Responses.Response.changeset(%MyApp.Responses.Response{}, response_params)

    # 这里不需要手动处理 @uploads, LiveView 会自动验证
    {:noreply, assign(socket, changeset: changeset)}
  end
  
  @impl true
  def handle_event("validate", %{"form_data" => form_data} = params, socket) do
    Logger.info("Handling validate event with form_data: #{inspect(params["_target"])}")
    
    # 处理表单字段更改，更新表单状态
    updated_form_state = 
      socket.assigns.form_state
      |> Map.merge(form_data)
    
    # 当用户与单选按钮交互时，应执行条件逻辑
    changed_field_id = case params["_target"] do
      ["form_data", field_id] -> field_id
      _ -> nil
    end
    
    if changed_field_id do
      field_value = Map.get(form_data, changed_field_id)
      Logger.info("字段变更: #{changed_field_id}, 值: #{inspect(field_value)}")
      
      # 记录特殊值情况
      if "#{field_value}" == "我是🐷" do
        Logger.info("🚨 检测到特殊值 '我是🐷'，这可能会触发跳转逻辑")
      end
      
      # 识别表单项是否有逻辑规则
      item = Map.get(socket.assigns.items_map || %{}, changed_field_id)
      if item && (Map.get(item, :logic) || Map.get(item, "logic")) do
        logic = Map.get(item, :logic) || Map.get(item, "logic")
        Logger.info("字段 #{changed_field_id} 有逻辑规则: #{inspect(logic)}")
      end
    end
    
    # 重要：更新form_data，这是模板逻辑渲染评估所需的
    # 使用maybe_validate_form来处理表单验证和数据更新
    updated_socket = socket
                    |> assign(:form_state, updated_form_state)
                    |> maybe_validate_form(form_data)  # 这里使用原始form_data  
    
    {:noreply, updated_socket}
  end
  
  @impl true
  def handle_event("validate", params, socket) do
    # 处理其他验证情况
    Logger.warning("Received validate event with unexpected params format: #{inspect(params)}")
    {:noreply, socket}
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
    require Logger
    
    # 执行基本验证（必填项）
    errors = validate_form_data(form_data, socket.assigns.items_map)
    
    # 记录表单数据，这很重要，因为模板逻辑依赖于它来决定显示/隐藏
    Logger.info("📝 表单数据更新: #{inspect(form_data)}")
    
    # 记录更新的字段，查找是否有可能触发跳转逻辑的字段
    form_items = socket.assigns.form_items || []
    Enum.each(form_data, fn {field_id, value} ->
      # 字符串化处理字段ID以确保一致比较
      field_id_str = to_string(field_id)
      
      # 查找是否有包含跳转逻辑的表单项
      item_with_logic = Enum.find(form_items, fn item -> 
        # 确保使用字符串比较ID
        to_string(item.id) == field_id_str && 
        (Map.get(item, :logic) || Map.get(item, "logic"))
      end)
      
      if item_with_logic do
        logic = Map.get(item_with_logic, :logic) || Map.get(item_with_logic, "logic")
        logic_type = Map.get(logic, "type") || Map.get(logic, :type)
        
        # 检查是否有"我是🐷"条件
        condition = Map.get(logic, "condition") || Map.get(logic, :condition) || %{}
        condition_value = Map.get(condition, "value") || Map.get(condition, :value)
        
        if logic_type == "jump" && "#{condition_value}" == "我是🐷" do
          target_id = Map.get(logic, "target_id") || Map.get(logic, :target_id)
          Logger.info("🚨 检测到关键跳转逻辑字段 #{field_id} 更新为: #{inspect(value)}")
          Logger.info("🚨 跳转源: #{item_with_logic.id}, 跳转条件: #{inspect(condition)}, 跳转目标: #{target_id}")
          
          # 特殊情况 - 如果选择了"a"而非"我是🐷"
          if value != nil && value != "我是🐷" && value == "a" do
            Logger.info("🚨🚨 特殊场景：用户选择了'a'，不满足'我是🐷'条件，应执行跳转")
          end
        end
      end
    end)
    
    # 不再在此处计算可见性，因为可见性现在完全由模板逻辑在渲染时决定
    # 重要的是更新form_data并强制视图更新
    socket = socket
             |> assign(:form_data, form_data)
             |> assign(:errors, errors)
             |> assign(:form_updated_at, System.system_time(:millisecond))
             
    socket
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
  defp is_field_visible(form_state, _item, _items_map) do
    # 现在我们不依赖 visibility_condition，直接返回 true
    # 表单项的可见性完全由模板逻辑控制
    # 此函数仅用于 validate_form_data 以确保必填项检查
    true
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
    # 获取源字段的值 - 尝试使用字符串键和原子键
    source_value = Map.get(form_state, source_id) || Map.get(form_state, "#{source_id}")
    # 获取源字段的类型，安全处理nil
    source_type = get_in(items_map, [source_id, :type])

    # 根据操作符和字段类型评估条件
    evaluate_operator(operator, source_value, target, source_type)
  end
  
  # 处理有类型但没有operator的情况
  defp evaluate_condition(%{"type" => type}, _, _) do
    Logger.warning("条件缺少必要的操作符或来源: #{inspect(type)}")
    true
  end

  # 处理其他情况
  defp evaluate_condition(condition, _, _) do
    Logger.warning("无法识别的条件格式: #{inspect(condition)}")
    true
  end

  # 定义不同操作符的评估逻辑
  defp evaluate_operator("equals", nil, _, _), do: false
  defp evaluate_operator("equals", _, nil, _), do: false
  defp evaluate_operator("equals", source, target, _) do
    # 将两边转换为字符串进行比较，以处理类型不匹配的情况
    string_source = if is_binary(source), do: source, else: to_string(source)
    string_target = if is_binary(target), do: target, else: to_string(target)
    string_source == string_target
  end
  
  defp evaluate_operator("not_equals", nil, nil, _), do: false  # nil和nil不相等应该为false
  defp evaluate_operator("not_equals", nil, _, _), do: true
  defp evaluate_operator("not_equals", _, nil, _), do: true
  defp evaluate_operator("not_equals", source, target, _) do
    # 将两边转换为字符串进行比较
    string_source = if is_binary(source), do: source, else: to_string(source)
    string_target = if is_binary(target), do: target, else: to_string(target)
    string_source != string_target
  end
  
  defp evaluate_operator("contains", nil, _, _), do: false
  defp evaluate_operator("contains", _, nil, _), do: false
  defp evaluate_operator("contains", source, target, _) when is_list(source) do
    # 列表中包含元素
    string_target = if is_binary(target), do: target, else: to_string(target)
    Enum.any?(source, fn item -> 
      to_string(item) == string_target
    end)
  end
  defp evaluate_operator("contains", source, target, _) when is_binary(source) and is_binary(target) do
    # 字符串包含子串
    String.contains?(source, target)
  end
  defp evaluate_operator("contains", source, target, _) do
    # 转换为字符串然后比较
    try do
      string_source = to_string(source)
      string_target = to_string(target)
      String.contains?(string_source, string_target)
    rescue
      _ -> false
    end
  end
  
  defp evaluate_operator("not_contains", source, target, type) do
    !evaluate_operator("contains", source, target, type)
  end
  
  defp evaluate_operator("greater_than", source, target, _) do
    # 安全地尝试数字比较
    try do
      {src_num, _} = if is_number(source), do: {source, ""}, else: Float.parse(to_string(source))
      {tgt_num, _} = if is_number(target), do: {target, ""}, else: Float.parse(to_string(target))
      src_num > tgt_num
    rescue
      _ -> false
    end
  end
  
  defp evaluate_operator("less_than", source, target, _) do
    # 安全地尝试数字比较
    try do
      {src_num, _} = if is_number(source), do: {source, ""}, else: Float.parse(to_string(source))
      {tgt_num, _} = if is_number(target), do: {target, ""}, else: Float.parse(to_string(target))
      src_num < tgt_num
    rescue
      _ -> false
    end
  end
  
  defp evaluate_operator("greater_than_or_equal", source, target, _) do
    # 安全地尝试数字比较
    try do
      {src_num, _} = if is_number(source), do: {source, ""}, else: Float.parse(to_string(source))
      {tgt_num, _} = if is_number(target), do: {target, ""}, else: Float.parse(to_string(target))
      src_num >= tgt_num
    rescue
      _ -> false
    end
  end
  
  defp evaluate_operator("less_than_or_equal", source, target, _) do
    # 安全地尝试数字比较
    try do
      {src_num, _} = if is_number(source), do: {source, ""}, else: Float.parse(to_string(source))
      {tgt_num, _} = if is_number(target), do: {target, ""}, else: Float.parse(to_string(target))
      src_num <= tgt_num
    rescue
      _ -> false
    end
  end
  
  defp evaluate_operator(op, source, target, _) do
    Logger.warning("未知操作符或无法处理的值类型: op=#{op}, source=#{inspect(source)}, target=#{inspect(target)}")
    false
  end

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