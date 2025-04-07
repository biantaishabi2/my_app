defmodule MyAppWeb.FormLive.Edit do
  use MyAppWeb, :live_view

  alias MyApp.Forms
  alias MyApp.Forms.FormItem
  alias MyAppWeb.FormLive.ItemRendererComponent
  alias MyApp.Upload
  alias MyApp.Upload.UploadedFile
  # Repo在测试环境中的直接查询中使用，但可以通过完全限定名称访问
  # alias MyApp.Repo
  # 移除未使用的ItemOption别名
  
  import Ecto.Query
  import MyAppWeb.FormComponents
  # Phoenix.LiveView.Upload 的函数已经通过 use MyAppWeb, :live_view 导入

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    form = Forms.get_form(id)
    
    if form do
      # 设置表单和默认值
      socket = socket
        |> assign(:form, form)
        |> assign(:form_items, form.items || [])  # 确保不会是nil
        |> assign(:active_category, :basic)
        |> assign(:item_type, "text_input")  # 默认类型
        |> assign(:editing_item, false)
        |> assign(:editing_item_id, nil)  # 用于直接在列表中编辑
        |> assign(:current_item, nil)
        |> assign(:loading_complete, false)
        |> assign(:item_options, [])
        |> assign(:editing_form_info, false)
        |> assign(:search_term, nil)
        |> assign(:delete_item_id, nil)
        |> assign(:editing_page, false)
        |> assign(:current_page, nil)
        |> assign(:delete_page_id, nil)
        |> assign(:show_publish_confirm, false)  # 用于发布确认
        |> assign(:editing_conditions, false)
        |> assign(:current_condition_item, nil)
        |> assign(:current_option_index, nil)  # 用于追踪当前正在编辑的选项的索引
        |> assign(:current_condition_type, nil)
        |> assign(:available_condition_items, [])
        |> assign(:temp_image_upload, %{})  # 用于临时存储图片上传信息

      # 允许Phoenix.LiveView上传图片
      socket = 
        socket
        |> allow_upload(:image, 
            accept: ~w(.jpg .jpeg .png .gif), 
            max_entries: 1,
            max_file_size: 5_000_000, # 5MB
            auto_upload: false)
      
      {:ok, socket}
    else
      {:ok, 
        socket
        |> put_flash(:error, "表单不存在")
        |> redirect(to: ~p"/forms")
      }
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    if socket.assigns[:loading_complete] do
      # 已经加载过数据的情况下不重复加载
      {:noreply, apply_action(socket, socket.assigns.live_action, params)}
    else
      # 开始异步加载表单完整数据
      send(self(), {:load_form_data, socket.assigns.form.id})
      
      # 先返回正在加载的状态
      {:noreply, 
        socket
        |> assign(:loading_complete, false)
        |> apply_action(socket.assigns.live_action, params)
      }
    end
  end
  
  # 异步加载表单数据
  @impl true
  def handle_info({:load_form_data, form_id}, socket) do
    # 并行获取需要的数据（控件类型和表单数据）
    all_types = Forms.list_available_form_item_types()
    form_with_pages = Forms.get_form_with_full_preload(form_id)
    
    # 确保表单有默认页面并处理未关联页面的表单项
    {:ok, _} = Forms.assign_default_page(form_with_pages)

    # 预先收集现有表单项，检查是否需要迁移
    all_form_items = 
      Enum.flat_map(form_with_pages.pages, fn page -> 
        # 提取每个页面的表单项
        page.items || []
      end)
    
    # 只有在确实需要迁移的情况下执行迁移操作
    form_with_pages = 
      if length(form_with_pages.items) > length(all_form_items) do
        # 迁移未关联页面的表单项到默认页面
        {:ok, updated_form} = Forms.migrate_items_to_default_page_optimized(form_with_pages)
        updated_form
      else
        # 不需要迁移，直接使用现有表单
        form_with_pages
      end
      
    # 重新收集所有表单项
    all_form_items = 
      Enum.flat_map(form_with_pages.pages, fn page -> 
        page.items || []
      end)
    
    IO.puts("异步加载完成: 发现#{length(all_form_items)}个表单项")
    
    # 更新socket状态
    {:noreply, 
      socket
      |> assign(:form, form_with_pages)
      |> assign(:form_items, all_form_items)
      |> assign(:all_item_types, all_types)
      |> assign(:loading_complete, true)
      |> assign(:editing_form_info, Enum.empty?(all_form_items) && (form_with_pages.title == nil || form_with_pages.title == ""))
    }
  end

  defp apply_action(socket, :edit, _params) do
    socket
    |> assign(:page_title, "编辑表单 - #{socket.assigns.form.title}")
  end

  @impl true
  def handle_event("edit_form_info", _params, socket) do
    {:noreply, assign(socket, :editing_form_info, true)}
  end

  @impl true
  def handle_event("cancel_edit_form_info", _params, socket) do
    {:noreply, assign(socket, :editing_form_info, false)}
  end

  @impl true
  def handle_event("save_form_info", params, socket) do
    form = socket.assigns.form
    
    # 优先使用表单提交的参数，如果没有则使用临时存储的值
    form_params = params["form"] || %{}
    title = form_params["title"] || socket.assigns[:temp_title] || form.title
    description = form_params["description"] || socket.assigns[:temp_description] || form.description
    
    IO.puts("使用用户输入的值：title=#{title}, description=#{description}")
    
    form_params = %{
      "title" => title,
      "description" => description
    }
    
    IO.puts("保存表单信息: #{inspect(form_params)}")
    
    case Forms.update_form(form, form_params) do
      {:ok, updated_form} ->
        # 使用公共函数重新加载表单和更新socket
        {:noreply, reload_form_and_update_socket(socket, updated_form.id, "表单信息已更新")}
        
      {:error, %Ecto.Changeset{} = changeset} ->
        IO.puts("表单更新失败: #{inspect(changeset)}")
        
        {:noreply, 
          socket
          |> assign(:form_changeset, changeset)
          |> put_flash(:error, "表单更新失败")
        }
    end
  end

  @impl true
  def handle_event("add_item", params, socket) do
    # 检查是否指定了页面ID
    page_id = Map.get(params, "page_id")
    form = socket.assigns.form
    
    # 获取默认页面ID
    default_page_id = form.default_page_id || (if length(form.pages) > 0, do: List.first(form.pages).id, else: nil)
    
    # 使用指定的页面ID或默认页面ID
    page_id = page_id || default_page_id
    
    # 使用当前选择的控件类型而不是固定为text_input
    item_type = socket.assigns.item_type || "text_input"
    type_atom = case item_type do
      "text_input" -> :text_input
      "textarea" -> :textarea
      "radio" -> :radio
      "checkbox" -> :checkbox
      "dropdown" -> :dropdown
      "rating" -> :rating
      "number" -> :number
      "email" -> :email
      "phone" -> :phone
      "date" -> :date
      "time" -> :time
      "region" -> :region
      "matrix" -> :matrix
      "image_choice" -> :image_choice
      "file_upload" -> :file_upload
      _ -> :text_input
    end
    
    # 使用当前表单类型设置默认标签
    default_label = case item_type do
      "radio" -> "新单选问题"
      "checkbox" -> "新复选问题"
      "matrix" -> "新矩阵题"
      "dropdown" -> "新下拉菜单"
      "rating" -> "新评分题"
      _ -> "新问题"
    end
    
    # 保留现有临时标签（如果存在），或使用默认标签
    temp_label = socket.assigns[:temp_label] || default_label
    
    # 创建初始化的表单项
    new_item = %FormItem{
      type: type_atom, 
      required: false, 
      page_id: page_id,
      label: temp_label
    }
    
    # 矩阵类型的特殊处理：预设行列
    new_item = if item_type == "matrix" || item_type == :matrix do
      new_item
      |> Map.put(:matrix_rows, ["问题1", "问题2", "问题3"])
      |> Map.put(:matrix_columns, ["选项A", "选项B", "选项C"])
      |> Map.put(:matrix_type, :single)
    else
      new_item
    end
      
    IO.puts("添加新表单项，使用顶部编辑区域")
    
    # 给当前表单项分配一个ID，防止有多个"添加问题"按钮
    # 注意：设置editing_item=true但不设置editing_item_id，使用顶部编辑区域
    {:noreply, 
      socket
      |> assign(:current_item, new_item)
      |> assign(:item_options, [])
      |> assign(:item_type, item_type)
      |> assign(:editing_item, true)
      |> assign(:editing_item_id, nil)  # 明确设置为nil，确保使用顶部编辑区域
      |> assign(:temp_label, temp_label)  # 保留标签值，不清除
    }
  end

  @impl true
  def handle_event("edit_item", %{"id" => id}, socket) do
    item = Enum.find(socket.assigns.form_items, fn item -> item.id == id end)
    
    if item do
      options = case item.options do
        nil -> []
        opts -> opts
      end
      
      IO.puts("开始编辑表单项 ID: #{id}, 类型: #{item.type}")
      
      # 改为设置editing_item_id而不是editing_item=true
      {:noreply, 
        socket
        |> assign(:current_item, item)
        |> assign(:item_options, options)
        |> assign(:item_type, to_string(item.type))
        |> assign(:editing_item_id, id)  # 设置当前正在原地编辑的表单项ID
        |> assign(:temp_label, item.label)
      }
    else
      {:noreply, put_flash(socket, :error, "表单项不存在")}
    end
  end

  @impl true
  def handle_event("cancel_edit_item", _params, socket) do
    IO.puts("取消编辑表单项")
    
    {:noreply, 
      socket
      |> assign(:current_item, nil)
      |> assign(:editing_item, false)
      |> assign(:editing_item_id, nil)  # 清除原地编辑ID
      |> assign(:item_options, [])
      |> assign(:editing_conditions, false)
      |> assign(:current_condition, nil)
    }
  end
  
  # 条件逻辑事件处理
  
  def handle_event("edit_conditions", %{"id" => item_id, "type" => condition_type}, socket) do
    # 获取表单项
    form_item = Enum.find(socket.assigns.form_items, &(&1.id == item_id))
    
    # 确定条件类型（可见性或必填）
    condition_type = String.to_existing_atom(condition_type)
    
    # 获取现有条件（如果有）
    current_condition = case condition_type do
      :visibility -> 
        if form_item.visibility_condition do
          Jason.decode!(form_item.visibility_condition)
        else
          nil
        end
      :required ->
        if form_item.required_condition do
          Jason.decode!(form_item.required_condition)
        else
          nil
        end
    end
    
    # 获取可以作为条件源的表单项（不包括当前表单项）
    available_items = Enum.filter(socket.assigns.form_items, fn item ->
      item.id != item_id
    end)
    
    {:noreply, 
      socket
      |> assign(:editing_conditions, true)
      |> assign(:current_item, form_item)
      |> assign(:condition_type, condition_type)
      |> assign(:current_condition, current_condition)
      |> assign(:available_items, available_items)
    }
  end
  
  def handle_event("cancel_edit_conditions", _params, socket) do
    {:noreply, 
      socket
      |> assign(:editing_conditions, false)
      |> assign(:current_item, nil)
      |> assign(:current_condition, nil)
    }
  end
  
  def handle_event("add_simple_condition", params, socket) do
    parent_id = Map.get(params, "parent-id")
    
    # 创建一个新的简单条件
    new_condition = %{
      "type" => "simple",
      "source_item_id" => nil,
      "operator" => "equals",
      "value" => ""
    }
    
    # 处理不同情况
    updated_condition = cond do
      # 如果是顶级条件且当前没有条件
      is_nil(parent_id) && is_nil(socket.assigns.current_condition) ->
        new_condition
        
      # 如果是顶级条件但已有一个简单条件，则创建一个 AND 组合条件
      is_nil(parent_id) && socket.assigns.current_condition["type"] == "simple" ->
        %{
          "type" => "compound",
          "operator" => "and",
          "conditions" => [socket.assigns.current_condition, new_condition]
        }
        
      # 如果是顶级条件且已有一个复合条件，则向该复合条件添加子条件
      is_nil(parent_id) && socket.assigns.current_condition["type"] == "compound" ->
        updated_conditions = socket.assigns.current_condition["conditions"] ++ [new_condition]
        Map.put(socket.assigns.current_condition, "conditions", updated_conditions)
        
      # 如果是子条件，则找到父条件并添加新的子条件
      !is_nil(parent_id) ->
        # 递归函数，在嵌套条件中查找并更新父条件
        add_to_parent = fn condition, parent_id, recurse ->
          case condition do
            %{"type" => "compound", "conditions" => conditions} = compound ->
              if condition["id"] == parent_id do
                # 找到了父条件，添加新的子条件
                Map.put(compound, "conditions", conditions ++ [new_condition])
              else
                # 递归查找子条件
                updated_conditions = Enum.map(conditions, &recurse.(&1, parent_id, recurse))
                Map.put(compound, "conditions", updated_conditions)
              end
              
            _ -> condition  # 不是复合条件，返回原条件
          end
        end
        
        add_to_parent.(socket.assigns.current_condition, parent_id, add_to_parent)
    end
    
    {:noreply, assign(socket, :current_condition, updated_condition)}
  end
  
  def handle_event("add_condition_group", params, socket) do
    parent_id = Map.get(params, "parent-id")
    
    # 创建一个新的复合条件组
    new_group = %{
      "type" => "compound",
      "operator" => "and",
      "conditions" => []
    }
    
    # 处理不同情况（与add_simple_condition类似）
    updated_condition = cond do
      # 如果是顶级条件且当前没有条件
      is_nil(parent_id) && is_nil(socket.assigns.current_condition) ->
        new_group
        
      # 如果是顶级条件但已有一个简单条件，则创建一个 AND 组合条件
      is_nil(parent_id) && socket.assigns.current_condition["type"] == "simple" ->
        %{
          "type" => "compound",
          "operator" => "and",
          "conditions" => [socket.assigns.current_condition, new_group]
        }
        
      # 如果是顶级条件且已有一个复合条件，则向该复合条件添加子条件组
      is_nil(parent_id) && socket.assigns.current_condition["type"] == "compound" ->
        updated_conditions = socket.assigns.current_condition["conditions"] ++ [new_group]
        Map.put(socket.assigns.current_condition, "conditions", updated_conditions)
        
      # 如果是子条件，则找到父条件并添加新的子条件组
      !is_nil(parent_id) ->
        # 递归函数，在嵌套条件中查找并更新父条件
        add_to_parent = fn condition, parent_id, recurse ->
          case condition do
            %{"type" => "compound", "conditions" => conditions} = compound ->
              if condition["id"] == parent_id do
                # 找到了父条件，添加新的子条件组
                Map.put(compound, "conditions", conditions ++ [new_group])
              else
                # 递归查找子条件
                updated_conditions = Enum.map(conditions, &recurse.(&1, parent_id, recurse))
                Map.put(compound, "conditions", updated_conditions)
              end
              
            _ -> condition  # 不是复合条件，返回原条件
          end
        end
        
        add_to_parent.(socket.assigns.current_condition, parent_id, add_to_parent)
    end
    
    {:noreply, assign(socket, :current_condition, updated_condition)}
  end
  
  def handle_event("delete_condition", %{"condition_id" => condition_id}, socket) do
    # 递归函数，在嵌套条件中查找并删除条件
    delete_condition = fn condition, condition_id, recurse ->
      case condition do
        %{"type" => "compound", "conditions" => conditions} = compound ->
          # 筛选出不等于condition_id的子条件
          filtered_conditions = Enum.reject(conditions, &(&1["id"] == condition_id))
          
          if length(filtered_conditions) == length(conditions) do
            # 如果没有找到要删除的条件，则递归查找子条件
            updated_conditions = Enum.map(filtered_conditions, &recurse.(&1, condition_id, recurse))
            Map.put(compound, "conditions", updated_conditions)
          else
            # 找到并删除了条件
            Map.put(compound, "conditions", filtered_conditions)
          end
          
        _ -> condition  # 不是复合条件，返回原条件
      end
    end
    
    updated_condition = 
      if socket.assigns.current_condition["id"] == condition_id do
        # 如果是顶级条件，则整个条件都被删除
        nil
      else
        # 否则递归查找并删除子条件
        delete_condition.(socket.assigns.current_condition, condition_id, delete_condition)
      end
    
    {:noreply, assign(socket, :current_condition, updated_condition)}
  end
  
  def handle_event("update_condition_operator", %{"condition_id" => condition_id, "operator" => operator}, socket) do
    # 递归函数，在嵌套条件中查找并更新条件的操作符
    update_operator = fn condition, condition_id, operator, recurse ->
      cond do
        condition["id"] == condition_id ->
          # 找到目标条件，更新操作符
          Map.put(condition, "operator", operator)
          
        condition["type"] == "compound" ->
          # 递归查找子条件
          updated_conditions = Enum.map(condition["conditions"], &recurse.(&1, condition_id, operator, recurse))
          Map.put(condition, "conditions", updated_conditions)
          
        true ->
          # 其他情况，保持不变
          condition
      end
    end
    
    updated_condition = update_operator.(socket.assigns.current_condition, condition_id, operator, update_operator)
    
    {:noreply, assign(socket, :current_condition, updated_condition)}
  end
  
  def handle_event("update_condition_source", %{"condition_id" => condition_id, "source_id" => source_id}, socket) do
    # 递归函数，在嵌套条件中查找并更新条件的源表单项
    update_source = fn condition, condition_id, source_id, recurse ->
      cond do
        condition["id"] == condition_id ->
          # 找到目标条件，更新源表单项
          Map.put(condition, "source_item_id", source_id)
          
        condition["type"] == "compound" ->
          # 递归查找子条件
          updated_conditions = Enum.map(condition["conditions"], &recurse.(&1, condition_id, source_id, recurse))
          Map.put(condition, "conditions", updated_conditions)
          
        true ->
          # 其他情况，保持不变
          condition
      end
    end
    
    updated_condition = update_source.(socket.assigns.current_condition, condition_id, source_id, update_source)
    
    {:noreply, assign(socket, :current_condition, updated_condition)}
  end
  
  def handle_event("update_condition_value", %{"condition_id" => condition_id, "value" => value}, socket) do
    # 递归函数，在嵌套条件中查找并更新条件的值
    update_value = fn condition, condition_id, value, recurse ->
      cond do
        condition["id"] == condition_id ->
          # 找到目标条件，更新值
          Map.put(condition, "value", value)
          
        condition["type"] == "compound" ->
          # 递归查找子条件
          updated_conditions = Enum.map(condition["conditions"], &recurse.(&1, condition_id, value, recurse))
          Map.put(condition, "conditions", updated_conditions)
          
        true ->
          # 其他情况，保持不变
          condition
      end
    end
    
    updated_condition = update_value.(socket.assigns.current_condition, condition_id, value, update_value)
    
    {:noreply, assign(socket, :current_condition, updated_condition)}
  end
  
  def handle_event("update_condition_group_type", %{"group_id" => group_id, "group_type" => group_type}, socket) do
    # 递归函数，在嵌套条件中查找并更新条件组的类型
    update_group_type = fn condition, group_id, group_type, recurse ->
      cond do
        condition["id"] == group_id && condition["type"] == "compound" ->
          # 找到目标条件组，更新类型
          Map.put(condition, "operator", group_type)
          
        condition["type"] == "compound" ->
          # 递归查找子条件
          updated_conditions = Enum.map(condition["conditions"], &recurse.(&1, group_id, group_type, recurse))
          Map.put(condition, "conditions", updated_conditions)
          
        true ->
          # 其他情况，保持不变
          condition
      end
    end
    
    updated_condition = update_group_type.(socket.assigns.current_condition, group_id, group_type, update_group_type)
    
    {:noreply, assign(socket, :current_condition, updated_condition)}
  end
  
  def handle_event("save_conditions", _params, socket) do
    form_item = socket.assigns.current_item
    condition_type = socket.assigns.condition_type
    condition = socket.assigns.current_condition
    
    # 根据条件类型更新表单项
    result = case condition_type do
      :visibility ->
        Forms.add_condition_to_form_item(form_item, condition, :visibility)
        
      :required ->
        Forms.add_condition_to_form_item(form_item, condition, :required)
    end
    
    case result do
      {:ok, _} ->
        # 更新成功，重新加载表单和表单项
        updated_form = Forms.get_form_with_items(socket.assigns.form.id)
        
        {:noreply, 
          socket
          |> assign(:form, updated_form)
          |> assign(:form_items, updated_form.items)
          |> assign(:editing_conditions, false)
          |> assign(:current_item, nil)
          |> assign(:current_condition, nil)
          |> put_flash(:info, "条件规则已保存")
        }
        
      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, "条件规则保存失败: #{inspect(changeset.errors)}")}
    end
  end

  @impl true
  def handle_event("type_changed", %{"item" => %{"type" => type}}, socket) do
    {:noreply, assign(socket, :item_type, type)}
  end

  @impl true
  def handle_event("type_changed", %{"type" => type}, socket) do
    # 清除高亮状态，重置current_item，确保切换类型时不保留之前输入框的高亮状态
    {:noreply, 
      socket 
      |> assign(:item_type, type)
      |> assign(:current_item, %FormItem{})
      |> assign(:temp_label, nil)}
  end

  @impl true
  def handle_event("form_change", %{"form" => form_params} = params, socket) do
    # 处理表单整体的变化
    target = params["_target"]
    
    IO.puts("表单变更: target=#{inspect(target)}, 值=#{inspect(form_params)}")
    
    socket = 
      cond do
        # 添加防御性检查，确保target是列表
        is_list(target) && (target == ["form", "title"] || List.last(target) == "title") ->
          # 存储表单标题，并写入日志
          title = form_params["title"]
          IO.puts("保存临时标题: #{title}")
          socket |> assign(:temp_title, title)
          
        is_list(target) && (target == ["form", "description"] || List.last(target) == "description") ->
          # 存储表单描述，并写入日志
          description = form_params["description"]
          IO.puts("保存临时描述: #{description}")
          socket |> assign(:temp_description, description)
          
        # 处理表单项的标签字段
        is_list(target) && (target == ["form", "item", "label"] || List.last(target) == "label") ->
          label_value = get_in(form_params, ["item", "label"]) || ""
          IO.puts("保存表单项标签: #{label_value}")
          
          # 同时更新临时标签和当前项的标签
          current_item = socket.assigns.current_item
          updated_item = if current_item, do: Map.put(current_item, :label, label_value), else: current_item
          
          socket 
          |> assign(:temp_label, label_value)
          |> assign(:current_item, updated_item)
          
        true -> 
          socket
      end
      
    {:noreply, socket}
  end

  @impl true
  def handle_event("form_change", %{"value" => value} = params, socket) do
    # 保存表单元素的值变化
    element_id = params["id"] || ""
    
    # 添加直接调试信息
    IO.puts("表单元素变更: id=#{element_id}, value=#{value}")
    
    socket = 
      cond do
        element_id == "form-title" || String.contains?(element_id, "title") ->
          # 存储表单标题，并写入日志
          IO.puts("保存临时标题: #{value}")
          socket 
          |> assign(:temp_title, value)
        element_id == "form-description" || String.contains?(element_id, "description") ->
          # 存储表单描述，并写入日志
          IO.puts("保存临时描述: #{value}")
          socket 
          |> assign(:temp_description, value)
        element_id == "edit-item-label" || element_id == "new-item-label" || String.contains?(element_id, "item-label") || String.contains?(element_id, "label") ->
          # 存储表单项标签，并写入日志
          IO.puts("保存临时标签: #{value}")
          # 同时更新临时标签和当前项的标签
          current_item = socket.assigns.current_item
          updated_item = if current_item, do: Map.put(current_item, :label, value), else: current_item
          
          socket 
          |> assign(:temp_label, value)
          |> assign(:current_item, updated_item)
        true -> 
          socket
      end
      
    {:noreply, socket}
  end
  
  @impl true
  def handle_event("form_change", _params, socket) do
    # 仅用于处理表单变化，不需要更新状态
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_group", %{"group" => _group}, socket) do
    # 侧边栏分组折叠/展开的处理在前端JavaScript中完成
    # 这里只需返回不变的socket
    {:noreply, socket}
  end
  
  @impl true
  def handle_event("add_matrix_row", _params, socket) do
    current_item = socket.assigns.current_item
    
    # 获取当前所有行
    current_rows = current_item.matrix_rows || ["问题1", "问题2", "问题3"]
    next_idx = length(current_rows) + 1
    
    # 添加新行
    updated_item = Map.put(current_item, :matrix_rows, current_rows ++ ["问题#{next_idx}"])
    
    {:noreply, assign(socket, :current_item, updated_item)}
  end
  
  @impl true
  def handle_event("remove_matrix_row", %{"index" => index}, socket) do
    current_item = socket.assigns.current_item
    
    # 获取当前所有行
    current_rows = current_item.matrix_rows || ["问题1", "问题2", "问题3"]
    index = String.to_integer(index)
    
    # 确保至少保留一行
    if length(current_rows) > 1 do
      # 删除指定行
      updated_rows = List.delete_at(current_rows, index)
      updated_item = Map.put(current_item, :matrix_rows, updated_rows)
      
      {:noreply, assign(socket, :current_item, updated_item)}
    else
      {:noreply, socket}
    end
  end
  
  @impl true
  def handle_event("add_matrix_column", _params, socket) do
    current_item = socket.assigns.current_item
    
    # 获取当前所有列
    current_columns = current_item.matrix_columns || ["选项A", "选项B", "选项C"]
    next_idx = length(current_columns)
    column_letter = <<65 + next_idx::utf8>> # A=65, B=66, ...
    
    # 添加新列
    updated_item = Map.put(current_item, :matrix_columns, current_columns ++ ["选项#{column_letter}"])
    
    {:noreply, assign(socket, :current_item, updated_item)}
  end
  
  @impl true
  def handle_event("remove_matrix_column", %{"index" => index}, socket) do
    current_item = socket.assigns.current_item
    
    # 获取当前所有列
    current_columns = current_item.matrix_columns || ["选项A", "选项B", "选项C"]
    index = String.to_integer(index)
    
    # 确保至少保留一列
    if length(current_columns) > 1 do
      # 删除指定列
      updated_columns = List.delete_at(current_columns, index)
      updated_item = Map.put(current_item, :matrix_columns, updated_columns)
      
      {:noreply, assign(socket, :current_item, updated_item)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("add_option", _params, socket) do
    current_options = socket.assigns.item_options
    # 使用字母A/B/C/D等作为选项标签
    next_idx = length(current_options)
    option_letter = <<65 + next_idx::utf8>> # A=65, B=66, ...
    # 确保新选项包含所有必要的键，特别是图片相关的键设为 nil
    new_option = %{
      id: Ecto.UUID.generate(), 
      label: "选项#{option_letter}", 
      value: "option_#{String.downcase(option_letter)}",
      image_id: nil, 
      image_filename: nil
    }
    
    {:noreply, assign(socket, :item_options, current_options ++ [new_option])}
  end

  @impl true
  def handle_event("remove_option", %{"index" => index}, socket) do
    index = String.to_integer(index)
    current_options = socket.assigns.item_options
    updated_options = List.delete_at(current_options, index)
    
    {:noreply, assign(socket, :item_options, updated_options)}
  end

  @impl true
  def handle_event("save_item", %{"item" => item_params} = params, socket) do
    # --- Debugging: Inspect state at start of save_item ---
    IO.puts("[Debug save_item start] Received item_options: #{inspect socket.assigns.item_options}")
    current_item_at_start = socket.assigns.current_item
    current_item_options_at_start = if current_item_at_start, do: Map.get(current_item_at_start, :options), else: "current_item is nil"
    IO.puts("[Debug save_item start] Received current_item.options: #{inspect current_item_options_at_start}")
    # --- End Debugging ---
    
    form = socket.assigns.form
    current_item = socket.assigns.current_item
    editing_item_id = socket.assigns.editing_item_id
    item_options = socket.assigns.item_options # 使用当前socket中的选项

    # 调试参数
    IO.puts("==== 表单项保存调试信息 ====")
    IO.puts("传入参数结构: #{inspect(params)}")
    IO.puts("Socket中的选项 (:item_options): #{inspect(item_options)}")
    
    # 处理 item 参数 (类型转换, required 标准化)
    clean_item_params = process_item_params(item_params)
    item_type = clean_item_params["type"]

    # 区分是更新还是添加
    if current_item && (current_item.id || editing_item_id) do
      # 更新现有表单项
      item_id_to_update = editing_item_id || current_item.id
      existing_item = Forms.get_form_item(item_id_to_update)
      
      if existing_item do
        IO.puts("更新现有表单项 ID: #{item_id_to_update}")
        
        # 如果是矩阵类型，确保行列存在
        clean_item_params = if item_type == :matrix do
           rows = Map.get(clean_item_params, "matrix_rows") || existing_item.matrix_rows || []
           cols = Map.get(clean_item_params, "matrix_columns") || existing_item.matrix_columns || []
           Map.merge(clean_item_params, %{"matrix_rows" => rows, "matrix_columns" => cols})
        else
          clean_item_params
        end

        case Forms.update_form_item(existing_item, clean_item_params) do
          {:ok, updated_item} ->
            IO.puts("表单项更新成功: id=#{updated_item.id}, label=#{updated_item.label}")
            
            # 直接使用当前选项状态，不需要再处理图片上传
            # 因为每个选项的图片已经在apply_upload_to_option中处理过了
            process_options(updated_item, item_options)
            
            # 强制重新加载表单数据
            socket = reload_form_and_update_socket(socket, form.id, "表单项已更新")
            
            {:noreply,
              socket
              |> assign(:current_item, nil)
              |> assign(:editing_item, false)
              |> assign(:editing_item_id, nil) 
              |> assign(:item_options, []) # 清空临时选项
              |> assign(:current_option_index, nil) # 清除当前选项索引
            }
            
          {:error, changeset} ->
            IO.puts("表单项更新失败: #{inspect(changeset.errors)}")
            error_msg = inspect(changeset.errors)
            {:noreply, put_flash(socket, :error, "表单项更新失败: #{error_msg}")}
        end
      else
        {:noreply, put_flash(socket, :error, "要更新的表单项不存在")}
      end
    else
      # 添加新表单项
      clean_params = process_item_params(item_params)
      
      case Forms.add_form_item(form, clean_params) do
        {:ok, new_item} ->
          IO.puts("成功添加新表单项: id=#{new_item.id}, label=#{new_item.label}, type=#{inspect(new_item.type)}")
          
          # 直接使用当前选项状态，不需要再处理图片上传
          # 因为每个选项的图片已经在apply_upload_to_option中处理过了
          process_options(new_item, item_options)
          
          # 强制重新加载表单数据
          socket = reload_form_and_update_socket(socket, form.id, "表单项已添加")
            
          {:noreply, 
            socket
            |> assign(:current_item, nil)
            |> assign(:editing_item, false)
            |> assign(:editing_item_id, nil) 
            |> assign(:item_options, []) # 清空临时选项
            |> assign(:current_option_index, nil) # 清除当前选项索引
          }
          
        {:error, changeset} ->
          IO.puts("添加表单项失败! 错误: #{inspect(changeset.errors)}")
          error_msg = inspect(changeset.errors)
          
          {:noreply, 
            socket
            |> put_flash(:error, "表单项添加失败: #{error_msg}")
          }
      end
    end
  end

  @impl true
  def handle_event("delete_item", %{"id" => id}, socket) do
    item = Forms.get_form_item(id)
    
    if item do
      # 设置当前选择的表单项以便确认删除
      {:noreply, assign(socket, :delete_item_id, id)}
    else
      {:noreply, put_flash(socket, :error, "表单项不存在")}
    end
  end
  
  @impl true
  def handle_event("confirm_delete", _params, socket) do
    id = socket.assigns.delete_item_id
    item = Forms.get_form_item(id)
    
    if item do
      case Forms.delete_form_item(item) do
        {:ok, _} ->
          # 获取完整的表单包括关联项
          form_id = socket.assigns.form.id
          
          # 使用公共函数重新加载表单
          socket = reload_form_and_update_socket(socket, form_id, "表单项已删除")
          
          # 清除删除项ID
          {:noreply, assign(socket, :delete_item_id, nil)}
          
        {:error, _} ->
          {:noreply, 
            socket
            |> assign(:delete_item_id, nil)
            |> put_flash(:error, "表单项删除失败")
          }
      end
    else
      {:noreply, 
        socket
        |> assign(:delete_item_id, nil)
        |> put_flash(:error, "表单项不存在")
      }
    end
  end
  
  @impl true
  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, :delete_item_id, nil)}
  end

  @impl true
  def handle_event("reorder_items", %{"item_ids" => item_ids}, socket) do
    form_id = socket.assigns.form.id
    
    case Forms.reorder_form_items(form_id, item_ids) do
      :ok ->
        # 重新加载表单项
        updated_form = Forms.get_form(form_id)
        
        {:noreply, 
          socket
          |> assign(:form, updated_form)
          |> assign(:form_items, updated_form.items)
        }
        
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "表单项排序失败: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("publish_form", _params, socket) do
    form = socket.assigns.form
    
    if Enum.empty?(form.items) do
      {:noreply, put_flash(socket, :error, "表单至少需要一个表单项才能发布")}
    else
      # 显示确认提示
      {:noreply, assign(socket, :show_publish_confirm, true)}
    end
  end
  
  @impl true
  def handle_event("confirm_publish", _params, socket) do
    form = socket.assigns.form
    
    case Forms.publish_form(form) do
      {:ok, updated_form} ->
        {:noreply, 
          socket
          |> assign(:form, updated_form)
          |> assign(:show_publish_confirm, false)
          |> put_flash(:info, "表单已发布")
        }
        
      {:error, :already_published} ->
        {:noreply, 
          socket
          |> assign(:show_publish_confirm, false)
          |> put_flash(:info, "表单已经是发布状态")
        }
        
      {:error, reason} ->
        {:noreply, 
          socket
          |> assign(:show_publish_confirm, false)
          |> put_flash(:error, "表单发布失败: #{inspect(reason)}")
        }
    end
  end
  
  @impl true
  def handle_event("cancel_publish", _params, socket) do
    {:noreply, assign(socket, :show_publish_confirm, false)}
  end
  
  @impl true
  def handle_event("change_category", %{"category" => category}, socket) do
    # 将类别字符串转为原子
    category_atom = String.to_existing_atom(category)
    
    {:noreply, 
      socket
      |> assign(:active_category, category_atom)
      |> assign(:search_term, nil) # 切换类别时清空搜索
    }
  end
  
  @impl true
  def handle_event("search_item_types", %{"search" => search_term}, socket) do
    filtered_types = if search_term == "" do
      nil # 空搜索恢复正常类别显示
    else
      Forms.search_form_item_types(search_term)
    end
    
    {:noreply, 
      socket
      |> assign(:search_term, filtered_types)
    }
  end
  
  @impl true
  # 处理异步表单项添加后的事件，确保界面正确更新
  def handle_info({:update_matrix_defaults, updated_item}, socket) do
    IO.puts("Updating matrix defaults")
    {:noreply, assign(socket, :current_item, updated_item)}
  end
  
  def handle_info(:after_item_added, socket) do
    # 重新获取最新数据
    updated_form = Forms.get_form(socket.assigns.form.id)
    IO.puts("异步更新表单项，确保渲染: #{length(updated_form.items)}项")
    
    # 收集所有页面的表单项
    all_form_items = 
      Enum.flat_map(updated_form.pages, fn page -> 
        # 提取每个页面的表单项
        page.items || []
      end)
    
    IO.puts("从页面收集到 #{length(all_form_items)} 个表单项")
    
    # 输出所有表单项，用于调试
    items_debug = Enum.map(all_form_items, &"#{&1.id}: #{&1.label}") |> Enum.join(", ")
    IO.puts("表单项详情: #{items_debug}")
    
    # 在测试环境中，也手动查询所有表单项以验证
    if Mix.env() == :test do
      # 使用不同的查询方式再次获取表单项
      alias MyApp.Forms.FormItem
      import Ecto.Query
      
      form_id = socket.assigns.form.id
      direct_items = MyApp.Repo.all(from i in FormItem, where: i.form_id == ^form_id, order_by: i.order)
      IO.puts("直接查询到 #{length(direct_items)} 个表单项")
      
      direct_labels = Enum.map(direct_items, &"#{&1.id}: #{&1.label}") |> Enum.join(", ")
      IO.puts("直接查询表单项: #{direct_labels}")
    end
    
    {:noreply, 
      socket
      |> assign(:form, updated_form)
      |> assign(:form_items, all_form_items)  # 使用从页面收集的表单项
    }
  end


  # 辅助函数

  # 处理表单项参数
  defp process_item_params(params) do
    # 确保所有键都是字符串
    params = normalize_params(params)
    
    # 类型转换
    params = convert_type_to_atom(params)
    
    # 必填项处理
    normalize_required_field(params)
  end
  
  # 检查是否需要选项的表单项类型
  defp requires_options?(item_type) when is_atom(item_type) do
    item_type in [:radio, :checkbox, :dropdown]
  end
  
  defp requires_options?(item_type) when is_binary(item_type) do
    item_type in ["radio", "checkbox", "dropdown"]
  end
  
  defp requires_options?(_), do: false
  
  # 检查矩阵类型控件是否有行和列
  defp validate_matrix(socket, item_type) do
    current_item = socket.assigns.current_item
    
    if (item_type == :matrix or item_type == "matrix") do
      matrix_rows = current_item.matrix_rows || []
      matrix_columns = current_item.matrix_columns || []
      
      IO.puts("Matrix validation: rows=#{inspect(matrix_rows)}, columns=#{inspect(matrix_columns)}")
      
      # 确保行和列都有默认值
      matrix_rows = if Enum.empty?(matrix_rows) do
        default_rows = ["问题1", "问题2", "问题3"]
        IO.puts("Using default rows: #{inspect(default_rows)}")
        default_rows
      else
        matrix_rows
      end
      
      matrix_columns = if Enum.empty?(matrix_columns) do
        default_columns = ["选项A", "选项B", "选项C"]
        IO.puts("Using default columns: #{inspect(default_columns)}")
        default_columns
      else
        matrix_columns
      end
      
      # 确保原始item有行列字段
      updated_item = current_item
        |> Map.put(:matrix_rows, matrix_rows)
        |> Map.put(:matrix_columns, matrix_columns)
        |> Map.put(:matrix_type, current_item.matrix_type || :single)
      
      # 立即更新socket的current_item
      socket = assign(socket, :current_item, updated_item)
      
      # 也异步发送更新指令，确保UI能响应
      Process.send_after(self(), {:update_matrix_defaults, updated_item}, 50)
      
      # 返回更新后的socket，而不是简单的:ok
      {:ok, socket}
    else
      {:ok, socket}
    end
  end
  
  # 确保所有键都是字符串
  defp normalize_params(params) do
    params
    |> Enum.map(fn {k, v} -> {to_string(k), v} end)
    |> Map.new()
  end
  
  # 将类型字符串转换为atom
  defp convert_type_to_atom(params) do
    case params["type"] do
      "text_input" -> 
        IO.puts("转换类型 text_input 为 atom")
        Map.put(params, "type", :text_input)
      "textarea" -> Map.put(params, "type", :textarea)
      "radio" -> 
        IO.puts("转换类型 radio 为 atom")
        Map.put(params, "type", :radio)
      "checkbox" -> Map.put(params, "type", :checkbox)
      "dropdown" -> Map.put(params, "type", :dropdown)
      "rating" -> Map.put(params, "type", :rating)
      "number" -> 
        IO.puts("转换类型 number 为 atom")
        Map.put(params, "type", :number)
      "email" -> 
        IO.puts("转换类型 email 为 atom")
        Map.put(params, "type", :email)
      "phone" -> 
        IO.puts("转换类型 phone 为 atom")
        Map.put(params, "type", :phone)
      "date" -> 
        IO.puts("转换类型 date 为 atom")
        Map.put(params, "type", :date)
      "time" -> 
        IO.puts("转换类型 time 为 atom")
        Map.put(params, "type", :time)
      "region" -> 
        IO.puts("转换类型 region 为 atom")
        Map.put(params, "type", :region)
      "matrix" -> 
        IO.puts("转换类型 matrix 为 atom")
        Map.put(params, "type", :matrix)
      type when is_binary(type) -> 
        IO.puts("转换其他字符串类型 #{type} 为 atom")
        Map.put(params, "type", String.to_existing_atom(type))
      _ -> 
        IO.puts("无法转换类型: #{inspect(params["type"])}")
        params
    end
  end
  
  # 处理required字段的值
  defp normalize_required_field(params) do
    IO.puts("转换后的类型: #{inspect(params["type"])}, 类型: #{if is_atom(params["type"]), do: "atom", else: "非atom"}")
    
    case params["required"] do
      "true" -> Map.put(params, "required", true)
      true -> Map.put(params, "required", true)
      "on" -> Map.put(params, "required", true)
      nil -> Map.put(params, "required", false)
      false -> Map.put(params, "required", false)
      "false" -> Map.put(params, "required", false)
      _ -> params
    end
  end

  # 处理选项图片上传
  defp process_option_images(socket, options, form_item_id, form_id) do
    IO.puts("\n==== 处理选项图片上传 ====")
    
    # 遍历所有选项，处理其中待上传的图片
    Enum.map(options, fn option ->
      # 获取选项索引（直接使用列表位置）
      option_index = Enum.find_index(options, fn opt -> opt.id == option.id end)
      option_ref = "option-image-#{option_index}"
      
      # 检查该选项是否有上传引用和待上传项
      if upload = socket.assigns.uploads[option_ref] do
        if upload.entries != [] do
          # 有图片等待上传，消耗上传项
          IO.puts("处理选项 #{option_index} 的图片上传")
          
          # 使用 Phoenix.LiveView 提供的 consume_uploaded_entries 函数
          upload_results = Phoenix.LiveView.consume_uploaded_entries(socket, option_ref, fn %{path: path}, entry ->
            # 存储图片文件
            ext = Path.extname(entry.client_name)
            filename = "#{Ecto.UUID.generate()}#{ext}"
            dest_path = Path.join([:code.priv_dir(:my_app), "static", "uploads", filename])
            
            # 确保目标目录存在
            File.mkdir_p!(Path.dirname(dest_path))
            
            # 复制文件到目标位置
            File.cp!(path, dest_path)
            
            # 如果选项有旧图片，尝试删除
            if option.image_id do
              old_image_id = option.image_id
              Task.start(fn -> 
                case Upload.delete_file(old_image_id) do
                  {:ok, _} -> IO.puts("旧选项图片已删除: #{old_image_id}")
                  {:error, reason} -> IO.puts("旧选项图片删除失败: #{inspect(reason)}")
                end
              end)
            end
            
            # 创建新的文件记录
            case Upload.save_uploaded_file(form_id, form_item_id, %{
              original_filename: entry.client_name,
              filename: filename,
              path: "/uploads/#{filename}",
              content_type: entry.client_type,
              size: entry.client_size
            }) do
              {:ok, file} -> 
                {:ok, %{id: file.id, filename: filename}}
              
              {:error, changeset} ->
                error_message = changeset.errors
                |> Enum.map(fn {field, {msg, _}} -> "#{field}: #{msg}" end)
                |> Enum.join(", ")
                IO.puts("图片文件记录创建失败: #{error_message}")
                {:error, "图片保存失败: #{error_message}"}
            end
          end)
          
          case upload_results do
            [{:ok, %{id: image_id, filename: filename}}] ->
              # 返回带图片信息的选项
              IO.puts("选项 #{option_index} 图片上传成功: id=#{image_id}, filename=#{filename}")
              Map.merge(option, %{image_id: image_id, image_filename: filename})
            
            _ ->
              # 保持原始选项不变
              IO.puts("选项 #{option_index} 图片处理失败或无上传")
              option
          end
        else
          # 有上传引用但没有文件
          option
        end
      else
        # 没有上传引用，返回原始选项
        option
      end
    end)
  end

  # 处理选项
  defp process_options(item, options_list) do
    # 处理表单项选项
    IO.puts("\n==== 处理表单项选项 ====")
    IO.puts("表单项: #{inspect(item)}")
    IO.puts("传入选项列表: #{inspect(options_list)}") # 打印传入的选项列表
    
    # 先获取当前数据库中的选项以备参考（主要用于更新场景，判断是否需要删除旧选项）
    current_options = case MyApp.Repo.preload(item, :options).options do
      nil -> 
        IO.puts("选项关联未加载或为nil，使用空列表")
        []
      options when is_list(options) -> 
        IO.puts("选项已加载，当前数据库有 #{length(options)} 个选项")
        options
    end
    IO.puts("当前数据库选项数量: #{length(current_options)}")
    
    # 直接使用传入的 options_list (可能已经包含处理过的图片信息)
    # 提取需要的字段来构建用于保存的参数 Map 列表
    options_to_save = options_list
      |> Enum.map(fn opt ->
          # 提取字段
          %{
            "label" => opt.label || "", 
            "value" => opt.value || "",
            "image_id" => opt.image_id, # image_id 可能为 nil
            "image_filename" => opt.image_filename # image_filename 可能为 nil
          }
        end)
      |> Enum.filter(fn opt -> 
          # 过滤掉完全空的选项（除非它有关联的图片）
          opt["label"] != "" || opt["value"] != "" || !is_nil(opt["image_id"])
        end)

    IO.puts("最终准备保存的选项数量: #{length(options_to_save)}")
    IO.puts("最终选项内容: #{inspect(options_to_save)}")
    
    # 使用 Multi 来确保原子性：先删除旧选项，再添加新选项
    multi = Ecto.Multi.new()
    
    # 1. 删除旧选项
    multi = Enum.reduce(current_options, multi, fn option, multi_acc ->
      IO.puts("准备删除旧选项: #{option.id}")
      Ecto.Multi.delete(multi_acc, "delete_option_#{option.id}", option)
    end)
    
    # 2. 添加新选项 (使用新的 options_to_save 列表)
    multi = Enum.with_index(options_to_save, 1) 
            |> Enum.reduce(multi, fn {option_params, index}, multi_acc ->
                IO.puts("准备添加新选项: #{inspect(option_params)}，顺序: #{index}")
                # 添加 order 字段
                params_with_order = Map.put(option_params, "order", index)
                
                # 创建 ItemOption changeset
                changeset = MyApp.Forms.ItemOption.changeset(%MyApp.Forms.ItemOption{form_item_id: item.id}, params_with_order)
                
                Ecto.Multi.insert(multi_acc, "insert_option_#{index}", changeset)
            end)
            
    # 执行事务
    case MyApp.Repo.transaction(multi) do
      {:ok, _result_map} ->
        IO.puts("选项事务成功")
        # 重新加载并返回更新后的项目，确保选项已关联
        updated_item = Forms.get_form_item_with_options(item.id)
        IO.puts("更新后的表单项: #{inspect(updated_item.id)}")
        IO.puts("选项数量: #{length(updated_item.options || [])}")
        updated_item
        
      {:error, failed_operation, failed_value, _changes_so_far} ->
        IO.puts("选项事务失败在操作: #{inspect(failed_operation)}")
        IO.puts("失败原因: #{inspect(failed_value)}")
        # 返回原始 item，或者可以考虑返回错误信息
        item # 或者 {:error, ...}
    end
  end
  
  # 调试函数 - 测试选项提取逻辑
  defp debug_options_extraction(params) do
    IO.puts("\n--- 选项提取调试 ---")
    
    # 1. 检查params是否包含item键
    IO.puts("1. params包含item键: #{Map.has_key?(params, "item")}")
    
    # 2. 检查item是否包含options键
    item = Map.get(params, "item", %{})
    IO.puts("2. item包含options键: #{Map.has_key?(item, "options")}")
    
    # 3. 输出options的结构
    options = Map.get(item, "options", nil)
    IO.puts("3. options类型: #{inspect(options && typeof(options) || "nil")}")
    IO.puts("   options值: #{inspect(options)}")
    
    # 4. 使用get_options_from_params测试提取逻辑
    extracted_options = get_options_from_params(item)
    IO.puts("4. 提取的选项数量: #{length(extracted_options)}")
    IO.puts("   提取的选项: #{inspect(extracted_options)}")
    
    # 5. 测试函数的各个分支
    IO.puts("\n5. 测试get_options_from_params函数各分支:")
    
    test_map1 = %{"options" => [%{"label" => "测试1", "value" => "test1"}]}
    test_map2 = %{"options" => %{"0" => %{"label" => "测试2", "value" => "test2"}}}
    test_map3 = %{"no_options" => true}
    
    IO.puts("   测试列表选项: #{length(get_options_from_params(test_map1))}")
    IO.puts("   测试映射选项: #{length(get_options_from_params(test_map2))}")
    IO.puts("   测试无选项: #{length(get_options_from_params(test_map3))}")
    
    IO.puts("--- 选项提取调试结束 ---\n")
  end
  
  # 类型检查辅助函数
  defp typeof(x) do
    cond do
      is_binary(x) -> "字符串"
      is_boolean(x) -> "布尔值"
      is_atom(x) -> "原子"
      is_integer(x) -> "整数"
      is_float(x) -> "浮点数"
      is_map(x) -> "映射"
      is_list(x) -> "列表"
      is_tuple(x) -> "元组"
      true -> "未知类型"
    end
  end

  # 从参数中提取选项 - 需要为调试函数保留
  defp get_options_from_params(%{"options" => options}) when is_list(options) do
    IO.puts("使用分支1: options是列表")
    options
  end
  
  defp get_options_from_params(%{"options" => options}) when is_map(options) do
    IO.puts("使用分支2: options是映射")
    # 将Map格式的选项转为列表，确保排序正确
    options 
    |> Enum.sort_by(fn {key, _} -> key end)  # 确保选项按顺序处理
    |> Enum.map(fn {_, opt} -> opt end)
    |> Enum.filter(fn opt -> 
      is_map(opt) && Map.has_key?(opt, "label") && Map.has_key?(opt, "value")
    end)
  end
  
  defp get_options_from_params(%{"item" => %{"options" => options}}) do
    IO.puts("使用分支3: 嵌套在item下的options")
    get_options_from_params(%{"options" => options})
  end
  
  defp get_options_from_params(_) do
    IO.puts("使用分支4: 无法提取选项")
    []
  end

  # 公共函数：重新加载表单并更新socket
  defp reload_form_and_update_socket(socket, form_id, info_message) do
    # 强制重新加载，确保所有字段都已更新
    updated_form = Forms.get_form(form_id)
    
    IO.puts("更新后的表单: title=#{updated_form.title}, description=#{updated_form.description}")
    
    # 收集所有页面的表单项
    all_form_items = 
      Enum.flat_map(updated_form.pages, fn page -> 
        # 提取每个页面的表单项
        page.items || []
      end)
    
    IO.puts("重新加载表单项: 从页面收集到#{length(all_form_items)}个项目")
    
    socket
    |> assign(:form, updated_form)
    |> assign(:form_items, all_form_items)  # 使用从页面收集的表单项
    |> assign(:editing_form_info, false)
    |> put_flash(:info, info_message)
  end

  #
  # 页面管理相关事件处理
  #
  
  @impl true
  def handle_event("add_page", _params, socket) do
    {:noreply, 
      socket
      |> assign(:editing_page, true)
      |> assign(:current_page, nil)
    }
  end
  
  @impl true
  def handle_event("edit_page", %{"id" => id}, socket) do
    page = Enum.find(socket.assigns.form.pages, fn p -> p.id == id end)
    
    if page do
      {:noreply, 
        socket
        |> assign(:editing_page, true)
        |> assign(:current_page, page)
      }
    else
      {:noreply, put_flash(socket, :error, "页面不存在")}
    end
  end
  
  @impl true
  def handle_event("cancel_edit_page", _params, socket) do
    {:noreply, 
      socket
      |> assign(:editing_page, false)
      |> assign(:current_page, nil)
    }
  end
  
  @impl true
  def handle_event("save_page", %{"page" => page_params}, socket) do
    form = socket.assigns.form
    current_page = socket.assigns.current_page
    
    if current_page do
      # 更新现有页面
      case Forms.update_form_page(current_page, page_params) do
        {:ok, _updated_page} ->
          # 重新加载表单以获取更新后的页面数据
          updated_form = Forms.get_form(form.id)
          
          {:noreply, 
            socket
            |> assign(:form, updated_form)
            |> assign(:editing_page, false)
            |> assign(:current_page, nil)
            |> put_flash(:info, "页面已更新")
          }
          
        {:error, changeset} ->
          {:noreply, put_flash(socket, :error, "页面更新失败: #{inspect(changeset.errors)}")}
      end
    else
      # 创建新页面
      case Forms.create_form_page(form, page_params) do
        {:ok, _new_page} ->
          # 重新加载表单以获取新页面数据
          updated_form = Forms.get_form(form.id)
          
          {:noreply, 
            socket
            |> assign(:form, updated_form)
            |> assign(:editing_page, false)
            |> assign(:current_page, nil)
            |> put_flash(:info, "页面已添加")
          }
          
        {:error, changeset} ->
          {:noreply, put_flash(socket, :error, "页面添加失败: #{inspect(changeset.errors)}")}
      end
    end
  end
  
  @impl true
  def handle_event("delete_page", %{"id" => id}, socket) do
    # 设置要删除的页面ID，以便确认
    {:noreply, assign(socket, :delete_page_id, id)}
  end
  
  @impl true
  def handle_event("confirm_delete_page", _params, socket) do
    id = socket.assigns.delete_page_id
    form = socket.assigns.form
    
    # 查找页面
    page = Enum.find(form.pages, fn p -> p.id == id end)
    
    if page do
      case Forms.delete_form_page(page) do
        {:ok, _} ->
          # 重新加载表单
          updated_form = Forms.get_form(form.id)
          
          {:noreply, 
            socket
            |> assign(:form, updated_form)
            |> assign(:delete_page_id, nil)
            |> put_flash(:info, "页面已删除")
          }
          
        {:error, _} ->
          {:noreply, 
            socket
            |> assign(:delete_page_id, nil)
            |> put_flash(:error, "页面删除失败")
          }
      end
    else
      {:noreply, 
        socket
        |> assign(:delete_page_id, nil)
        |> put_flash(:error, "页面不存在")
      }
    end
  end
  
  @impl true
  def handle_event("cancel_delete_page", _params, socket) do
    {:noreply, assign(socket, :delete_page_id, nil)}
  end
  
  @impl true
  def handle_event("pages_reordered", %{"pageIds" => page_ids}, socket) do
    form = socket.assigns.form
    
    case Forms.reorder_form_pages(form.id, page_ids) do
      {:ok, _} ->
        # 重新加载表单
        updated_form = Forms.get_form(form.id)
        
        {:noreply, 
          socket
          |> assign(:form, updated_form)
        }
        
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "页面排序失败: #{inspect(reason)}")}
    end
  end
  
  @impl true
  def handle_event("item_moved_to_page", %{"itemId" => item_id, "targetPageId" => page_id}, socket) do
    case Forms.move_item_to_page(item_id, page_id) do
      {:ok, _} ->
        # 重新加载表单
        updated_form = Forms.get_form(socket.assigns.form.id)
        
        {:noreply, 
          socket
          |> assign(:form, updated_form)
          |> assign(:form_items, updated_form.items)
        }
        
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "移动表单项失败: #{inspect(reason)}")}
    end
  end
  
  # 辅助函数：显示选中的控件类型名称
  defp display_selected_type(nil), do: "未选择"
  defp display_selected_type("text_input"), do: "文本输入"
  defp display_selected_type("textarea"), do: "文本区域"
  defp display_selected_type("radio"), do: "单选按钮"
  defp display_selected_type("dropdown"), do: "下拉菜单"
  defp display_selected_type("checkbox"), do: "复选框"
  defp display_selected_type("rating"), do: "评分"
  defp display_selected_type("number"), do: "数字输入"
  defp display_selected_type("email"), do: "邮箱输入"
  defp display_selected_type("phone"), do: "电话号码"
  defp display_selected_type("date"), do: "日期选择"
  defp display_selected_type("time"), do: "时间选择"
  defp display_selected_type("region"), do: "地区选择"
  defp display_selected_type("matrix"), do: "矩阵题"
  defp display_selected_type("image_choice"), do: "图片选择"
  defp display_selected_type("file_upload"), do: "文件上传"
  defp display_selected_type(_), do: "未知类型"
  
  # 条件相关辅助函数（简化版）
  defp find_source_item(nil, _available_items), do: nil
  defp find_source_item(source_id, available_items) do
    Enum.find(available_items, fn item -> item.id == source_id end)
  end
  
  # 这些函数已经从FormComponents导入:
  @impl true
  def handle_event("select_image_for_option", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    
    # 记录当前正在编辑的选项索引
    socket = assign(socket, :current_option_index, index)
    
    # 为此选项准备上传引用
    option_ref = "option-image-#{index}"
    socket = Phoenix.LiveView.allow_upload(socket, option_ref, 
      accept: ~w(.jpg .jpeg .png .gif),
      max_entries: 1,
      max_file_size: 5_000_000
    )
    
    # 准备图片上传
    {:noreply, socket}
  end
  
  @impl true
  def handle_event("remove_image_from_option", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    options = socket.assigns.item_options
    
    if index >= 0 and index < length(options) do
      # 获取要移除图片的选项
      option = Enum.at(options, index)
      
      # 移除相关的图片信息
      updated_option = option
        |> Map.delete(:image_id)
        |> Map.delete(:image_filename)
      
      # 更新选项列表
      updated_options = List.replace_at(options, index, updated_option)
      
      # 如果有图片ID，尝试删除图片文件（异步，不等待结果）
      if option.image_id do
        old_image_id = option.image_id
        Task.start(fn -> 
          case Upload.delete_file(old_image_id) do
            {:ok, _} -> IO.puts("旧选项图片已删除: #{old_image_id}")
            {:error, reason} -> IO.puts("旧选项图片删除失败: #{inspect(reason)}")
          end
        end)
      end
      
      {:noreply, assign(socket, :item_options, updated_options)}
    else
      {:noreply, socket}
    end
  end
  
  # 取消图片上传模态框
  @impl true
  def handle_event("cancel_image_upload", _params, socket) do
    {:noreply, assign(socket, :current_option_index, nil)}
  end
  
  # 取消单个上传条目
  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    # 找出该ref对应的upload key
    option_index = socket.assigns.current_option_index
    option_ref = "option-image-#{option_index}"
    
    # 使用正确的upload key取消上传
    {:noreply, Phoenix.LiveView.cancel_upload(socket, option_ref, ref)}
  end
  
  # 验证上传
  @impl true
  def handle_event("validate_upload", _params, socket) do
    # 验证上传并更新socket
    {:noreply, socket}
  end
  
  # 处理图片上传完成事件
  @impl true
  def handle_event("upload_image", _params, socket) do
    option_index = socket.assigns.current_option_index
    options = socket.assigns.item_options
    
    # 确保索引有效
    if option_index >= 0 and option_index < length(options) do
      option = Enum.at(options, option_index)
      option_ref = "option-image-#{option_index}"
      
      # 创建并配置该选项的上传引用
      socket = Phoenix.LiveView.allow_upload(socket, option_ref, 
        accept: ~w(.jpg .jpeg .png .gif),
        max_entries: 1,
        max_file_size: 5_000_000
      )
      
      # 更新模态框状态
      {:noreply, socket}
    else
      # 索引无效
      {:noreply, 
        socket 
        |> put_flash(:error, "无效的选项索引")
        |> assign(:current_option_index, nil) # 关闭模态框
      }
    end
  end
  
  @impl true
  def handle_event("apply_upload_to_option", _params, socket) do
    option_index = socket.assigns.current_option_index
    options = socket.assigns.item_options
    current_item = socket.assigns.current_item
    
    # 确保索引有效
    if option_index >= 0 and option_index < length(options) do
      option = Enum.at(options, option_index)
      option_ref = "option-image-#{option_index}"
      
      # 检查是否有图片可上传
      if upload = socket.assigns.uploads[option_ref] do
        if upload.entries != [] do
          form_id = socket.assigns.form.id
          # 如果表单项还没有保存，则使用临时ID
          form_item_id = if current_item && current_item.id, do: current_item.id, else: "temp_#{Ecto.UUID.generate()}"
          
          # 处理图片上传
          upload_results = Phoenix.LiveView.consume_uploaded_entries(socket, option_ref, fn %{path: path}, entry ->
            # 存储图片文件
            ext = Path.extname(entry.client_name)
            filename = "#{Ecto.UUID.generate()}#{ext}"
            dest_path = Path.join([:code.priv_dir(:my_app), "static", "uploads", filename])
            
            # 确保目标目录存在
            File.mkdir_p!(Path.dirname(dest_path))
            
            # 复制文件到目标位置
            File.cp!(path, dest_path)
            
            # 如果选项有旧图片，尝试删除
            if option.image_id do
              old_image_id = option.image_id
              Task.start(fn -> 
                case Upload.delete_file(old_image_id) do
                  {:ok, _} -> IO.puts("旧选项图片已删除: #{old_image_id}")
                  {:error, reason} -> IO.puts("旧选项图片删除失败: #{inspect(reason)}")
                end
              end)
            end
            
            # 创建新的文件记录
            case Upload.save_uploaded_file(form_id, form_item_id, %{
              original_filename: entry.client_name,
              filename: filename,
              path: "/uploads/#{filename}",
              content_type: entry.client_type,
              size: entry.client_size
            }) do
              {:ok, file} -> 
                {:ok, %{id: file.id, filename: filename}}
              
              {:error, changeset} ->
                error_message = changeset.errors
                |> Enum.map(fn {field, {msg, _}} -> "#{field}: #{msg}" end)
                |> Enum.join(", ")
                IO.puts("图片文件记录创建失败: #{error_message}")
                {:error, "图片保存失败: #{error_message}"}
            end
          end)
          
          # 根据上传结果更新选项
          case upload_results do
            [{:ok, %{id: image_id, filename: filename}}] ->
              # 更新选项的图片信息
              updated_option = Map.merge(option, %{
                image_id: image_id,
                image_filename: filename
              })
              
              # 更新选项列表
              updated_options = List.replace_at(options, option_index, updated_option)
              
              # 同时更新 current_item 中的选项
              updated_current_item = if current_item do
                %{current_item | options: updated_options}
              else
                current_item
              end
              
              IO.puts("选项 #{option_index} 图片上传成功并应用到选项预览")
              
              # 关闭图片上传模态框并更新状态
              {:noreply, 
                socket
                |> assign(:item_options, updated_options)
                |> assign(:current_item, updated_current_item)
                |> assign(:current_option_index, nil) # 关闭模态框
                |> put_flash(:info, "图片上传成功！")
              }
              
            _ ->
              {:noreply, 
                socket 
                |> put_flash(:error, "图片上传或保存失败")
              }
          end
        else
          {:noreply, 
            socket 
            |> put_flash(:error, "请先选择要上传的图片")
          }
        end
      else
        {:noreply, 
          socket 
          |> put_flash(:error, "上传组件未准备好")
        }
      end
    else
      # 索引无效
      {:noreply, 
        socket 
        |> put_flash(:error, "无效的选项索引")
        |> assign(:current_option_index, nil) # 关闭模态框
      }
    end
  end
  
  # 辅助函数：将上传错误转换为友好字符串
  defp error_to_string(:too_large), do: "文件太大"
  defp error_to_string(:too_many_files), do: "文件数量过多"
  defp error_to_string(:not_accepted), do: "文件类型不被接受"
  defp error_to_string(_), do: "无效的文件"
  
  # 格式化文件大小
  defp format_bytes(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_048_576 -> # 1 MB
        "#{Float.round(bytes / 1_048_576, 1)} MB"
      bytes >= 1024 -> # 1 KB
        "#{Float.round(bytes / 1024, 1)} KB"
      true ->
        "#{bytes} B"
    end
  end
  defp format_bytes(_), do: "未知大小"
end