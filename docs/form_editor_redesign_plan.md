# 表单编辑器分页式设计改进方案

## 当前问题分析

目前表单编辑器存在以下问题：

1. **控件添加机制不一致**：
   - 顶部添加按钮未传递page_id，导致控件可能被错误关联到默认页面
   - 页面内添加按钮仅在页面为空时显示，添加一个控件后就消失
   - 侧边栏添加按钮也不传递page_id
   - 导致添加同样的控件时出现不同行为

2. **用户体验混乱**：
   - 三种不同的添加控件方式让用户困惑
   - 页面控件关联关系不清晰
   - 页面跳转和控件管理逻辑割裂

## 设计目标

采用类似表单提交页面的分页式设计，保证直观的用户体验并确保控件与页面的准确关联。

## 页面渲染机制详解

### 分页渲染组件

表单提交页面使用了`MyAppWeb.FormTemplateRenderer`组件进行分页渲染，主要包含以下组件：

1. **主要渲染函数**：
   - `render_page_with_decorations` - 渲染单个页面及其装饰元素
   - `render_form_with_decorations` - 渲染整个表单及其装饰元素

2. **组件工作流程**：
   - 在LiveView中维护`current_page`和`current_page_idx`状态
   - 通过`get_page_items`函数获取当前页面的表单项
   - 使用渲染器组件展示当前页面内容

3. **从submit.ex借鉴的核心代码**：
   ```elixir
   # 获取当前页面的表单项
   defp get_page_items(form, page) do
     if page do
       # 获取当前页面的表单项
       page.items || []
     else
       # 如果没有页面，返回所有表单项
       form.items || []
     end
   end
   
   # 在mount时初始化页面状态
   socket = assign(socket, %{
     current_page: current_page,
     current_page_idx: current_page_idx,
     pages_status: initialize_pages_status(form.pages || []),
     page_items: page_items
   })
   ```

### Page ID与表单项关联机制

表单项与页面的关联是通过表单项的`page_id`字段实现的：

1. **数据库关联**：
   - 表单项(`form_items`)表包含`page_id`外键字段
   - 页面(`form_pages`)表与表单项是一对多关系

2. **添加控件时关联页面**：
   ```elixir
   # 在添加表单项时指定当前页面ID
   def handle_event("add_item", params, socket) do
     # 获取当前活跃页面
     current_page = socket.assigns.current_page
     current_page_id = current_page && current_page.id
     
     # 创建带有page_id的表单项参数
     attrs = %{
       label: label,
       type: item_type,
       options: options,
       required: required,
       form_id: form.id,
       # 关键：确保传递当前页面ID
       page_id: current_page_id  
     }
     
     # 创建表单项
     {:ok, new_item} = Forms.add_form_item(form, attrs)
     
     # 处理选项等后续逻辑...
   end
   ```

3. **重新加载页面项目**：
   ```elixir
   # 页面切换时重新加载页面项目
   def handle_event("switch_page", %{"page_id" => page_id}, socket) do
     form = socket.assigns.form
     target_page = find_page(form, page_id)
     
     # 获取目标页面的表单项
     page_items = get_page_items(form, target_page)
     
     # 更新socket状态
     {:noreply,
      socket
      |> assign(:current_page, target_page)
      |> assign(:current_page_idx, find_page_index(form, page_id))
      |> assign(:page_items, page_items)}
   end
   ```

## 具体实现方案

### 1. UI结构改进

1. **分页式导航栏**：
   ```html
   <div class="form-pagination-container">
     <!-- 分页导航 -->
     <div class="form-pagination-header">
       <h2 class="form-pagination-title">
         {if @current_page, do: @current_page.title, else: "表单内容"}
       </h2>
       <div class="form-pagination-counter">
         {@current_page_idx + 1} / {length(@form.pages)}
       </div>
     </div>
     
     <!-- 页面切换指示器 -->
     <div class="form-pagination-indicators">
       <%= for {page, idx} <- Enum.with_index(@form.pages || []) do %>
         <button
           type="button"
           class={"form-pagination-indicator #{if idx == @current_page_idx, do: "active", else: ""}"}
           phx-click="switch_page"
           phx-value-page_id={page.id}
         >
           {idx + 1}
         </button>
       <% end %>
     </div>
   </div>
   ```

