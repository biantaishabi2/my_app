defmodule MyAppWeb.FormLive.Submit do
  use MyAppWeb, :live_view
  require Logger # 确保 Logger 被引入

  alias MyApp.Forms
  alias MyApp.Responses
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
  def mount(%{"id" => id}, _session, socket) do
    # 使用与预览页面相同的获取表单方法
    case get_published_form(id) do
      {:ok, form} ->

        # --- 详细选项标签日志 (移动到这里) ---
        if Mix.env() == :dev do
          IO.puts("\\n===== Detailed Option Labels in Submit Mount =====")
          form.items
          |> Enum.filter(fn item -> item.type in [:radio, :checkbox, :dropdown] end)
          |> Enum.each(fn item ->
            IO.puts("Item: #{item.label} (ID: #{item.id}, Type: #{item.type})")
            options_data = item.options
            cond do
              is_list(options_data) ->
                if Enum.empty?(options_data) do
                  IO.puts("  -> No options loaded.")
                else
                  Enum.each(options_data, fn opt ->
                    # 打印选项的 label 字段
                    IO.puts("    Option Label: #{inspect(opt.label)}") 
                  end)
                end
              %Ecto.Association.NotLoaded{} ->
                IO.puts("  -> Options association not loaded.")
              true ->
                 IO.puts("  -> Options data is not a list or not loaded.")
                 IO.inspect(options_data, label: "    Unexpected Options Data")
            end
          end)
          IO.puts("===== Detailed Option Labels End =====\\n")
        end
        # --- 详细选项标签日志结束 ---

        items_map = build_items_map(form.items)

        # 获取分页数据
        pages = form.pages || []
        current_page_idx = 0
        current_page = if Enum.empty?(pages), do: nil, else: Enum.at(pages, current_page_idx)

        # 获取当前页面的表单项
        page_items = get_page_items(form, current_page)

        # 调试输出表单项和选项
        if Mix.env() == :dev do
          IO.puts("\n===== 表单提交页面调试信息 =====")
          IO.puts("表单ID: #{form.id}")
          IO.puts("表单项数量: #{length(form.items)}")

          # 检查所有表单项的选项
          Enum.each(form.items, fn item ->
            options_info =
              case item.options do
                %Ecto.Association.NotLoaded{} -> "选项未加载"
                nil -> "无选项"
                options when is_list(options) -> "#{length(options)}个选项"
                _ -> "未知选项类型"
              end

            IO.puts("表单项: #{item.id} (#{item.label}) - 类型: #{item.type} - 选项: #{options_info}")

            # 如果有选项，输出选项信息
            if is_list(item.options) && !Enum.empty?(item.options) do
              Enum.each(item.options, fn option ->
                IO.puts("  - 选项ID: #{option.id}, 标签: #{option.label}, 值: #{option.value}")
              end)
            end
          end)

          IO.puts("当前页面表单项数量: #{length(page_items)}")
          IO.puts("===== 调试信息结束 =====\n")
        end

        # 初始化文件上传配置 (移动到这里)
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

        {:ok,
         socket
         |> assign(:page_title, "填写表单 - #{form.title}")
         |> assign(:form, form)
         |> assign(:items_map, items_map)
         |> assign(:form_state, %{})
         |> assign(:errors, %{})
         |> assign(:submitted, false)
         # 存储已上传文件的信息
         |> assign(:file_uploads, %{})
         # 分页相关状态
         |> assign(:current_page_idx, current_page_idx)
         |> assign(:current_page, current_page)
         |> assign(:page_items, page_items)
         |> assign(:pages_status, initialize_pages_status(pages))}

      {:error, :not_published} ->
        # 表单未发布，重定向到表单列表
        {:ok,
         socket
         |> put_flash(:error, "表单未发布，无法填写")
         |> push_navigate(to: ~p"/forms")}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  # ===========================================
  # 表单验证事件处理
  # ===========================================

  @impl true
  def handle_event("validate", params, socket) do
    items_map = socket.assigns.items_map

    # 提取表单数据，简化为仅处理标准表单验证
    form_data = params["form"] || socket.assigns.form_state || %{}

    # 执行基本验证（必填项）
    errors = validate_form_data(form_data, items_map)

    {:noreply,
     socket
     |> assign(:form_state, form_data)
     |> assign(:errors, errors)}
  end

  @impl true
  def handle_event("submit_form", params, socket) do
    form = socket.assigns.form
    form_data = params["form"] || %{}
    items_map = socket.assigns.items_map

    # --- 1. 处理文件上传 (新添加的逻辑) ---
    file_upload_items = Enum.filter(form.items, &(&1.type == :file_upload))
    file_uploads_state = socket.assigns.file_uploads # 获取当前的 file_uploads 状态

    {socket, consumed_files_data, consumption_errors} = 
      Enum.reduce(file_upload_items, {socket, %{}, []}, fn item, {acc_socket, acc_consumed, acc_errors} ->
        upload_ref = get_upload_ref(acc_socket, item.id)
        
        # 如果找不到上传配置或配置无效，则跳过此项并记录错误
        if is_nil(upload_ref) || !Map.has_key?(acc_socket.assigns.uploads, upload_ref) do
           Logger.error("Could not find valid upload config for item #{item.id}")
           {acc_socket, acc_consumed, acc_errors ++ [{item.id, :config_not_found}]}
        else
          uploads_dir = "uploads/#{form.id}/#{item.id}"
          File.mkdir_p!(Path.join(["priv/static", uploads_dir]))

          {completed_uploads, item_consumption_errors} =
            consume_uploaded_entries(acc_socket, upload_ref, fn %{path: path}, entry ->
              # 只有状态是 :done 的 entry 才会被这个函数处理
              filename = "#{Ecto.UUID.generate()}-#{entry.client_name}"
              dest_path = Path.join(["priv/static", uploads_dir, filename])

              try do
                File.cp!(path, dest_path)
                file_info = %{
                  name: entry.client_name,
                  size: entry.client_size,
                  content_type: entry.client_type,
                  path: "/#{uploads_dir}/#{filename}" # 存储相对URL路径
                }
                {:ok, file_info}
              rescue
                e in File.Error ->
                  Logger.error("Failed to copy uploaded file for item #{item.id}: #{inspect(e)}")
                  {:error, {entry, :copy_failed}}
              end
            end)
          
          # 将成功处理的文件信息添加到累积结果中
          updated_consumed = Map.put(acc_consumed, item.id, completed_uploads)
          
          # 累积错误
          updated_errors = acc_errors ++ (Enum.map(item_consumption_errors, fn {entry, reason} -> {item.id, entry.client_name, reason} end))

          {acc_socket, updated_consumed, updated_errors}
        end
      end)

    # 将消费后的文件信息合并到 form_data 中，以便一起验证和保存
    # 注意：这里假设 form_data 中的 key 是 item.id (字符串)
    # 如果 file_upload 字段的值需要特殊处理（例如只存路径列表），需要调整这里
    merged_form_data = Map.merge(form_data, consumed_files_data, fn _key, existing, new ->
      # 如果已存在旧的文件列表（例如来自草稿），根据需要合并或替换
      # 这里简单地替换为新上传的文件列表
      new
    end)

    # --- 2. 验证所有页面的数据 (使用合并后的 form_data) ---
    all_errors = validate_all_pages(form, merged_form_data, items_map)
    
    # 如果有上传处理错误，添加到验证错误中（或通过flash显示）
    socket = 
      if !Enum.empty?(consumption_errors) do
        error_msg = "部分文件处理失败: " <> Enum.map_join(consumption_errors, ", ", fn {_item_id, name, reason} -> "#{name} (#{reason})" end)
        put_flash(socket, :error, error_msg) 
      else
        socket
      end

    if Enum.empty?(all_errors) && Enum.empty?(consumption_errors) do
      # --- 3. 提交表单数据 (如果验证通过且文件处理无误) ---
      # 过滤掉辅助字段
      filtered_form_data =
        merged_form_data # 使用合并了文件数据的 form_data
        |> Enum.filter(fn {key, _value} ->
          not (is_binary(key) and
                 (String.ends_with?(key, "_province") or
                  String.ends_with?(key, "_city") or
                  String.ends_with?(key, "_district")))
        end)
        |> Enum.into(%{})

      case Responses.create_response(form.id, filtered_form_data) do
        {:ok, _response} ->
          if Mix.env() == :test do
            Process.sleep(100)
          end
          {:noreply,
           socket
           |> assign(:submitted, true)
           |> put_flash(:info, "表单提交成功")
           |> push_navigate(to: ~p"/forms")}
        {:error, reason} ->
          {:noreply,
           socket
           |> put_flash(:error, "表单提交失败: #{inspect(reason)}")}
      end
    else
      # --- 4. 处理验证错误或上传错误 ---
      # 查找第一个有错误的页面
      {error_page_idx, page_errors} = find_first_error_page(form, all_errors)
      
      # 更新页面状态
      pages_status = socket.assigns.pages_status
      updated_pages_status = 
        pages_status
        |> Map.put(error_page_idx, :error) # 标记错误页面
        |> check_previous_pages_status(error_page_idx) # 确保错误页之前的页面状态正确

      # 切换到第一个有错误的页面
      current_page = Enum.at(form.pages, error_page_idx)
      page_items = get_page_items(form, current_page)
      
      # 合并所有页面的错误到一个map中，以便在UI中显示
      flat_errors = Enum.reduce(all_errors, %{}, fn {_idx, errors}, acc -> Map.merge(acc, errors) end)

      {:noreply,
       socket
       |> assign(:form_state, merged_form_data) # 更新为包含文件数据的 state
       |> assign(:errors, flat_errors) # 分配合并后的错误
       |> assign(:pages_status, updated_pages_status)
       |> assign(:current_page_idx, error_page_idx)
       |> assign(:current_page, current_page)
       |> assign(:page_items, page_items)
       |> put_flash(:error, "表单包含错误，请检查后重新提交") # 添加一个通用的错误提示
      }
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
  def handle_event("cancel_upload", %{"field-id" => field_id, "ref" => ref}, socket) do
    # 从映射中获取上传引用
    upload_ref = get_upload_ref(socket, field_id)

    # 根据上传引用取消特定上传
    {:noreply, cancel_upload(socket, upload_ref, ref)}
  end

  # 删除已上传的文件
  @impl true
  def handle_event("remove_file", %{"field-id" => field_id, "file-index" => index_str}, socket) do
    index = String.to_integer(index_str)

    # 从表单状态和文件上传记录中删除对应的文件
    file_uploads = socket.assigns.file_uploads
    form_state = socket.assigns.form_state

    # 获取字段的当前上传文件列表
    field_uploads = Map.get(file_uploads, field_id, [])
    field_files = Map.get(form_state, field_id, [])

    # 移除指定索引的文件
    updated_uploads = List.delete_at(field_uploads, index)
    updated_files = List.delete_at(field_files, index)

    # 更新状态
    updated_file_uploads = Map.put(file_uploads, field_id, updated_uploads)
    updated_form_state = Map.put(form_state, field_id, updated_files)

    {:noreply,
     socket
     |> assign(:file_uploads, updated_file_uploads)
     |> assign(:form_state, updated_form_state)}
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
        # 如果找不到映射，说明状态有问题，立即抛出错误
        raise "Upload configuration name not found in assigns for field_id: #{inspect(field_id)}. " <>
              "This might indicate a state inconsistency (e.g., after hot-reload)."
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
  # --- 重新添加结束 ---
end
