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
          }
        end
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

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
    
    {:noreply, 
      socket
      |> assign(:form_state, updated_form_state)
      |> assign(:errors, errors)
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
    
    {:noreply, 
      socket
      |> assign(:form_state, updated_form_state)
      |> assign(:errors, errors)
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
    
    {:noreply, 
      socket
      |> assign(:form_state, updated_form_state)
      |> assign(:errors, errors)
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

  @impl true
  def handle_event("submit_form", params, socket) do
    form_data = params["form"] || %{}
    form = socket.assigns.form
    items_map = socket.assigns.items_map
    
    # 合并文件上传数据到表单数据中
    form_data = Map.merge(form_data, socket.assigns.file_uploads)
    
    # 执行验证
    errors = validate_form_data(form_data, items_map)
    
    if Enum.empty?(errors) do
      # 准备响应数据 - 不需要respondent_info，直接传递表单数据
      
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
    else
      {:noreply, 
        socket
        |> assign(:form_state, form_data)
        |> assign(:errors, errors)
      }
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
end