2. **页面内容显示区**：
   ```html
   <div class="form-page-content">
     <!-- 只显示当前页面的控件 -->
     <%= for item <- @page_items do %>
       <!-- 渲染表单项 -->
     <% end %>
   </div>
   ```

3. **控件添加区**：
   ```html
   <div class="form-item-controls">
     <button 
       phx-click="add_item" 
       phx-value-page_id={@current_page.id} 
       class="add-control-button"
     >
       添加控件到当前页面
     </button>
   </div>
   ```

### 2. 数据流改进

1. **页面ID处理**：
   ```elixir
   # handle_event("add_item", params, socket) 函数修改
   def handle_event("add_item", params, socket) do
     # 始终使用当前显示页面的ID
     current_page = socket.assigns.current_page
     page_id = current_page && current_page.id
     
     # 确保页面ID有效
     page_id = if is_nil(page_id) do
       # 如果没有当前页面，使用默认页面
       socket.assigns.form.default_page_id
     else
       page_id
     end
     
     # 其余添加逻辑
     # ...
   end
   ```

2. **页面切换逻辑**：
   ```elixir
   # 添加页面切换处理函数
   def handle_event("switch_page", %{"page_id" => page_id}, socket) do
     form = socket.assigns.form
     
     # 查找目标页面
     target_page = Enum.find(form.pages, fn p -> p.id == page_id end)
     target_idx = Enum.find_index(form.pages, fn p -> p.id == page_id end) || 0
     
     # 获取页面表单项
     page_items = get_page_items(form, target_page)
     
     # 更新socket状态
     {:noreply, 
      socket
      |> assign(:current_page, target_page)
      |> assign(:current_page_idx, target_idx)
      |> assign(:page_items, page_items)
      |> assign(:editing_item, false)
      |> assign(:current_item, nil)}
   end
   ```

3. **表单项加载函数**：
   ```elixir
   # 获取页面的表单项
   defp get_page_items(form, page) do
     if page do
       # 过滤出当前页面的表单项
       Enum.filter(form.items || [], fn item -> 
         item.page_id == page.id
       end)
     else
       # 如果没有页面，返回所有表单项
       form.items || []
     end
   end
   ```

### 3. Socket状态初始化

在mount函数中添加分页相关状态：

```elixir
# 在mount中初始化分页状态
def mount(%{"id" => id}, _session, socket) do
  form = Forms.get_form(id)
  
  # 获取第一个页面作为默认页面
  current_page = List.first(form.pages || [])
  current_page_idx = 0
  
  # 获取当前页面的表单项
  page_items = get_page_items(form, current_page)
  
  socket =
    socket
    |> assign(:form, form)
    |> assign(:form_items, form.items || [])
    |> assign(:current_page, current_page)
    |> assign(:current_page_idx, current_page_idx)
    |> assign(:page_items, page_items)
    # 其他状态...
  
  {:ok, socket}
end
```

## 实施计划

1. **阶段一**：基础分页导航
   - 实现基本页面切换功能
   - 确保控件正确关联到页面
   
2. **阶段二**：完善控件操作
   - 优化控件添加/编辑/删除流程
   - 实现跨页面控件移动
   
3. **阶段三**：优化用户体验
   - 添加过渡动画
   - 完善页面管理功能
   - 提供表单预览模式

## 兼容性考虑

1. 保留现有的数据结构和数据库设计
2. 确保与现有模板渲染系统兼容
3. 复用FormTemplateRenderer组件的渲染逻辑

## 后续优化方向

1. 添加页面预览功能
2. 实现页面间控件复制功能
3. 提供页面模板功能
4. 优化页面和控件的拖拽排序体验

## 分步实施计划 (实施进度跟踪)

### 第一阶段：状态管理与数据准备 [ ] 未开始

