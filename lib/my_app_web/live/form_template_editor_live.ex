defmodule MyAppWeb.FormTemplateEditorLive do
  use MyAppWeb, :live_view
  import MyAppWeb.FormLive.ItemRendererComponent
  import MyAppWeb.FormComponents
  alias MyApp.FormTemplates
  alias MyApp.Forms.FormItem

  @impl true
  def mount(%{"id" => template_id}, _session, socket) do
    # 加载模板，如果找不到会抛出 Ecto.NoResultsError，由框架处理
    template = FormTemplates.get_template!(template_id)

    # 检查 template.structure 是否为 nil，如果是，则使用空列表
    structure = template.structure || []

    # 确保 structure 是一个列表 (以防数据库中存了非列表数据)
    structure = if is_list(structure), do: structure, else: []

    socket =
      socket
      |> assign(:template, template)
      |> assign(:structure, structure)
      |> assign(:editing_item_id, nil) # 用于控制编辑 Modal
      |> assign(:page_title, "编辑模板结构: #{template.name}") # 设置页面标题
      |> assign(:active_category, :basic) # 默认选中基础控件分类
      |> assign(:item_type, "text_input") # 默认控件类型
      |> assign(:editing_item, false) # 是否正在编辑控件
      |> assign(:current_item, nil) # 当前编辑的控件
      |> assign(:item_options, []) # 控件选项
      |> assign(:search_term, nil) # 搜索关键词
      |> assign(:delete_item_id, nil) # 要删除的控件ID

    {:ok, socket}
  end

  @impl true
  def handle_event("update_structure_order", %{"ordered_ids" => ordered_ids}, socket) do
    # 获取当前模板和结构
    %{template: template, structure: current_structure} = socket.assigns
    
    # 根据新的顺序重新排列结构项
    reordered_structure = reorder_structure_items(current_structure, ordered_ids)
    
    # 保存更新后的模板
    case FormTemplates.update_template(template, %{structure: reordered_structure}) do
      {:ok, updated_template} ->
        {:noreply, 
          socket
          |> assign(:template, updated_template)
          |> assign(:structure, updated_template.structure)
          |> put_flash(:info, "模板结构顺序已更新")
        }
        
      {:error, _changeset} ->
        {:noreply, 
          socket
          |> put_flash(:error, "无法更新模板结构顺序")
        }
    end
  end

  @impl true
  def handle_event("save_structure", _params, socket) do
    # 获取当前模板和结构
    %{template: template, structure: current_structure} = socket.assigns
    
    # 保存当前结构（重用现有顺序，无需重排）
    case FormTemplates.update_template(template, %{structure: current_structure}) do
      {:ok, updated_template} ->
        {:noreply, 
          socket
          |> assign(:template, updated_template)
          |> assign(:structure, updated_template.structure)
          |> put_flash(:info, "模板结构已保存")
        }
        
      {:error, _changeset} ->
        {:noreply, 
          socket
          |> put_flash(:error, "无法保存模板结构")
        }
    end
  end
  
  # 添加从FormLive.Edit复用的事件处理函数
  
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
      ["text_input", "textarea", "radio", "checkbox", "dropdown", "rating", 
      "number", "email", "phone", "date", "time", "region", "matrix", 
      "image_choice", "file_upload"]
      |> Enum.filter(fn type -> 
        String.contains?(type, search_term) || 
        String.contains?(display_selected_type(type), search_term)
      end)
    end
    
    {:noreply, 
      socket
      |> assign(:search_term, filtered_types)
    }
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
  def handle_event("add_item", _params, socket) do
    # 使用当前选择的控件类型
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
    
    # 准备要添加到模板结构的新项目
    new_item = %{
      "id" => Ecto.UUID.generate(),
      "type" => item_type,
      "label" => default_label,
      "required" => false,
      "description" => ""
    }
    
    # 根据控件类型设置特定属性
    new_item = cond do
      item_type == "matrix" ->
        new_item 
        |> Map.put("matrix_rows", ["问题1", "问题2", "问题3"])
        |> Map.put("matrix_columns", ["选项A", "选项B", "选项C"])
        |> Map.put("matrix_type", "single")
      
      item_type == "image_choice" ->
        new_item
        |> Map.put("selection_type", "single")
        |> Map.put("image_caption_position", "bottom")
      
      item_type in ["radio", "checkbox", "dropdown"] ->
        new_item
        |> Map.put("options", [
          %{"id" => Ecto.UUID.generate(), "label" => "选项A", "value" => "option_a"},
          %{"id" => Ecto.UUID.generate(), "label" => "选项B", "value" => "option_b"}
        ])
        
      true -> new_item
    end
    
    # 添加新项目到结构中
    updated_structure = socket.assigns.structure ++ [new_item]
    
    # 保存更新后的模板结构
    case FormTemplates.update_template(socket.assigns.template, %{structure: updated_structure}) do
      {:ok, updated_template} ->
        {:noreply, 
          socket
          |> assign(:template, updated_template)
          |> assign(:structure, updated_template.structure)
          |> put_flash(:info, "已添加新控件")
        }
        
      {:error, _changeset} ->
        {:noreply, 
          socket
          |> put_flash(:error, "无法添加新控件")
        }
    end
  end
  
  @impl true
  def handle_event("delete_item", %{"id" => id}, socket) do
    # 设置当前选择的表单项以便确认删除
    {:noreply, assign(socket, :delete_item_id, id)}
  end
  
  @impl true
  def handle_event("confirm_delete", _params, socket) do
    id = socket.assigns.delete_item_id
    
    # 从结构中移除指定ID的项目
    updated_structure = Enum.reject(socket.assigns.structure, fn item ->
      Map.get(item, "id") == id
    end)
    
    # 保存更新后的模板结构
    case FormTemplates.update_template(socket.assigns.template, %{structure: updated_structure}) do
      {:ok, updated_template} ->
        {:noreply, 
          socket
          |> assign(:template, updated_template)
          |> assign(:structure, updated_template.structure)
          |> assign(:delete_item_id, nil)
          |> put_flash(:info, "控件已删除")
        }
        
      {:error, _changeset} ->
        {:noreply, 
          socket
          |> assign(:delete_item_id, nil)
          |> put_flash(:error, "无法删除控件")
        }
    end
  end
  
  @impl true
  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, :delete_item_id, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="form-editor-container">
      <!-- 模板编辑页面 -->
      <div style="display: flex; max-width: 100%; overflow-hidden;">
        <!-- 左侧控件类型选择栏 -->
        <div style="flex: 0 0 16rem; border-right: 1px solid #e5e7eb; background-color: white; padding: 1rem; overflow-y: auto; height: calc(100vh - 4rem);">
          <h2 style="font-size: 1.125rem; font-weight: 500; margin-bottom: 1rem;">控件类型</h2>
          
          <!-- 分类标签 -->
          <div style="display: flex; border-bottom: 1px solid #e5e7eb; margin-bottom: 1rem;" data-test-id="form-item-category-selector">
            <button 
              phx-click="change_category" 
              phx-value-category="basic"
              data-category="basic"
              style={"padding: 0.5rem 0.75rem; border: none; background: none; font-size: 0.875rem; font-weight: 500; cursor: pointer; border-bottom: 2px solid #{if @active_category == :basic, do: "#4f46e5", else: "transparent"}; color: #{if @active_category == :basic, do: "#4f46e5", else: "#6b7280"}; display: flex; align-items: center; gap: 0.375rem;"}
            >
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.25rem; height: 1.25rem;">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 3v4M3 5h4M6 17v4m-2-2h4m5-16l2.286 6.857L21 12l-5.714 2.143L13 21l-2.286-6.857L5 12l5.714-2.143L13 3z" />
              </svg>
              基础控件
            </button>
            <button 
              phx-click="change_category" 
              phx-value-category="personal"
              data-category="personal"
              style={"padding: 0.5rem 0.75rem; border: none; background: none; font-size: 0.875rem; font-weight: 500; cursor: pointer; border-bottom: 2px solid #{if @active_category == :personal, do: "#4f46e5", else: "transparent"}; color: #{if @active_category == :personal, do: "#4f46e5", else: "#6b7280"}; display: flex; align-items: center; gap: 0.375rem;"}
            >
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.25rem; height: 1.25rem;">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
              </svg>
              个人信息
            </button>
            <button 
              phx-click="change_category" 
              phx-value-category="advanced"
              data-category="advanced"
              style={"padding: 0.5rem 0.75rem; border: none; background: none; font-size: 0.875rem; font-weight: 500; cursor: pointer; border-bottom: 2px solid #{if @active_category == :advanced, do: "#4f46e5", else: "transparent"}; color: #{if @active_category == :advanced, do: "#4f46e5", else: "#6b7280"}; display: flex; align-items: center; gap: 0.375rem;"}
            >
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.25rem; height: 1.25rem;">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19.428 15.428a2 2 0 00-1.022-.547l-2.387-.477a6 6 0 00-3.86.517l-.318.158a6 6 0 01-3.86.517L6.05 15.21a2 2 0 00-1.806.547M8 4h8l-1 1v5.172a2 2 0 00.586 1.414l5 5c1.26 1.26.367 3.414-1.415 3.414H4.828c-1.782 0-2.674-2.154-1.414-3.414l5-5A2 2 0 009 10.172V5L8 4z" />
              </svg>
              高级控件
            </button>
          </div>
          
          <!-- 控件类型搜索 -->
          <div style="margin-bottom: 1rem;">
            <div style="position: relative;">
              <input 
                type="text" 
                placeholder="搜索控件类型..." 
                style="width: 100%; padding: 0.5rem 0.75rem; padding-left: 2rem; border: 1px solid #d1d5db; border-radius: 0.375rem; font-size: 0.875rem;"
                phx-keyup="search_item_types"
                phx-key="Enter"
                name="search"
              />
              <div style="position: absolute; left: 0.5rem; top: 0.5rem; color: #9ca3af;">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor" style="width: 1.25rem; height: 1.25rem;">
                  <path fill-rule="evenodd" d="M8 4a4 4 0 100 8 4 4 0 000-8zM2 8a6 6 0 1110.89 3.476l4.817 4.817a1 1 0 01-1.414 1.414l-4.816-4.816A6 6 0 012 8z" clip-rule="evenodd" />
                </svg>
              </div>
            </div>
          </div>
          
          <!-- 渲染控件类型列表 -->
          <%= if is_nil(@search_term) do %>
            <!-- 分类显示 -->
            <%= if @active_category == :basic do %>
              <div style="margin-bottom: 1rem;">
                <h3 style="font-size: 1rem; font-weight: 500; margin-bottom: 0.5rem; color: #4b5563;">基础控件</h3>
                <div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 0.5rem;">
                  <button 
                    type="button"
                    phx-click="type_changed"
                    phx-value-type="text_input"
                    data-test-id="item-type-text_input"
                    style={"display: flex; flex-direction: column; align-items: center; padding: 0.75rem; border: 1px solid #{if @item_type == "text_input", do: "#4f46e5", else: "#e5e7eb"}; border-radius: 0.375rem; background-color: #{if @item_type == "text_input", do: "#f5f3ff", else: "white"}; cursor: pointer; text-align: center; color: #{if @item_type == "text_input", do: "#4f46e5", else: "#1f2937"};"}
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.5rem; height: 1.5rem; margin-bottom: 0.25rem;">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                    </svg>
                    <div style="font-size: 0.75rem; white-space: nowrap;">文本输入</div>
                  </button>
                  
                  <button 
                    type="button"
                    phx-click="type_changed"
                    phx-value-type="textarea"
                    data-test-id="item-type-textarea"
                    style={"display: flex; flex-direction: column; align-items: center; padding: 0.75rem; border: 1px solid #{if @item_type == "textarea", do: "#4f46e5", else: "#e5e7eb"}; border-radius: 0.375rem; background-color: #{if @item_type == "textarea", do: "#f5f3ff", else: "white"}; cursor: pointer; text-align: center; color: #{if @item_type == "textarea", do: "#4f46e5", else: "#1f2937"};"}
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.5rem; height: 1.5rem; margin-bottom: 0.25rem;">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h7" />
                    </svg>
                    <div style="font-size: 0.75rem; white-space: nowrap;">文本区域</div>
                  </button>
                  
                  <button 
                    type="button"
                    phx-click="type_changed"
                    phx-value-type="radio"
                    data-test-id="item-type-radio"
                    style={"display: flex; flex-direction: column; align-items: center; padding: 0.75rem; border: 1px solid #{if @item_type == "radio", do: "#4f46e5", else: "#e5e7eb"}; border-radius: 0.375rem; background-color: #{if @item_type == "radio", do: "#f5f3ff", else: "white"}; cursor: pointer; text-align: center; color: #{if @item_type == "radio", do: "#4f46e5", else: "#1f2937"};"}
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.5rem; height: 1.5rem; margin-bottom: 0.25rem;">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                    <div style="font-size: 0.75rem; white-space: nowrap;">单选按钮</div>
                  </button>
                  
                  <button 
                    type="button"
                    phx-click="type_changed"
                    phx-value-type="checkbox"
                    data-test-id="item-type-checkbox"
                    style={"display: flex; flex-direction: column; align-items: center; padding: 0.75rem; border: 1px solid #{if @item_type == "checkbox", do: "#4f46e5", else: "#e5e7eb"}; border-radius: 0.375rem; background-color: #{if @item_type == "checkbox", do: "#f5f3ff", else: "white"}; cursor: pointer; text-align: center; color: #{if @item_type == "checkbox", do: "#4f46e5", else: "#1f2937"};"}
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.5rem; height: 1.5rem; margin-bottom: 0.25rem;">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                    </svg>
                    <div style="font-size: 0.75rem; white-space: nowrap;">复选框</div>
                  </button>
                  
                  <button 
                    type="button"
                    phx-click="type_changed"
                    phx-value-type="dropdown"
                    data-test-id="item-type-dropdown"
                    style={"display: flex; flex-direction: column; align-items: center; padding: 0.75rem; border: 1px solid #{if @item_type == "dropdown", do: "#4f46e5", else: "#e5e7eb"}; border-radius: 0.375rem; background-color: #{if @item_type == "dropdown", do: "#f5f3ff", else: "white"}; cursor: pointer; text-align: center; color: #{if @item_type == "dropdown", do: "#4f46e5", else: "#1f2937"};"}
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.5rem; height: 1.5rem; margin-bottom: 0.25rem;">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 9l4-4 4 4m0 6l-4 4-4-4" />
                    </svg>
                    <div style="font-size: 0.75rem; white-space: nowrap;">下拉菜单</div>
                  </button>
                  
                    <button 
                      type="button"
                      phx-click="type_changed"
                    phx-value-type="number"
                    data-test-id="item-type-number"
                    style={"display: flex; flex-direction: column; align-items: center; padding: 0.75rem; border: 1px solid #{if @item_type == "number", do: "#4f46e5", else: "#e5e7eb"}; border-radius: 0.375rem; background-color: #{if @item_type == "number", do: "#f5f3ff", else: "white"}; cursor: pointer; text-align: center; color: #{if @item_type == "number", do: "#4f46e5", else: "#1f2937"};"}
                    >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.5rem; height: 1.5rem; margin-bottom: 0.25rem;">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 20l4-16m2 16l4-16M6 9h14M4 15h14" />
                    </svg>
                    <div style="font-size: 0.75rem; white-space: nowrap;">数字输入</div>
                    </button>
                </div>
              </div>
            <% end %>
            
            <%= if @active_category == :personal do %>
              <div style="margin-bottom: 1rem;">
                <h3 style="font-size: 1rem; font-weight: 500; margin-bottom: 0.5rem; color: #4b5563;">个人信息控件</h3>
                <div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 0.5rem;">
                  <button 
                    type="button"
                    phx-click="type_changed"
                    phx-value-type="email"
                    data-test-id="item-type-email"
                    style={"display: flex; flex-direction: column; align-items: center; padding: 0.75rem; border: 1px solid #{if @item_type == "email", do: "#4f46e5", else: "#e5e7eb"}; border-radius: 0.375rem; background-color: #{if @item_type == "email", do: "#f5f3ff", else: "white"}; cursor: pointer; text-align: center; color: #{if @item_type == "email", do: "#4f46e5", else: "#1f2937"};"}
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.5rem; height: 1.5rem; margin-bottom: 0.25rem;">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                    </svg>
                    <div style="font-size: 0.75rem; white-space: nowrap;">电子邮箱</div>
                  </button>
                  
                  <button 
                    type="button"
                    phx-click="type_changed"
                    phx-value-type="phone"
                    data-test-id="item-type-phone"
                    style={"display: flex; flex-direction: column; align-items: center; padding: 0.75rem; border: 1px solid #{if @item_type == "phone", do: "#4f46e5", else: "#e5e7eb"}; border-radius: 0.375rem; background-color: #{if @item_type == "phone", do: "#f5f3ff", else: "white"}; cursor: pointer; text-align: center; color: #{if @item_type == "phone", do: "#4f46e5", else: "#1f2937"};"}
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.5rem; height: 1.5rem; margin-bottom: 0.25rem;">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z" />
                    </svg>
                    <div style="font-size: 0.75rem; white-space: nowrap;">电话号码</div>
                  </button>
                  
                  <button 
                    type="button"
                    phx-click="type_changed"
                    phx-value-type="date"
                    data-test-id="item-type-date"
                    style={"display: flex; flex-direction: column; align-items: center; padding: 0.75rem; border: 1px solid #{if @item_type == "date", do: "#4f46e5", else: "#e5e7eb"}; border-radius: 0.375rem; background-color: #{if @item_type == "date", do: "#f5f3ff", else: "white"}; cursor: pointer; text-align: center; color: #{if @item_type == "date", do: "#4f46e5", else: "#1f2937"};"}
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.5rem; height: 1.5rem; margin-bottom: 0.25rem;">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                    </svg>
                    <div style="font-size: 0.75rem; white-space: nowrap;">日期选择</div>
                  </button>
                  
                  <button 
                    type="button"
                    phx-click="type_changed"
                    phx-value-type="time"
                    data-test-id="item-type-time"
                    style={"display: flex; flex-direction: column; align-items: center; padding: 0.75rem; border: 1px solid #{if @item_type == "time", do: "#4f46e5", else: "#e5e7eb"}; border-radius: 0.375rem; background-color: #{if @item_type == "time", do: "#f5f3ff", else: "white"}; cursor: pointer; text-align: center; color: #{if @item_type == "time", do: "#4f46e5", else: "#1f2937"};"}
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.5rem; height: 1.5rem; margin-bottom: 0.25rem;">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                    <div style="font-size: 0.75rem; white-space: nowrap;">时间选择</div>
                  </button>
                  
                    <button 
                      type="button"
                      phx-click="type_changed"
                    phx-value-type="region"
                    data-test-id="item-type-region"
                    style={"display: flex; flex-direction: column; align-items: center; padding: 0.75rem; border: 1px solid #{if @item_type == "region", do: "#4f46e5", else: "#e5e7eb"}; border-radius: 0.375rem; background-color: #{if @item_type == "region", do: "#f5f3ff", else: "white"}; cursor: pointer; text-align: center; color: #{if @item_type == "region", do: "#4f46e5", else: "#1f2937"};"}
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.5rem; height: 1.5rem; margin-bottom: 0.25rem;">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
                    </svg>
                    <div style="font-size: 0.75rem; white-space: nowrap;">地区选择</div>
                    </button>
                </div>
              </div>
            <% end %>
            
            <%= if @active_category == :advanced do %>
              <div style="margin-bottom: 1rem;">
                <h3 style="font-size: 1rem; font-weight: 500; margin-bottom: 0.5rem; color: #4b5563;">高级控件</h3>
                <div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 0.5rem;">
                  <button 
                    type="button"
                    phx-click="type_changed"
                    phx-value-type="rating"
                    data-test-id="item-type-rating"
                    style={"display: flex; flex-direction: column; align-items: center; padding: 0.75rem; border: 1px solid #{if @item_type == "rating", do: "#4f46e5", else: "#e5e7eb"}; border-radius: 0.375rem; background-color: #{if @item_type == "rating", do: "#f5f3ff", else: "white"}; cursor: pointer; text-align: center; color: #{if @item_type == "rating", do: "#4f46e5", else: "#1f2937"};"}
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.5rem; height: 1.5rem; margin-bottom: 0.25rem;">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z" />
                    </svg>
                    <div style="font-size: 0.75rem; white-space: nowrap;">评分控件</div>
                  </button>
                  
                  <button 
                    type="button"
                    phx-click="type_changed"
                    phx-value-type="matrix"
                    data-test-id="item-type-matrix"
                    style={"display: flex; flex-direction: column; align-items: center; padding: 0.75rem; border: 1px solid #{if @item_type == "matrix", do: "#4f46e5", else: "#e5e7eb"}; border-radius: 0.375rem; background-color: #{if @item_type == "matrix", do: "#f5f3ff", else: "white"}; cursor: pointer; text-align: center; color: #{if @item_type == "matrix", do: "#4f46e5", else: "#1f2937"};"}
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.5rem; height: 1.5rem; margin-bottom: 0.25rem;">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 10h16M4 14h16M4 18h16" />
                    </svg>
                    <div style="font-size: 0.75rem; white-space: nowrap;">矩阵问题</div>
                  </button>
                  
                  <button 
                    type="button"
                    phx-click="type_changed"
                    phx-value-type="image_choice"
                    data-test-id="item-type-image_choice"
                    style={"display: flex; flex-direction: column; align-items: center; padding: 0.75rem; border: 1px solid #{if @item_type == "image_choice", do: "#4f46e5", else: "#e5e7eb"}; border-radius: 0.375rem; background-color: #{if @item_type == "image_choice", do: "#f5f3ff", else: "white"}; cursor: pointer; text-align: center; color: #{if @item_type == "image_choice", do: "#4f46e5", else: "#1f2937"};"}
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.5rem; height: 1.5rem; margin-bottom: 0.25rem;">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                    </svg>
                    <div style="font-size: 0.75rem; white-space: nowrap;">图片选择</div>
                  </button>
                  
                    <button 
                      type="button"
                      phx-click="type_changed"
                    phx-value-type="file_upload"
                    data-test-id="item-type-file_upload"
                    style={"display: flex; flex-direction: column; align-items: center; padding: 0.75rem; border: 1px solid #{if @item_type == "file_upload", do: "#4f46e5", else: "#e5e7eb"}; border-radius: 0.375rem; background-color: #{if @item_type == "file_upload", do: "#f5f3ff", else: "white"}; cursor: pointer; text-align: center; color: #{if @item_type == "file_upload", do: "#4f46e5", else: "#1f2937"};"}
                    >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.5rem; height: 1.5rem; margin-bottom: 0.25rem;">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
                    </svg>
                    <div style="font-size: 0.75rem; white-space: nowrap;">文件上传</div>
                    </button>
                </div>
              </div>
            <% end %>
          <% else %>
            <!-- 搜索结果显示 -->
            <div style="margin-bottom: 1rem;">
              <h3 style="font-size: 1rem; font-weight: 500; margin-bottom: 0.5rem; color: #4b5563;">搜索结果</h3>
              <%= if Enum.empty?(@search_term) do %>
                <div style="text-align: center; padding: 1rem; color: #6b7280; background-color: #f9fafb; border-radius: 0.375rem;">
                  <p>没有找到匹配的控件类型</p>
                </div>
              <% else %>
                <div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 0.5rem;">
                  <%= for type <- @search_term do %>
                    <button 
                      type="button"
                      phx-click="type_changed"
                      phx-value-type={type}
                      style={"display: flex; flex-direction: column; align-items: center; padding: 0.75rem; border: 1px solid #{if @item_type == to_string(type), do: "#4f46e5", else: "#e5e7eb"}; border-radius: 0.375rem; background-color: #{if @item_type == to_string(type), do: "#f5f3ff", else: "white"}; cursor: pointer; text-align: center; color: #{if @item_type == to_string(type), do: "#4f46e5", else: "#1f2937"};"}
                    >
                      <div style="font-size: 0.75rem; white-space: nowrap;"><%= display_selected_type(type) %></div>
                    </button>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>
          
          <!-- 添加控件按钮 -->
          <div style="margin-top: 1rem;">
            <button 
              type="button"
              id="add-new-form-item-button"
              phx-click="add_item"
              disabled={is_nil(@item_type)}
              style={"width: 100%; padding: 0.75rem; border: none; border-radius: 0.375rem; background-color: #{if is_nil(@item_type), do: "#d1d5db", else: "#4f46e5"}; color: white; font-weight: 500; cursor: #{if is_nil(@item_type), do: "not-allowed", else: "pointer"}; display: flex; justify-content: center; align-items: center; gap: 0.5rem;"}
            >
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.25rem; height: 1.25rem;">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
              </svg>
              添加选中控件
            </button>
          </div>
        </div>
        
        <!-- 右侧内容区域 -->
        <div style="flex: 1; padding: 1.5rem; overflow-y: auto; height: calc(100vh - 4rem);">
          <!-- 模板标题和操作区 -->
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1.5rem;">
            <h1 style="font-size: 1.5rem; font-weight: 700;"><%= @template.name || "未命名模板" %></h1>
            
            <div style="display: flex; gap: 0.75rem;">
              <.link
                patch={~p"/forms"}
                style="display: inline-flex; justify-content: center; padding: 0.5rem 1rem; background-color: white; color: #4b5563; border: 1px solid #d1d5db; border-radius: 0.375rem; font-weight: 500; font-size: 0.875rem; text-decoration: none;"
              >
                返回表单列表
              </.link>
              
              <button 
                type="button"
                phx-click="save_structure"
                style="display: inline-flex; justify-content: center; padding: 0.5rem 1rem; background-color: #4f46e5; color: white; border-radius: 0.375rem; font-weight: 500; font-size: 0.875rem; border: none;"
              >
                保存模板
              </button>
            </div>
          </div>

          <!-- 确认删除对话框 -->
          <%= if @delete_item_id do %>
            <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
              <div class="bg-white rounded-lg p-6 max-w-md w-full shadow-xl">
                <h3 class="text-lg font-medium mb-4">确认删除控件</h3>
                <p class="text-gray-600 mb-6">您确定要删除这个控件吗？此操作无法撤销。</p>
                <div class="flex justify-end space-x-3">
                  <button
                    type="button"
                    phx-click="cancel_delete"
                    class="px-4 py-2 bg-white border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                  >
                    取消
                  </button>
                  <button
                    type="button"
                    phx-click="confirm_delete"
                    data-test-id="confirm-delete"
                    class="inline-flex justify-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-red-600 hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500"
                  >
                    确认删除
                  </button>
                </div>
              </div>
            </div>
          <% end %>
          
          <!-- 模板结构列表 -->
          <div class="form-card">
            <h2 style="font-size: 1.125rem; font-weight: 500; margin-bottom: 1rem;">模板元素</h2>
            
            <div id="structure-list" phx-hook="Sortable" class="space-y-4">
              <%= if Enum.empty?(@structure) do %>
                <div style="text-align: center; padding: 3rem 0;">
                  <div style="margin: 0 auto; height: 3rem; width: 3rem; color: #9ca3af;">
                    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
                    </svg>
                  </div>
                  <h3 style="font-size: 1.125rem; font-weight: 500; color: #1f2937; margin-top: 0.5rem;">模板还没有元素</h3>
                  <p style="margin-top: 0.5rem; font-size: 0.875rem; color: #6b7280;">从左侧选择控件类型并点击"添加选中控件"按钮</p>
                </div>
              <% else %>
                <%= for element <- @structure do %>
                  <% 
                    elem_id = Map.get(element, "id", "unknown")
                    elem_type = Map.get(element, "type", "unknown")
                    elem_label = Map.get(element, "label") || Map.get(element, "title", "未命名元素")
                    elem_required = Map.get(element, "required", false)
                    elem_description = Map.get(element, "description")
                    
                    # 将模板项转换为FormItem结构，以便重用ItemRendererComponent
                    form_item = %{
                      id: elem_id,
                      type: safe_to_atom(elem_type),
                      label: elem_label,
                      required: elem_required,
                      description: elem_description,
                      placeholder: Map.get(element, "placeholder"),
                      options: format_options(Map.get(element, "options", [])),
                      min: Map.get(element, "min"),
                      max: Map.get(element, "max"),
                      step: Map.get(element, "step"),
                      max_rating: Map.get(element, "max_rating", 5),
                      min_date: Map.get(element, "min_date"),
                      max_date: Map.get(element, "max_date"),
                      min_time: Map.get(element, "min_time"),
                      max_time: Map.get(element, "max_time"),
                      time_format: Map.get(element, "time_format", "24h"),
                      show_format_hint: Map.get(element, "show_format_hint"),
                      format_display: Map.get(element, "format_display"),
                      matrix_rows: Map.get(element, "matrix_rows"),
                      matrix_columns: Map.get(element, "matrix_columns"),
                      matrix_type: safe_matrix_type(Map.get(element, "matrix_type")),
                      image_caption_position: safe_caption_position(Map.get(element, "image_caption_position")),
                      selection_type: safe_selection_type(Map.get(element, "selection_type")),
                      multiple_files: Map.get(element, "multiple_files"),
                      max_files: Map.get(element, "max_files"),
                      max_file_size: Map.get(element, "max_file_size"),
                      allowed_extensions: Map.get(element, "allowed_extensions"),
                      region_level: Map.get(element, "region_level"),
                      default_province: Map.get(element, "default_province")
                    }
                  %>
                  <div 
                    id={"item-#{elem_id}"} 
                    data-id={elem_id} 
                    class="p-3 border rounded bg-white shadow-sm form-card"
                  >
                    <div class="flex justify-between items-center">
                      <div class="flex items-center">
                        <span class="drag-handle text-gray-400 hover:text-gray-600 mr-3 cursor-move text-xl">⠿</span>
                        <div>
                          <div class="flex items-center">
                            <span class="font-medium text-gray-700"><%= elem_label %></span>
                            <%= if elem_required do %>
                              <span class="ml-2 text-red-500">*</span>
                            <% end %>
                          </div>
                          <div class="text-xs text-gray-500 mt-1">
                            控件类型: <%= display_selected_type(elem_type) %>
                          </div>
                        </div>
                      </div>
                      
                      <div class="flex gap-2">
                        <button type="button" phx-click="delete_item" phx-value-id={elem_id} style="color: #ef4444; background: none; border: none; cursor: pointer;">
                          删除
                        </button>
                      </div>
                    </div>
                    
                    <%= if elem_description do %>
                      <div class="text-sm text-gray-500 mt-2"><%= elem_description %></div>
                    <% end %>
                    
                    <div class="mt-3 border-t pt-3">
                      <MyAppWeb.FormLive.ItemRendererComponent.render_item item={form_item} mode={:edit_preview} />
                    </div>
                  </div>
                <% end %>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
  
  # 安全地将字符串转换为atom，如果转换失败则返回默认值:text_input
  defp safe_to_atom(type_str) when is_binary(type_str) do
    try do
      String.to_existing_atom(type_str)
    rescue
      ArgumentError -> :text_input
    end
  end
  defp safe_to_atom(_), do: :text_input

  # 安全处理matrix_type值
  defp safe_matrix_type("multiple"), do: :multiple
  defp safe_matrix_type(:multiple), do: :multiple
  defp safe_matrix_type(_), do: :single

  # 安全处理selection_type值
  defp safe_selection_type("multiple"), do: :multiple
  defp safe_selection_type(:multiple), do: :multiple
  defp safe_selection_type(_), do: :single

  # 安全处理image_caption_position值
  defp safe_caption_position("top"), do: :top
  defp safe_caption_position(:top), do: :top
  defp safe_caption_position("none"), do: :none
  defp safe_caption_position(:none), do: :none
  defp safe_caption_position(_), do: :bottom

  # 将模板选项格式化为FormItem需要的格式
  defp format_options(options) when is_list(options) do
    Enum.map(options, fn option ->
      %{
        id: Map.get(option, "id") || Map.get(option, :id) || Ecto.UUID.generate(),
        value: Map.get(option, "value") || Map.get(option, :value) || "",
        label: Map.get(option, "label") || Map.get(option, :label) || "",
        image_filename: Map.get(option, "image_filename") || Map.get(option, :image_filename)
      }
    end)
  end
  defp format_options(_), do: []

  # 根据新的顺序重排结构项
  defp reorder_structure_items(structure, ordered_ids) do
    # 创建一个ID到结构项的映射
    id_to_item_map = Enum.reduce(structure, %{}, fn item, acc ->
      item_id = Map.get(item, "id")
      if item_id, do: Map.put(acc, item_id, item), else: acc
    end)
    
    # 按新顺序重组结构项
    reordered_items = Enum.map(ordered_ids, fn id -> 
      Map.get(id_to_item_map, id)
    end)
    |> Enum.filter(&(&1 != nil))
    
    # 处理可能不在ordered_ids中的项（尽管这种情况应该不会发生）
    missing_items = Enum.filter(structure, fn item ->
      item_id = Map.get(item, "id")
      item_id && !Enum.member?(ordered_ids, item_id)
    end)
    
    # 合并重排序的项和缺失的项
    reordered_items ++ missing_items
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
end
