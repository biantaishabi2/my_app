defmodule MyAppWeb.FormLive.Submit do
  use MyAppWeb, :live_view

  alias MyApp.Forms
  alias MyApp.Responses
  # Phoenix.LiveView已经在use MyAppWeb, :live_view中导入了
  # 不需要重复导入Phoenix.LiveView.Upload
  
  # 导入表单组件以使用自定义表单控件
  import MyAppWeb.FormComponents

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Forms.get_form(id) do
      nil ->
        {:ok, 
          socket
          |> put_flash(:error, "表单不存在")
          |> push_navigate(to: ~p"/forms")
        }
      
      form ->
        if form.status != :published do
          # 表单未发布，重定向到表单列表
          {:ok, 
            socket
            |> put_flash(:error, "表单未发布，无法填写")
            |> push_navigate(to: ~p"/forms")
          }
        else
          items_map = build_items_map(form.items)
          
          # 获取分页数据
          pages = form.pages || []
          current_page_idx = 0
          current_page = if Enum.empty?(pages), do: nil, else: Enum.at(pages, current_page_idx)
          
          # 获取当前页面的表单项
          page_items = get_page_items(form, current_page)
          
          # 初始化文件上传配置
          socket = 
            Enum.reduce(form.items, socket, fn item, acc ->
              if item.type == :file_upload do
                # 每个文件上传控件都有自己的上传配置
                max_files_value = if item.multiple_files, do: item.max_files || 1, else: 1
                live_upload_config = %{
                  max_entries: max_files_value,
                  max_file_size: (item.max_file_size || 5) * 1024 * 1024, # 转换为字节
                  accept: item.allowed_extensions || [".jpg", ".jpeg", ".png", ".pdf", ".doc", ".docx"]
                }
                
                # 为每个文件上传控件注册一个上传配置
                allow_upload(acc, String.to_atom("#{item.id}_uploader"), live_upload_config)
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
            |> assign(:file_uploads, %{}) # 存储已上传文件的信息
            # 分页相关状态
            |> assign(:current_page_idx, current_page_idx)
            |> assign(:current_page, current_page)
            |> assign(:page_items, page_items)
            |> assign(:pages_status, initialize_pages_status(pages))
          }
        end
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
      |> assign(:errors, errors)
    }
  end
  
  @impl true
  def handle_event("submit_form", params, socket) do
    form_data = params["form"] || %{}
    form = socket.assigns.form
    items_map = socket.assigns.items_map
    
    # 合并文件上传数据到表单数据中
    form_data = Map.merge(form_data, socket.assigns.file_uploads)
    
    if length(form.pages || []) > 0 do
      # 对于多页表单，验证所有页面的数据
      all_errors = validate_all_pages(form, form_data, items_map)
      
      # 检查是否有错误
      if Enum.empty?(all_errors) do
        # 所有页面都验证通过，可以提交表单
        submit_form_data(form, form_data, socket)
      else
        # 找出第一个有错误的页面
        {error_page_idx, page_errors} = find_first_error_page(form, all_errors)
        
        if error_page_idx == socket.assigns.current_page_idx do
          # 如果当前页面有错误，显示这些错误
          {:noreply, 
            socket
            |> assign(:form_state, form_data)
            |> assign(:errors, page_errors)
            |> put_flash(:error, "请完成当前页面上的所有必填项")
          }
        else
          # 如果错误在其他页面上，跳转到那个页面并显示错误
          error_page = Enum.at(form.pages, error_page_idx)
          page_items = get_page_items(form, error_page)
          
          {:noreply, 
            socket
            |> assign(:form_state, form_data)
            |> assign(:current_page_idx, error_page_idx)
            |> assign(:current_page, error_page)
            |> assign(:page_items, page_items)
            |> assign(:errors, page_errors)
            |> put_flash(:error, "请完成所有必填项才能提交表单")
          }
        end
      end
    else
      # 对于单页表单，执行一般验证
      errors = validate_form_data(form_data, items_map)
      
      if Enum.empty?(errors) do
        # 验证通过，提交表单
        submit_form_data(form, form_data, socket)
      else
        # 验证失败，显示错误信息
        {:noreply, 
          socket
          |> assign(:form_state, form_data)
          |> assign(:errors, errors)
          |> put_flash(:error, "表单提交失败，请检查所有必填项")
        }
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
    page_errors = validate_page_items(socket.assigns.form_state, page_items, socket.assigns.items_map)
    
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
      
      {:noreply, socket
        |> assign(:current_page_idx, next_idx)
        |> assign(:current_page, next_page)
        |> assign(:page_items, next_page_items)
        |> assign(:pages_status, updated_status)
        |> assign(:form_state, form_state) # 确保表单状态被保留
        |> assign(:errors, %{}) # 清除错误信息
      }
    else
      # 如果有错误，保持在当前页面并显示错误
      {:noreply, socket 
        |> assign(:errors, page_errors)
        |> put_flash(:error, "请完成当前页面上的所有必填项")
      }
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
    
    {:noreply, socket
      |> assign(:current_page_idx, prev_idx)
      |> assign(:current_page, prev_page)
      |> assign(:page_items, prev_page_items)
      |> assign(:form_state, form_state) # 确保表单状态被保留
    }
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
      page_errors = validate_page_items(socket.assigns.form_state, page_items, socket.assigns.items_map)
      
      if not Enum.empty?(page_errors) do
        # 当前页面有错误，无法跳转到后面的页面
        {:noreply, socket 
          |> assign(:errors, page_errors)
          |> put_flash(:error, "请先完成当前页面上的所有必填项")
        }
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
    
    {:noreply, socket
      |> assign(:current_page_idx, target_idx)
      |> assign(:current_page, target_page)
      |> assign(:page_items, target_page_items)
      |> assign(:pages_status, updated_status)
      |> assign(:form_state, form_state) # 确保表单状态被保留
      |> assign(:errors, %{}) # 清除错误信息
    }
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
      |> assign(:errors, errors)
    }
  end

  # 地区选择事件处理器 - 处理省份变化
  @impl true
  def handle_event("region_province_change", %{"field-id" => field_id, "value" => province}, socket) do
    form_state = socket.assigns.form_state || %{}
    
    # 更新省份并清除城市和区县
    updated_form_state = form_state
      |> Map.put("#{field_id}_province", province)
      |> Map.delete("#{field_id}_city")
      |> Map.delete("#{field_id}_district")
    
    # 更新组合值
    updated_form_state = Map.put(
      updated_form_state, 
      field_id, 
      combine_region_value(province, nil, nil)
    )
    
    # 重新验证
    errors = validate_form_data(updated_form_state, socket.assigns.items_map)
    
    # 添加日志帮助调试
    if Mix.env() == :dev do
      IO.puts("地区选择 - 省份变化: #{field_id} -> #{province}")
      IO.inspect(updated_form_state, label: "更新后的表单状态")
    end
    
    {:noreply, 
      socket
      |> assign(:form_state, updated_form_state)
      |> assign(:errors, errors)
      |> push_event("region_updated", %{field_id: field_id, level: "province"})
    }
  end
  
  # 处理城市变化
  @impl true
  def handle_event("region_city_change", %{"field-id" => field_id, "value" => city}, socket) do
    form_state = socket.assigns.form_state || %{}
    province = Map.get(form_state, "#{field_id}_province")
    
    # 更新城市并清除区县
    updated_form_state = form_state
      |> Map.put("#{field_id}_city", city)
      |> Map.delete("#{field_id}_district")
    
    # 更新组合值
    updated_form_state = Map.put(
      updated_form_state, 
      field_id, 
      combine_region_value(province, city, nil)
    )
    
    # 重新验证
    errors = validate_form_data(updated_form_state, socket.assigns.items_map)
    
    # 添加日志帮助调试
    if Mix.env() == :dev do
      IO.puts("地区选择 - 城市变化: #{field_id} -> #{city}")
      IO.inspect(updated_form_state, label: "更新后的表单状态")
    end
    
    {:noreply, 
      socket
      |> assign(:form_state, updated_form_state)
      |> assign(:errors, errors)
      |> push_event("region_updated", %{field_id: field_id, level: "city"})
    }
  end
  
  # 处理区县变化
  @impl true
  def handle_event("region_district_change", %{"field-id" => field_id, "value" => district}, socket) do
    form_state = socket.assigns.form_state || %{}
    province = Map.get(form_state, "#{field_id}_province")
    city = Map.get(form_state, "#{field_id}_city")
    
    # 更新区县
    updated_form_state = Map.put(form_state, "#{field_id}_district", district)
    
    # 更新组合值
    updated_form_state = Map.put(
      updated_form_state, 
      field_id, 
      combine_region_value(province, city, district)
    )
    
    # 重新验证
    errors = validate_form_data(updated_form_state, socket.assigns.items_map)
    
    # 添加日志帮助调试
    if Mix.env() == :dev do
      IO.puts("地区选择 - 区县变化: #{field_id} -> #{district}")
      IO.inspect(updated_form_state, label: "更新后的表单状态")
    end
    
    {:noreply, 
      socket
      |> assign(:form_state, updated_form_state)
      |> assign(:errors, errors)
      |> push_event("region_updated", %{field_id: field_id, level: "district"})
    }
  end
  
  # 处理矩阵题变化
  @impl true
  def handle_event("matrix_change", %{"field-id" => field_id, "row-idx" => row_idx, "col-idx" => col_idx}, socket) do
    form_state = socket.assigns.form_state || %{}
    item = socket.assigns.items_map[field_id]
    
    # 解析行索引和列索引为整数
    {row_idx, _} = Integer.parse(row_idx)
    {col_idx, _} = Integer.parse(col_idx)
    
    # 获取当前矩阵数据
    matrix_data = Map.get(form_state, field_id, %{})
    
    # 更新矩阵数据
    updated_matrix_data = 
      if item.matrix_type == :multiple do
        # 处理多选情况
        row_data = Map.get(matrix_data, to_string(row_idx), %{})
        # 切换选中状态
        row_data = if Map.get(row_data, to_string(col_idx), false) do
          Map.delete(row_data, to_string(col_idx))
        else
          Map.put(row_data, to_string(col_idx), true)
        end
        # 更新行数据
        Map.put(matrix_data, to_string(row_idx), row_data)
      else
        # 处理单选情况 (每行只能选择一列)
        Map.put(matrix_data, to_string(row_idx), to_string(col_idx))
      end
      
    # 更新表单状态
    updated_form_state = Map.put(form_state, field_id, updated_matrix_data)
    
    # 验证表单
    errors = validate_form_data(updated_form_state, socket.assigns.items_map)
    
    {:noreply, 
      socket
      |> assign(:form_state, updated_form_state)
      |> assign(:errors, errors)
    }
  end

  # ===========================================
  # 文件上传事件处理
  # ===========================================
  
  # 处理文件上传事件 - 文件选择
  @impl true
  def handle_event("select_files", %{"field-id" => field_id}, socket) do
    _upload_ref = String.to_atom("#{field_id}_uploader")
    
    # 触发文件选择对话框
    # 实际上，这个空实现会导致使用JS hooks中的代码来处理
    {:noreply, socket}
  end
  
  # 处理文件上传验证
  @impl true
  def handle_event("validate_upload", %{"field-id" => field_id}, socket) do
    _upload_ref = String.to_atom("#{field_id}_uploader")
    
    # 验证上传
    {:noreply, socket}
  end
  
  # 取消上传
  @impl true
  def handle_event("cancel_upload", %{"field-id" => field_id, "ref" => ref}, socket) do
    upload_ref = String.to_atom("#{field_id}_uploader")
    
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
      |> assign(:form_state, updated_form_state)
    }
  end
  
  # 处理文件上传完成
  @impl true
  def handle_event("upload_files", %{"field-id" => field_id}, socket) do
    upload_ref = String.to_atom("#{field_id}_uploader")
    _item = socket.assigns.items_map[field_id]
    
    # 获取当前控件的上传配置
    _uploads = socket.assigns.uploads[upload_ref]
    
    # 存储上传文件信息的目录
    uploads_dir = "uploads/#{socket.assigns.form.id}/#{field_id}"
    
    # 确保上传目录存在
    File.mkdir_p!(Path.join(["priv/static", uploads_dir]))
    
    # 处理每个已完成的上传
    {completed_uploads, upload_errors} =
      consume_uploaded_entries(socket, upload_ref, fn %{path: path}, entry ->
        # 生成文件名 - 使用UUID避免文件名冲突
        filename = "#{Ecto.UUID.generate()}-#{entry.client_name}"
        dest_path = Path.join(["priv/static", uploads_dir, filename])
        
        # 将临时文件复制到目标位置
        File.cp!(path, dest_path)
        
        # 返回文件的URL路径和元数据
        file_info = %{
          name: entry.client_name,
          size: entry.client_size,
          content_type: entry.client_type,
          path: "/#{uploads_dir}/#{filename}"
        }
        
        {:ok, file_info}
      end)
    
    # 更新表单状态中的文件列表
    file_uploads = socket.assigns.file_uploads
    form_state = socket.assigns.form_state
    
    # 获取字段当前的文件列表
    current_files = Map.get(form_state, field_id, [])
    current_uploads = Map.get(file_uploads, field_id, [])
    
    # 添加新上传的文件到列表
    updated_files = current_files ++ completed_uploads
    updated_uploads = current_uploads ++ completed_uploads
    
    # 更新状态
    updated_form_state = Map.put(form_state, field_id, updated_files)
    updated_file_uploads = Map.put(file_uploads, field_id, updated_uploads)
    
    # 如果有上传错误，显示错误信息
    socket = 
      if !Enum.empty?(upload_errors) do
        put_flash(socket, :error, "部分文件上传失败，请重试")
      else
        socket
      end
    
    {:noreply, 
      socket
      |> assign(:form_state, updated_form_state)
      |> assign(:file_uploads, updated_file_uploads)
    }
  end
  
  # 提交表单数据的辅助函数
  defp submit_form_data(form, form_data, socket) do
    # 修正提交格式，直接传递表单数据而不是嵌套在answers中
    case Responses.create_response(form.id, form_data) do
      {:ok, _response} ->
        # 保持响应在此进程，以便测试可以查询它
        if :test == Mix.env() do
          Process.sleep(100) # 确保数据库事务完成
        end
        
        # 提交成功后，更新状态并重定向
        {:noreply, 
          socket
          |> assign(:submitted, true)
          |> put_flash(:info, "表单提交成功")
          |> push_navigate(to: ~p"/forms")
        }
        
      {:error, reason} ->
        {:noreply, 
          socket
          |> put_flash(:error, "表单提交失败: #{inspect(reason)}")
        }
    end
  end
  
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
  
  # 检查之前所有页面的状态
  defp check_previous_pages_status(pages_status, current_idx) do
    # 检查之前的页面，确保它们都标记为完成
    Enum.reduce(0..(current_idx - 1), pages_status, fn idx, acc ->
      case Map.get(acc, idx) do
        :complete -> acc
        _ -> Map.put(acc, idx, :complete) # 设置为完成状态
      end
    end)
  end
  
  # 查找第一个有错误的页面
  defp find_first_error_page(_form, all_errors) do
    # 按页面索引排序
    sorted_errors = all_errors
    |> Enum.sort_by(fn {idx, _} -> idx end)
    
    # 如果没有错误，返回默认值
    if Enum.empty?(sorted_errors) do
      {0, %{}}
    else
      # 返回第一个有错误的页面
      Enum.at(sorted_errors, 0)
    end
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
              true -> errors
            end
            
          :time when not is_nil(value) and value != "" ->
            cond do
              item.min_time && compare_times(value, item.min_time) == :lt ->
                Map.put(errors, id, "时间不能早于 #{item.min_time}")
              item.max_time && compare_times(value, item.max_time) == :gt ->
                Map.put(errors, id, "时间不能晚于 #{item.max_time}")
              true -> errors
            end
            
          :region when item.required ->
            region_parts = parse_region_value(value)
            region_level = item.region_level || 3
            
            cond do
              region_level >= 1 && (is_nil(region_parts[:province]) || region_parts[:province] == "") ->
                Map.put(errors, id, "请选择省/直辖市")
              region_level >= 2 && (is_nil(region_parts[:city]) || region_parts[:city] == "") ->
                Map.put(errors, id, "请选择市")
              region_level >= 3 && (is_nil(region_parts[:district]) || region_parts[:district] == "") ->
                Map.put(errors, id, "请选择区/县")
              true -> errors
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
              true -> errors
            end
          
          :image_choice when item.required ->
            # 检查图片选择是否满足要求
            selected_images = cond do
              is_binary(value) && value != "" -> [value]
              is_list(value) && !Enum.empty?(value) -> value
              true -> []
            end
            
            if Enum.empty?(selected_images) do
              Map.put(errors, id, "请选择至少一张图片")
            else
              errors
            end
            
          _ -> errors
        end
      end
    end)
  end
  
  # 用于将地区选择的三个字段组合成一个值
  def combine_region_value(province, city, district) do
    case {province, city, district} do
      {nil, _, _} -> ""
      {_, nil, _} when not is_nil(province) -> province
      {_, _, nil} when not is_nil(province) and not is_nil(city) -> "#{province}-#{city}"
      {_, _, _} when not is_nil(province) and not is_nil(city) and not is_nil(district) -> 
        "#{province}-#{city}-#{district}"
      _ -> ""
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
      _ -> nil
    end
  end
  
  # 辅助函数：获取矩阵多选题的值
  def get_matrix_value(form_state, field_id, row_idx, col_idx) do
    case form_state do
      %{^field_id => matrix_data} when is_map(matrix_data) ->
        row_data = Map.get(matrix_data, to_string(row_idx), %{})
        Map.get(row_data, to_string(col_idx), false)
      _ -> false
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
end