#### 步骤1：扩展Socket状态 [ ] 未开始
1. 修改表单编辑器LiveView的mount函数，添加分页相关状态：
   ```elixir
   # 在mount中初始化分页状态
   def mount(%{"id" => id}, _session, socket) do
     form = Forms.get_form_with_full_preload(id)
     
     # 获取第一个页面作为默认页面
     current_page = List.first(form.pages || [])
     current_page_idx = 0
     
     # 获取当前页面的表单项
     page_items = get_page_items(form, current_page)
     
     socket =
       socket
       |> assign(:form, form)
       |> assign(:form_items, form.items || [])
       |> assign(:current_page, current_page)
       |> assign(:current_page_idx, current_page_idx)
       |> assign(:page_items, page_items)
       # 其他原有状态保持不变
     
     {:ok, socket}
   end
   ```

#### 步骤2：添加辅助函数 [ ] 未开始
1. 实现获取页面表单项的函数：
   ```elixir
   # 获取页面的表单项
   defp get_page_items(form, page) do
     if page do
       # 过滤出当前页面的表单项
       Enum.filter(form.items || [], fn item -> 
         item.page_id == page.id
       end)
     else
       # 如果没有页面，返回所有表单项
       form.items || []
     end
   end
   ```

2. 实现页面查找函数：
   ```elixir
   # 根据ID查找页面
   defp find_page(form, page_id) do
     Enum.find(form.pages || [], fn p -> p.id == page_id end)
   end
   
   # 查找页面索引
   defp find_page_index(form, page_id) do
     Enum.find_index(form.pages || [], fn p -> p.id == page_id end) || 0
   end
   ```

### 第二阶段：基础UI结构改造 [ ] 未开始

#### 步骤3：添加分页导航UI [ ] 未开始
1. 修改模板，添加页面导航部分，但暂不添加交互逻辑：
   ```html
   <!-- 分页导航 - 只增加显示部分 -->
   <div class="form-pagination-container">
     <div class="form-pagination-header">
       <h2 class="form-pagination-title">
         <%= if @current_page, do: @current_page.title, else: "表单内容" %>
       </h2>
       <div class="form-pagination-counter">
         <%= @current_page_idx + 1 %> / <%= length(@form.pages || []) %>
       </div>
     </div>
     
     <div class="form-pagination-indicators">
       <%= for {page, idx} <- Enum.with_index(@form.pages || []) do %>
         <button
           type="button"
           class={"form-pagination-indicator #{if idx == @current_page_idx, do: "active", else: ""}"}
           data-page-id={page.id}
         >
           <%= idx + 1 %>
         </button>
       <% end %>
     </div>
   </div>
   ```

2. 添加相应的CSS样式：
   ```css
   .form-pagination-container {
     display: flex;
     flex-direction: column;
     margin-bottom: 1rem;
   }
   
   .form-pagination-header {
     display: flex;
     justify-content: space-between;
     align-items: center;
   }
   
   .form-pagination-indicators {
     display: flex;
     gap: 0.5rem;
     margin-top: 0.5rem;
   }
   
   .form-pagination-indicator {
     width: 2rem;
     height: 2rem;
     border-radius: 50%;
     border: 1px solid #ccc;
     background: white;
     cursor: pointer;
   }
   
   .form-pagination-indicator.active {
     background: #4299e1;
     color: white;
     border-color: #4299e1;
   }
   ```

#### 步骤4：修改表单项显示逻辑 [ ] 未开始
1. 修改表单项显示部分，只显示当前页面的控件：
   ```html
   <!-- 修改表单项显示部分 -->
   <div class="form-items-container">
     <%= if Enum.empty?(@page_items) do %>
       <div class="empty-form-page">
         <p>当前页面没有表单项</p>
         <button phx-click="show_add_item_modal" class="btn btn-primary">
           添加表单项
         </button>
       </div>
     <% else %>
       <%= for item <- @page_items do %>
         <!-- 原有的表单项渲染逻辑 -->
         <div class="form-item" id={"item-#{item.id}"}>
           <!-- 保持原有的表单项内容不变 -->
         </div>
       <% end %>
     <% end %>
   </div>
   ```

### 第三阶段：添加交互逻辑 [ ] 未开始

#### 步骤5：实现页面切换逻辑 [ ] 未开始
1. 添加页面切换事件处理函数：
   ```elixir
   # 添加页面切换处理函数
   def handle_event("switch_page", %{"page_id" => page_id}, socket) do
     form = socket.assigns.form
     
     # 查找目标页面
     target_page = find_page(form, page_id)
     target_idx = find_page_index(form, page_id)
     
     # 获取页面表单项
     page_items = get_page_items(form, target_page)
     
     # 更新socket状态
     {:noreply, 
      socket
      |> assign(:current_page, target_page)
      |> assign(:current_page_idx, target_idx)
      |> assign(:page_items, page_items)
      |> assign(:editing_item, false)
      |> assign(:current_item, nil)}
   end
   ```

