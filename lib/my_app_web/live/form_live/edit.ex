defmodule MyAppWeb.FormLive.Edit do
  use MyAppWeb, :live_view

  alias MyApp.Forms
  alias MyApp.Forms.FormItem
  # Repo在测试环境中的直接查询中使用，但可以通过完全限定名称访问
  # alias MyApp.Repo
  # 移除未使用的ItemOption别名
  
  import Ecto.Query
  import MyAppWeb.FormComponents
  import Phoenix.LiveView, only: [redirect: 2, put_flash: 3, push_navigate: 2]

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    current_user = socket.assigns.current_user
    
    # 获取控件类型
    all_types = Forms.list_available_form_item_types()
    
    case Forms.get_form(id) do
      nil ->
        {:ok, 
          socket
          |> put_flash(:error, "表单不存在")
          |> push_navigate(to: ~p"/forms")
        }
        
      form ->
        if form.user_id == current_user.id do
          # 确保表单有默认页面
          Forms.assign_default_page(form)
          
          # 重新加载表单以获取页面信息
          form_with_pages = Forms.get_form(id)
          
          # 获取所有表单项，确保它们有正确的页面关联
          all_form_items = 
            Enum.flat_map(form_with_pages.pages, fn page -> 
              # 提取每个页面的表单项
              page.items || []
            end)
          
          # 确保添加任何未关联的表单项到默认页面，以便它们能被显示
          if length(form_with_pages.items) > length(all_form_items) do
            # 首先迁移未关联页面的表单项到默认页面
            {:ok, migrated_items} = Forms.migrate_items_to_default_page(form_with_pages)
            IO.puts("迁移了#{length(migrated_items)}个未关联页面的表单项到默认页面")
            
            # 重新加载表单以获取更新后的关联
            form_with_pages = Forms.get_form(id)
            
            # 重新收集所有表单项
            all_form_items = 
              Enum.flat_map(form_with_pages.pages, fn page -> 
                page.items || []
              end)
          end
            
          IO.puts("加载表单项: 发现#{length(all_form_items)}个项目")
          
          {:ok, 
            socket
            |> assign(:page_title, "编辑表单")
            |> assign(:form, form_with_pages)
            |> assign(:form_changeset, Forms.change_form(form_with_pages))
            |> assign(:editing_form_info, true)
            |> assign(:form_items, all_form_items)  # 使用从页面收集的表单项
            |> assign(:current_item, nil)
            |> assign(:editing_item, false)
            |> assign(:item_options, [])
            |> assign(:item_type, nil)
            |> assign(:delete_item_id, nil)
            |> assign(:show_publish_confirm, false)
            # 控件分类相关状态
            |> assign(:all_item_types, all_types) # 按类别分组的控件类型
            |> assign(:active_category, :basic) # 当前激活的类别
            |> assign(:search_term, nil) # 搜索关键词
            # 初始化临时值，用于表单编辑
            |> assign(:temp_title, form_with_pages.title)
            |> assign(:temp_description, form_with_pages.description)
            # 页面管理相关状态
            |> assign(:editing_page, false)
            |> assign(:current_page, nil)
            |> assign(:delete_page_id, nil)
            |> assign(:form_preview_mode, false)
            |> assign(:preview_current_page_idx, 0)
            # 条件逻辑相关状态
            |> assign(:editing_conditions, false)  # 是否正在编辑条件
            |> assign(:condition_type, :visibility)  # 当前编辑的条件类型：visibility 或 required
            |> assign(:current_condition, nil)  # 当前正在编辑的条件
          }
        else
          {:ok,
            socket
            |> put_flash(:error, "您没有权限编辑此表单")
            |> redirect(to: "/forms")
          }
        end
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
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
    
    # 给当前表单项分配一个ID，防止有多个"添加问题"按钮
    {:noreply, 
      socket
      |> assign(:current_item, %FormItem{type: :text_input, required: false, page_id: page_id})
      |> assign(:item_options, [])
      |> assign(:item_type, "text_input")
      |> assign(:editing_item, true)
      |> assign(:temp_label, "")  # 清除之前可能存在的临时标签
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
      
      # 确保初始化临时标签值，便于编辑
      {:noreply, 
        socket
        |> assign(:current_item, item)
        |> assign(:item_options, options)
        |> assign(:item_type, to_string(item.type))
        |> assign(:editing_item, true)
        |> assign(:temp_label, item.label)
      }
    else
      {:noreply, put_flash(socket, :error, "表单项不存在")}
    end
  end

  @impl true
  def handle_event("cancel_edit_item", _params, socket) do
    {:noreply, 
      socket
      |> assign(:current_item, nil)
      |> assign(:editing_item, false)
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
    
    # 如果条件为空，则传递nil，否则将条件转换为JSON
    condition_json = if is_nil(condition), do: nil, else: Jason.encode!(condition)
    
    # 根据条件类型更新表单项
    result = case condition_type do
      :visibility ->
        Forms.add_condition_to_form_item(form_item, condition, :visibility)
        
      :required ->
        Forms.add_condition_to_form_item(form_item, condition, :required)
    end
    
    case result do
      {:ok, updated_item} ->
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
        element_id == "edit-item-label" || element_id == "new-item-label" || String.contains?(element_id, "item-label") ->
          # 存储表单项标签，并写入日志
          IO.puts("保存临时标签: #{value}")
          socket 
          |> assign(:temp_label, value)
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
    new_option = %{id: Ecto.UUID.generate(), label: "选项#{option_letter}", value: "option_#{String.downcase(option_letter)}"}
    
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
  def handle_event("save_item", params, socket) do
    IO.puts("\n==== 表单项保存调试信息 ====")
    IO.puts("参数结构: #{inspect(params)}")
    
    # 测试选项提取逻辑
    debug_options_extraction(params)
    
    # 处理表单项标签和类型
    item_type = socket.assigns.item_type
    new_label = case params do
      %{"item" => %{"label" => label}} when label != "" -> 
        label
      _ -> 
        # 如果没有提供标签，使用默认值
        case item_type do
          "radio" -> "新单选问题"
          "matrix" -> "新矩阵题"
          _ -> "新文本问题"  
        end
    end
    
    # 确保表单项类型正确设置
    socket = assign(socket, :item_type, item_type)
    socket = assign(socket, :temp_label, new_label)
    # 处理表单提交或无参数的情况
    item_params = params["item"] || %{}
    form = socket.assigns.form
    current_item = socket.assigns.current_item
    
    # 处理选项数据
    item_params = process_item_params(item_params)
    
    if current_item.id do
      # 更新现有表单项 - 确保只有字符串键
      clean_params = 
        Map.new(item_params, fn
          # 原子键转字符串
          {k, v} when is_atom(k) -> {to_string(k), v}
          # 保留字符串键
          {k, v} -> {k, v} 
        end)
      
      # 删除强制使用固定标签值的测试代码，使用用户输入的实际标签  
      IO.puts("使用用户输入标签值: label=#{clean_params["label"]}")
        
      case Forms.update_form_item(current_item, clean_params) do
        {:ok, updated_item} ->
          # 如果是单选按钮或下拉菜单类型，需要添加选项
          if updated_item.type == :radio or updated_item.type == :dropdown do
            IO.puts("添加选项到#{updated_item.type}类型表单项")
            process_options(updated_item, item_params)
          end
          
          # 强制重新加载表单和表单项，确保所有更改都已应用
          updated_form = Forms.get_form(socket.assigns.form.id)
          
          {:noreply, 
            socket
            |> assign(:form, updated_form)
            |> assign(:form_items, updated_form.items)
            |> assign(:current_item, nil)
            |> assign(:editing_item, false)
            |> assign(:item_options, [])
            |> put_flash(:info, "表单项已更新")
          }
          
        {:error, changeset} ->
          {:noreply, put_flash(socket, :error, "表单项更新失败: #{inspect(changeset.errors)}")}
      end
    else
      # 添加新表单项
      # 准备参数 - 确保只有字符串键
      clean_params = 
        Map.new(item_params, fn
          # 原子键转字符串
          {k, v} when is_atom(k) -> {to_string(k), v}
          # 保留字符串键
          {k, v} -> {k, v} 
        end)
      
      # 使用用户输入的标签或生成默认标签
      label = if Map.has_key?(clean_params, "label") && clean_params["label"] != "" do
        # 如果参数中有标签，使用参数中的标签
        clean_params["label"]
      else
        # 否则使用临时标签或默认值
        socket.assigns[:temp_label] || case socket.assigns.item_type do
          "radio" -> "新单选问题"
          _ -> "新文本问题"  
        end
      end
      
      # 打印标签信息
      IO.puts("使用标签: #{label}, 来源: #{if Map.has_key?(clean_params, "label"), do: "表单参数", else: "临时存储或默认值"}")
      
      # 确保设置标签和必填属性
      clean_params = clean_params
        |> Map.put("label", label)
        |> Map.put("required", Map.get(clean_params, "required", true))  # 默认为必填
      
      # 添加类型参数 - 确保类型总是有效值
      clean_params = if Map.has_key?(clean_params, "type") && clean_params["type"] in [:text_input, :radio, :textarea, :checkbox, :dropdown, :rating, :number, :email, :phone, :date, :time, :region] do
        clean_params
      else
        # 从字符串转换为atom类型
        type_atom = case socket.assigns.item_type do
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
          _ -> :text_input  # 默认为文本输入
        end
        
        IO.puts("标准化表单项类型为 #{inspect(type_atom)}")
        Map.put(clean_params, "type", type_atom)
      end
      
      IO.puts("添加新表单项，使用标签: #{label}, 类型: #{inspect(clean_params["type"])}, 参数: #{inspect(clean_params)}")
      
      # 打印当前item_type，确认类型设置正确
      IO.puts("当前socket.assigns.item_type: #{inspect(socket.assigns.item_type)}")
        
      # 尝试保存表单项
      case Forms.add_form_item(form, clean_params) do
        {:ok, new_item} ->
          IO.puts("成功添加新表单项: id=#{new_item.id}, label=#{new_item.label}, type=#{inspect(new_item.type)}")
          
          # 如果是单选按钮或下拉菜单类型，需要添加选项
          if new_item.type == :radio or new_item.type == :dropdown do
            IO.puts("添加选项到#{new_item.type}类型表单项")
            process_options(new_item, item_params)
          end
          
          # 强制将改动提交到数据库
          :timer.sleep(50)
            
          # 重新加载表单项，确保获取完整数据
          updated_form = Forms.get_form(form.id)
          
          # 确认表单项是否成功添加
          item_labels = Enum.map(updated_form.items, & &1.label) |> Enum.join(", ")
          IO.puts("更新后的表单项: #{item_labels}")
          IO.puts("表单项数量: #{length(updated_form.items)}")
          
          socket = socket
            |> assign(:form, updated_form)
            |> assign(:form_items, updated_form.items)
            |> assign(:current_item, nil)
            |> assign(:editing_item, false)
            |> assign(:item_options, [])
            |> put_flash(:info, "表单项已添加")
            
          # 强制视图重新渲染
          Process.send_after(self(), :after_item_added, 100)
          
          {:noreply, socket}
          
        {:error, changeset} ->
          # 添加失败，显示错误信息
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

  # 处理选项
  defp process_options(item, params) do
    # 处理表单项选项
    IO.puts("\n==== 处理表单项选项 ====")
    IO.puts("表单项: #{inspect(item)}")
    
    # 先获取当前选项以备参考
    current_options = case item.options do
      %Ecto.Association.NotLoaded{} -> 
        IO.puts("选项关联未加载，使用空列表")
        []
      options when is_list(options) -> 
        IO.puts("选项已加载，当前有 #{length(options)} 个选项")
        options
      _ -> 
        IO.puts("其他情况，使用空列表")
        []
    end
    IO.puts("当前选项数量: #{length(current_options)}")
    
    # 从表单中获取选项 - 直接检查表单参数中的选项数据
    item_options = Map.get(params, "options", %{})
    
    # 处理表单中提交的选项数据
    extracted_options = 
      if is_map(item_options) do
        item_options
        |> Enum.sort_by(fn {key, _} -> key end)  # 确保选项按顺序处理
        |> Enum.map(fn {_, opt} -> 
          label = Map.get(opt, "label", "")
          value = Map.get(opt, "value", "")
          %{"label" => label, "value" => value}
        end)
        |> Enum.filter(fn opt -> 
          opt["label"] != "" && opt["value"] != ""
        end)
      else
        []
      end
      
    IO.puts("从表单提取到选项数量: #{length(extracted_options)}")
    IO.puts("选项内容: #{inspect(extracted_options)}")
    
    # 如果表单中没有选项但当前有选项，保留现有选项
    options = 
      cond do
        # 如果有提取到表单中的选项，使用表单数据
        length(extracted_options) > 0 ->
          IO.puts("使用从表单中提取的选项")
          extracted_options
          
        # 如果当前已有选项，保留现有选项
        length(current_options) > 0 ->
          IO.puts("使用现有选项")
          Enum.map(current_options, fn opt -> 
            %{"label" => opt.label, "value" => opt.value}
          end)
          
        # 两者都没有，使用默认选项
        true ->
          IO.puts("使用默认选项")
          [
            %{"label" => "选项A", "value" => "option_a"},
            %{"label" => "选项B", "value" => "option_b"}
          ]
      end
    
    IO.puts("最终使用选项数量: #{length(options)}")
    IO.puts("最终选项内容: #{inspect(options)}")
    
    # 先删除现有选项（如果更新现有表单项）
    case item.options do
      %Ecto.Association.NotLoaded{} -> 
        IO.puts("选项未加载，跳过删除操作")
      options when is_list(options) and length(options) > 0 ->
        IO.puts("删除#{length(options)}个现有选项")
        Enum.each(options, fn option ->
          Forms.delete_item_option(option)
        end)
      _ ->
        IO.puts("没有现有选项需要删除")
    end
    
    # 添加所有选项  
    Enum.each(options, fn option_params ->
      # 确保使用字符串键，避免混合键错误
      {:ok, option} = Forms.add_item_option(item, option_params)
      IO.puts("已添加选项: #{inspect(option.label)}")
    end)
    
    # 重新加载并返回更新后的项目
    updated_item = Forms.get_form_item_with_options(item.id)
    IO.puts("更新后的表单项: #{inspect(updated_item.id)}")
    IO.puts("选项数量: #{length(updated_item.options || [])}")
    updated_item
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
  
  @impl true
  def handle_event("toggle_preview", _params, socket) do
    # 切换预览模式
    form_preview_mode = not socket.assigns.form_preview_mode
    
    # 如果进入预览模式，设置当前页面为第一页
    preview_current_page_idx = if form_preview_mode, do: 0, else: socket.assigns.preview_current_page_idx
    
    {:noreply, 
      socket
      |> assign(:form_preview_mode, form_preview_mode)
      |> assign(:preview_current_page_idx, preview_current_page_idx)
    }
  end
  
  @impl true
  def handle_event("preview_next_page", _params, socket) do
    # 切换到下一页
    pages = socket.assigns.form.pages
    current_idx = socket.assigns.preview_current_page_idx
    
    # 确保不超出页面范围
    new_idx = if current_idx < length(pages) - 1, do: current_idx + 1, else: current_idx
    
    {:noreply, assign(socket, :preview_current_page_idx, new_idx)}
  end
  
  @impl true
  def handle_event("preview_prev_page", _params, socket) do
    # 切换到上一页
    current_idx = socket.assigns.preview_current_page_idx
    
    # 确保不小于0
    new_idx = if current_idx > 0, do: current_idx - 1, else: 0
    
    {:noreply, assign(socket, :preview_current_page_idx, new_idx)}
  end
  
  @impl true
  def handle_event("preview_jump_to_page", %{"index" => index}, socket) do
    # 直接跳转到指定页面
    index = String.to_integer(index)
    pages = socket.assigns.form.pages
    
    # 确保索引在有效范围内
    valid_index = max(0, min(index, length(pages) - 1))
    
    {:noreply, assign(socket, :preview_current_page_idx, valid_index)}
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
  
  # 这些函数已经从FormComponents导入:
end