2. 更新页面指示器按钮，添加事件绑定：
   ```html
   <button
     type="button"
     class={"form-pagination-indicator #{if idx == @current_page_idx, do: "active", else: ""}"}
     phx-click="switch_page"
     phx-value-page_id={page.id}
   >
     <%= idx + 1 %>
   </button>
   ```

#### 步骤6：修改控件添加逻辑 [ ] 未开始
1. 修改控件添加函数，确保使用当前页面ID：
   ```elixir
   # 修改控件添加处理函数
   def handle_event("add_item", params, socket) do
     form = socket.assigns.form
     
     # 始终使用当前显示页面的ID
     current_page = socket.assigns.current_page
     page_id = current_page && current_page.id
     
     # 确保页面ID有效
     page_id = if is_nil(page_id) do
       # 如果没有当前页面，使用默认页面或创建一个
       case Forms.assign_default_page(form) do
         {:ok, default_page} -> default_page.id
         _ -> nil
       end
     else
       page_id
     end
     
     # 准备添加表单项参数，包含页面ID
     item_params = Map.put(params, "page_id", page_id)
     
     # 然后继续原有的添加控件逻辑
     # ...
   end
   ```

2. 修改控件添加按钮，确保在每个页面都能看到：
   ```html
   <!-- 在每个页面底部添加控件按钮 -->
   <div class="add-item-container">
     <button phx-click="show_add_item_modal" class="btn btn-primary">
       添加表单项到当前页面
     </button>
   </div>
   ```

### 第四阶段：完善功能 [ ] 未开始

#### 步骤7：实现控件移动功能 [ ] 未开始
1. 添加控件移动到其他页面的处理函数：
   ```elixir
   # 移动控件到其他页面
   def handle_event("move_item_to_page", %{"item_id" => item_id, "page_id" => page_id}, socket) do
     case Forms.move_item_to_page(item_id, page_id) do
       {:ok, _} ->
         # 重新加载表单和当前页面表单项
         updated_form = Forms.get_form_with_full_preload(socket.assigns.form.id)
         current_page = find_page(updated_form, socket.assigns.current_page.id)
         page_items = get_page_items(updated_form, current_page)
         
         {:noreply,
          socket
          |> assign(:form, updated_form)
          |> assign(:form_items, updated_form.items || [])
          |> assign(:page_items, page_items)
          |> put_flash(:info, "控件已移动到其他页面")}
         
       {:error, reason} ->
         {:noreply, put_flash(socket, :error, "移动控件失败: #{inspect(reason)}")}
     end
   end
   ```

2. 为控件添加移动选项：
   ```html
   <!-- 在控件操作菜单中添加移动选项 -->
   <div class="item-menu">
     <div class="dropdown">
       <button class="btn btn-sm dropdown-toggle" type="button" id={"item-menu-#{item.id}"} data-bs-toggle="dropdown">
         操作
       </button>
       <ul class="dropdown-menu">
         <!-- 现有的编辑和删除选项 -->
         <li><a class="dropdown-item" href="#" phx-click="edit_item" phx-value-id={item.id}>编辑</a></li>
         <li><a class="dropdown-item" href="#" phx-click="delete_item" phx-value-id={item.id}>删除</a></li>
         <!-- 添加移动到其他页面选项 -->
         <li><hr class="dropdown-divider"></li>
         <li><span class="dropdown-item-text">移动到页面</span></li>
         <%= for page <- @form.pages do %>
           <%= if page.id != @current_page.id do %>
             <li>
               <a class="dropdown-item" href="#" 
                  phx-click="move_item_to_page" 
                  phx-value-item_id={item.id} 
                  phx-value-page_id={page.id}>
                 <%= page.title %>
               </a>
             </li>
           <% end %>
         <% end %>
       </ul>
     </div>
   </div>
   ```

#### 步骤8：页面管理功能 [ ] 未开始
1. 添加页面管理功能（添加/编辑/删除页面）：
   ```elixir
   # 添加页面处理函数
   def handle_event("add_page", %{"title" => title}, socket) do
     form = socket.assigns.form
     
     case Forms.add_form_page(form, %{title: title}) do
       {:ok, updated_form} ->
         # 切换到新添加的页面
         new_page = List.last(updated_form.pages)
         
         {:noreply,
          socket
          |> assign(:form, updated_form)
          |> assign(:current_page, new_page)
          |> assign(:current_page_idx, length(updated_form.pages) - 1)
          |> assign(:page_items, [])
          |> put_flash(:info, "页面已添加")}
         
       {:error, reason} ->
         {:noreply, put_flash(socket, :error, "添加页面失败: #{inspect(reason)}")}
     end
   end
   
   # 编辑页面标题处理函数
   def handle_event("edit_page", %{"page_id" => page_id, "title" => title}, socket) do
     case Forms.update_form_page(page_id, %{title: title}) do
       {:ok, _} ->
         # 重新加载表单
         updated_form = Forms.get_form_with_full_preload(socket.assigns.form.id)
         
         {:noreply,
          socket
          |> assign(:form, updated_form)
          |> put_flash(:info, "页面标题已更新")}
         
       {:error, reason} ->
         {:noreply, put_flash(socket, :error, "更新页面失败: #{inspect(reason)}")}
     end
   end
   
   # 删除页面处理函数
   def handle_event("delete_page", %{"page_id" => page_id}, socket) do
     # 只有当表单有多个页面时才允许删除
     if length(socket.assigns.form.pages) > 1 do
       case Forms.delete_form_page(page_id) do
         {:ok, _} ->
           # 重新加载表单
           updated_form = Forms.get_form_with_full_preload(socket.assigns.form.id)
           # 切换到第一个页面
           new_current_page = List.first(updated_form.pages)
           new_page_items = get_page_items(updated_form, new_current_page)
           
           {:noreply,
            socket
            |> assign(:form, updated_form)
            |> assign(:current_page, new_current_page)
            |> assign(:current_page_idx, 0)
            |> assign(:page_items, new_page_items)
            |> put_flash(:info, "页面已删除")}
           
         {:error, reason} ->
           {:noreply, put_flash(socket, :error, "删除页面失败: #{inspect(reason)}")}
       end
     else
       {:noreply, put_flash(socket, :error, "无法删除最后一个页面")}
     end
   end
   ```

2. 添加页面管理UI：
   ```html
   <!-- 页面管理工具栏 -->
   <div class="page-management-toolbar">
     <button phx-click="show_add_page_modal" class="btn btn-sm btn-outline-primary">
       添加页面
     </button>
     
     <button phx-click="show_edit_page_modal" phx-value-page_id={@current_page.id} class="btn btn-sm btn-outline-secondary">
       编辑当前页面
     </button>
     
     <%= if length(@form.pages) > 1 do %>
       <button phx-click="show_delete_page_modal" phx-value-page_id={@current_page.id} class="btn btn-sm btn-outline-danger">
         删除当前页面
       </button>
     <% end %>
   </div>
   ```

### 第五阶段：优化与测试 [ ] 未开始

#### 步骤9：优化页面加载和交互体验 [ ] 未开始
1. 添加页面切换动画：
   ```css
   /* 添加页面切换过渡动画 */
   .form-page-content {
     transition: opacity 0.3s ease-in-out;
   }
   
   .form-page-content.changing {
     opacity: 0;
   }
   ```

2. 实现JS钩子处理页面切换动画：
   ```javascript
   let FormEditorHooks = {
     PageTransition: {
       mounted() {
         this.handleEvent("page_changing", () => {
           this.el.classList.add("changing");
           setTimeout(() => {
             this.el.classList.remove("changing");
           }, 300);
         });
       }
     }
   }
   ```

#### 步骤10：完整回归测试 [ ] 未开始
1. 编写测试确保所有功能正常工作：
   - 测试页面切换
   - 测试控件添加到正确页面
   - 测试页面管理功能
   - 测试控件在页面间移动

2. 手动测试用户流程：
   - 表单创建和编辑
   - 多页面添加和管理
   - 复杂表单场景