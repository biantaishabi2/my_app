defmodule MyAppWeb.FormComponents do
  use Phoenix.Component
  import Phoenix.LiveView.Helpers
  import MyAppWeb.CoreComponents

  embed_templates "form_components/*"

  # 这些导入虽然当前未直接使用，但在组件开发中可能需要
  # 保留以备将来扩展组件功能时使用
  # HTML标记处理 - 用于HTML转义和安全处理
  # import Phoenix.HTML
  
  # 表单辅助函数 - 用于生成表单和表单元素
  # import Phoenix.HTML.Form
  
  # LiveView辅助函数 - 用于事件处理和DOM操作
  # import Phoenix.LiveView.Helpers  # 未使用
  
  # 条件逻辑编辑器组件
  attr :id, :string, required: true
  attr :condition, :map, default: nil
  attr :available_items, :list, default: []
  attr :show_delete_button, :boolean, default: true
  attr :target, :string, default: nil
  
  def condition_editor(assigns) do
    ~H"""
    <div class="condition-editor" id={@id} phx-hook="ConditionLogicEditor">
      <%= if @condition do %>
        <%= if @condition.type == :simple do %>
          <!-- 简单条件编辑器 -->
          <div class="simple-condition p-3 border rounded bg-gray-50 mb-2">
            <div class="flex items-center space-x-2">
              <!-- 条件源选择 -->
              <select
                class="condition-source-select form-select"
                data-condition-id={@id}
                name="source_item_id"
              >
                <option value="" disabled selected={@condition.source_item_id == nil}>选择字段</option>
                <%= for item <- @available_items do %>
                  <option value={item.id} selected={@condition.source_item_id == item.id}>
                    <%= item.label %>
                  </option>
                <% end %>
              </select>
              
              <!-- 条件操作符选择 -->
              <select
                class="condition-operator-select form-select"
                data-condition-id={@id}
                name="operator"
              >
                <option value="equals" selected={@condition.operator == "equals"}>等于</option>
                <option value="not_equals" selected={@condition.operator == "not_equals"}>不等于</option>
                <option value="contains" selected={@condition.operator == "contains"}>包含</option>
                <option value="greater_than" selected={@condition.operator == "greater_than"}>大于</option>
                <option value="greater_than_or_equal" selected={@condition.operator == "greater_than_or_equal"}>大于等于</option>
                <option value="less_than" selected={@condition.operator == "less_than"}>小于</option>
                <option value="less_than_or_equal" selected={@condition.operator == "less_than_or_equal"}>小于等于</option>
              </select>
              
              <!-- 条件值输入 -->
              <input
                type="text"
                class="condition-value-input form-input"
                data-condition-id={@id}
                name="value"
                value={@condition.value}
                placeholder="输入值"
              />
              
              <!-- 删除条件按钮 -->
              <%= if @show_delete_button do %>
                <button
                  type="button"
                  class="delete-condition-btn btn btn-icon btn-sm text-red-500"
                  data-condition-id={@id}
                  phx-click="delete_condition"
                  phx-value-condition-id={@id}
                  phx-target={@target}
                >
                  <i class="fas fa-trash"></i>
                </button>
              <% end %>
            </div>
          </div>
        <% else %>
          <!-- 复合条件编辑器 -->
          <div class="compound-condition p-3 border rounded bg-gray-100 mb-2">
            <div class="flex items-center mb-2 justify-between">
              <select
                class="condition-group-type-select form-select w-32"
                data-group-id={@id}
                name="group_type"
              >
                <option value="and" selected={@condition.operator == "and"}>全部满足</option>
                <option value="or" selected={@condition.operator == "or"}>任一满足</option>
              </select>
              
              <%= if @show_delete_button do %>
                <button
                  type="button"
                  class="delete-condition-btn btn btn-icon btn-sm text-red-500"
                  data-condition-id={@id}
                  phx-click="delete_condition"
                  phx-value-condition-id={@id}
                  phx-target={@target}
                >
                  <i class="fas fa-trash"></i>
                </button>
              <% end %>
            </div>
            
            <div class="pl-4 border-l-2 border-indigo-300">
              <!-- 显示子条件 -->
              <%= for {child, index} <- Enum.with_index(@condition.conditions) do %>
                <%= condition_editor(%{
                  id: "#{@id}_#{index}",
                  condition: child,
                  available_items: @available_items,
                  show_delete_button: true,
                  target: @target
                }) %>
              <% end %>
              
              <!-- 添加子条件按钮 -->
              <div class="flex space-x-2 mt-2">
                <button
                  type="button"
                  class="add-condition-btn btn btn-sm btn-outline"
                  phx-click="add_simple_condition"
                  phx-value-parent-id={@id}
                  phx-target={@target}
                >
                  <i class="fas fa-plus mr-1"></i> 添加条件
                </button>
                <button
                  type="button"
                  class="add-condition-group-btn btn btn-sm btn-outline"
                  phx-click="add_condition_group"
                  phx-value-parent-id={@id}
                  phx-target={@target}
                >
                  <i class="fas fa-object-group mr-1"></i> 添加条件组
                </button>
              </div>
            </div>
          </div>
        <% end %>
      <% else %>
        <!-- 空条件状态 -->
        <div class="empty-condition p-4 border rounded text-center text-gray-500">
          <p>未设置条件</p>
          <div class="flex space-x-2 justify-center mt-2">
            <button
              type="button"
              class="add-condition-btn btn btn-sm btn-outline"
              phx-click="add_simple_condition"
              phx-target={@target}
            >
              <i class="fas fa-plus mr-1"></i> 添加条件
            </button>
            <button
              type="button"
              class="add-condition-group-btn btn btn-sm btn-outline"
              phx-click="add_condition_group"
              phx-target={@target}
            >
              <i class="fas fa-object-group mr-1"></i> 添加条件组
            </button>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
  
  # 辅助函数：获取控件类型图标
  def get_type_icon(type) do
    case type do
      :text_input -> "fa-keyboard"
      :textarea -> "fa-align-left"
      :radio -> "fa-dot-circle"
      :checkbox -> "fa-check-square"
      :dropdown -> "fa-caret-down"
      :rating -> "fa-star"
      :number -> "fa-hashtag"
      :email -> "fa-envelope"
      :phone -> "fa-phone"
      :date -> "fa-calendar"
      :time -> "fa-clock"
      :region -> "fa-map-marker-alt"
      :matrix -> "fa-table"
      :image_choice -> "fa-images"
      :file_upload -> "fa-file-upload"
      _ -> "fa-question"
    end
  end
  
  # 辅助函数：获取控件类别名称
  def display_category(:basic), do: "基础控件"
  def display_category(:personal), do: "个人信息"
  def display_category(:advanced), do: "高级控件"
  def display_category(_), do: "其他控件"

  @doc """
  渲染表单头部，包括标题和描述
  
  ## 示例
      <.form_header form={@form} />
  """
  def form_header(assigns) do
    ~H"""
    <div class="form-header">
      <h1 class="text-2xl font-bold mb-2"><%= @form.title %></h1>
      <%= if @form.description do %>
        <div class="form-description text-gray-600 mb-6">
          <%= @form.description %>
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  渲染文本输入字段组件
  
  ## 示例
      <.text_input_field
        field={@field}
        form_state={@form_state}
        error={@errors[@field.id]}
        disabled={@disabled}
      />
  """
  def text_input_field(assigns) do
    assigns = assign_new(assigns, :disabled, fn -> false end)
    
    ~H"""
    <div class="form-field form-item mb-4">
      <label for={@field.id} class={"block text-sm font-medium mb-1 #{if @field.required, do: "required", else: ""}"}>
        <%= @field.label %>
        <%= if @field.required do %>
          <span class="form-item-required text-red-500">*</span>
        <% end %>
      </label>
      <input 
        type="text"
        id={@field.id}
        name={@field.id}
        value={Map.get(@form_state, @field.id, "")}
        required={@field.required}
        disabled={@disabled}
        class={"w-full px-3 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500 #{if @error, do: "border-red-500", else: "border-gray-300"}"}
        phx-debounce="blur"
      />
      <%= if @error do %>
        <div class="text-red-500 text-sm mt-1 field-error error-message"><%= @error %></div>
      <% end %>
    </div>
    """
  end

  @doc """
  渲染单选按钮字段组件
  
  ## 示例
      <.radio_field
        field={@field}
        options={@options}
        form_state={@form_state}
        error={@errors[@field.id]}
        disabled={@disabled}
      />
  """
  def radio_field(assigns) do
    assigns = assign_new(assigns, :disabled, fn -> false end)
    
    ~H"""
    <div class="form-field form-item mb-4">
      <fieldset>
        <legend class={"block text-sm font-medium mb-2 #{if @field.required, do: "required", else: ""}"}>
          <%= @field.label %>
          <%= if @field.required do %>
            <span class="form-item-required text-red-500">*</span>
          <% end %>
        </legend>
        <div class="space-y-2">
          <%= for option <- @options do %>
            <div class="flex items-center form-item-option">
              <input 
                type="radio" 
                id={"#{@field.id}_#{option.id}"}
                name={@field.id}
                value={option.value}
                checked={Map.get(@form_state, @field.id) == option.value}
                required={@field.required}
                disabled={@disabled}
                class="h-4 w-4 text-indigo-600 focus:ring-indigo-500" 
                phx-debounce="blur"
              />
              <label for={"#{@field.id}_#{option.id}"} class="ml-2 text-sm text-gray-700">
                <%= option.label %>
              </label>
            </div>
          <% end %>
        </div>
        <%= if @error do %>
          <div class="text-red-500 text-sm mt-1 field-error error-message"><%= @error %></div>
        <% end %>
      </fieldset>
    </div>
    """
  end

  @doc """
  渲染表单构建器组件，用于管理表单项
  
  ## 示例
      <.form_builder
        form={@form}
        items={@items}
        on_add_item={JS.push("add_item")}
        on_edit_item={fn id -> JS.push("edit_item", value: %{id: id}) end}
        on_delete_item={fn id -> JS.push("delete_item", value: %{id: id}) end}
      />
  """
  def form_builder(assigns) do
    ~H"""
    <div class="form-builder">
      <div class="form-items-container space-y-4 mb-6">
        <%= if Enum.empty?(@items) do %>
          <div class="text-center py-8 bg-gray-50 rounded-md">
            <p class="text-gray-500">还没有添加表单项，点击下方按钮添加第一个表单项。</p>
          </div>
        <% else %>
          <%= for {item, index} <- Enum.with_index(@items) do %>
            <div class="form-item-wrapper bg-white p-4 border rounded-md shadow-sm" id={"item-#{item.id}"} data-order={index + 1}>
              <div class="flex justify-between items-center mb-2">
                <div class="font-medium"><%= index + 1 %>. <%= item.label %> (<%= display_item_type(item.type) %>)</div>
                <div class="flex space-x-2">
                  <button type="button" phx-click={@on_edit_item.(item.id)} class="text-indigo-600 hover:text-indigo-800">
                    编辑
                  </button>
                  <button type="button" phx-click={@on_delete_item.(item.id)} class="text-red-600 hover:text-red-800"
                          data-confirm="确定要删除这个表单项吗？">
                    删除
                  </button>
                </div>
              </div>
              <div class="text-sm text-gray-600">
                <%= if item.required, do: "必填项", else: "选填项" %>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>
      
      <div class="form-controls flex justify-center mt-4">
        <button type="button" phx-click={@on_add_item} class="inline-flex items-center px-4 py-2 bg-indigo-600 text-white rounded-md hover:bg-indigo-700">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2" viewBox="0 0 20 20" fill="currentColor">
            <path fill-rule="evenodd" d="M10 5a1 1 0 011 1v3h3a1 1 0 110 2h-3v3a1 1 0 11-2 0v-3H6a1 1 0 110-2h3V6a1 1 0 011-1z" clip-rule="evenodd" />
          </svg>
          添加表单项
        </button>
      </div>
    </div>
    """
  end
  
  @doc """
  表单项编辑组件，用于添加或编辑表单项
  
  ## 示例
      <.form_item_editor
        item={@current_item}
        form_id="item-form"
        on_save="save_item"
        on_cancel="cancel_edit"
        on_add_option="add_option"
        on_remove_option="remove_option"
      />
  """
  def form_item_editor(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow-lg p-6 mb-6" id={@id || "form-item-editor"}>
      <h3 class="text-lg font-medium mb-4" id="item-editor-title">
        <%= if @item.id, do: "编辑表单项", else: "添加新表单项" %>
      </h3>
      
      <form id="form-item-form" phx-submit={@on_save} phx-change="form_change" class="space-y-4">
        <%= if @item.id do %>
          <input type="hidden" name="item[id]" value={@item.id} />
        <% end %>
        
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">类型</label>
            <%= if @item.id != nil do %>
              <div class="text-gray-700 py-2">
                <%= display_item_type(@item.type) %>
              </div>
              <input type="hidden" name="item[type]" value={@item_type || to_string(@item.type)} />
            <% else %>
              <div class="flex space-x-2">
                <button
                  type="button"
                  id="text-input-type-btn"
                  phx-click="type_changed"
                  phx-value-type="text_input"
                  class={"px-3 py-2 border rounded-md #{if @item_type == "text_input" || @item.type == :text_input, do: "bg-indigo-100 border-indigo-500", else: "bg-white border-gray-300"}"}
                >
                  文本输入
                </button>
                <button
                  type="button"
                  id="textarea-type-btn"
                  phx-click="type_changed"
                  phx-value-type="textarea"
                  class={"px-3 py-2 border rounded-md #{if @item_type == "textarea" || @item.type == :textarea, do: "bg-indigo-100 border-indigo-500", else: "bg-white border-gray-300"}"}
                >
                  文本区域
                </button>
                <button
                  type="button"
                  id="radio-type-btn"
                  phx-click="type_changed"
                  phx-value-type="radio"
                  class={"px-3 py-2 border rounded-md #{if @item_type == "radio" || @item.type == :radio, do: "bg-indigo-100 border-indigo-500", else: "bg-white border-gray-300"}"}
                >
                  单选按钮
                </button>
                <button
                  type="button"
                  id="dropdown-type-btn"
                  phx-click="type_changed"
                  phx-value-type="dropdown"
                  class={"px-3 py-2 border rounded-md #{if @item_type == "dropdown" || @item.type == :dropdown, do: "bg-indigo-100 border-indigo-500", else: "bg-white border-gray-300"}"}
                >
                  下拉菜单
                </button>
                <button
                  type="button"
                  id="checkbox-type-btn"
                  phx-click="type_changed"
                  phx-value-type="checkbox"
                  class={"px-3 py-2 border rounded-md #{if @item_type == "checkbox" || @item.type == :checkbox, do: "bg-indigo-100 border-indigo-500", else: "bg-white border-gray-300"}"}
                >
                  复选框
                </button>
                <button
                  type="button"
                  id="rating-type-btn"
                  phx-click="type_changed"
                  phx-value-type="rating"
                  class={"px-3 py-2 border rounded-md #{if @item_type == "rating" || @item.type == :rating, do: "bg-indigo-100 border-indigo-500", else: "bg-white border-gray-300"}"}
                >
                  评分
                </button>
                <button
                  type="button"
                  id="number-type-btn"
                  phx-click="type_changed"
                  phx-value-type="number"
                  class={"px-3 py-2 border rounded-md #{if @item_type == "number" || @item.type == :number, do: "bg-indigo-100 border-indigo-500", else: "bg-white border-gray-300"}"}
                >
                  数字输入
                </button>
                <button
                  type="button"
                  id="email-type-btn"
                  phx-click="type_changed"
                  phx-value-type="email"
                  class={"px-3 py-2 border rounded-md #{if @item_type == "email" || @item.type == :email, do: "bg-indigo-100 border-indigo-500", else: "bg-white border-gray-300"}"}
                >
                  邮箱输入
                </button>
                <button
                  type="button"
                  id="phone-type-btn"
                  phx-click="type_changed"
                  phx-value-type="phone"
                  class={"px-3 py-2 border rounded-md #{if @item_type == "phone" || @item.type == :phone, do: "bg-indigo-100 border-indigo-500", else: "bg-white border-gray-300"}"}
                >
                  电话号码
                </button>
                <input type="hidden" name="item[type]" value={@item_type || to_string(@item.type)} />
              </div>
            <% end %>
          </div>
          
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">标签 <span class="text-red-500">*</span></label>
            <input
              type="text"
              name="item[label]"
              value={@item.label || ""}
              required
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500"
              placeholder="请输入表单项标签"
              id={if @item.id, do: "edit-item-label", else: "new-item-label"}
              phx-value-id={if @item.id, do: "edit-item-label", else: "new-item-label"}
              phx-change="form_change"
            />
          </div>

          <%= if @item_type in ["text_input", "textarea", "number", "email", "phone"] or @item.type in [:text_input, :textarea, :number, :email, :phone] do %>
            <div class="mt-4">
              <label class="block text-sm font-medium text-gray-700 mb-1">占位提示</label>
              <input
                type="text"
                name="item[placeholder]"
                value={@item.placeholder || ""}
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500"
                placeholder="请输入占位提示文字 (可选)"
                id={if @item.id, do: "edit-item-placeholder", else: "new-item-placeholder"}
                phx-value-id={if @item.id, do: "edit-item-placeholder", else: "new-item-placeholder"}
                phx-change="form_change"
              />
            </div>
          <% end %>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">是否必填</label>
            <input
              type="checkbox"
              id={if @item.id, do: "item-required", else: "new-item-required"}
              name="item[required]"
              checked={@item.required}
              phx-change="form_change"
              class="h-4 w-4 text-indigo-600 focus:ring-indigo-500"
            />
            <label for={if @item.id, do: "item-required", else: "new-item-required"} class="ml-2 text-sm text-gray-700">必填项</label>
          </div>
        </div> <%# Closing div of the main grid %>

        <%# Add the placeholder input conditionally AFTER the main grid %>
        <%= if @item_type in ["text_input", "textarea", "number", "email", "phone"] or @item.type in [:text_input, :textarea, :number, :email, :phone] do %>
          <div class="mt-4"> <%# Add some margin top for spacing %>
            <label class="block text-sm font-medium text-gray-700 mb-1">占位提示</label>
            <input
              type="text"
              name="item[placeholder]"
              value={@item.placeholder || ""}
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500"
              placeholder="请输入占位提示文字 (可选)"
              id={if @item.id, do: "edit-item-placeholder", else: "new-item-placeholder"}
              phx-value-id={if @item.id, do: "edit-item-placeholder", else: "new-item-placeholder"}
              phx-change="form_change"
            />
          </div>
        <% end %>

        <%# Options for radio, checkbox, dropdown %>
        <%= if @item_type in ["radio", "checkbox", "dropdown"] or @item.type in [:radio, :checkbox, :dropdown] do %>
          <div class="options-editor mt-4">
            <div class="flex justify-between items-center mb-2">
              <label class="block text-sm font-medium text-gray-700">选项</label>
              <button type="button" id="add-option-btn" phx-click={@on_add_option} class="text-sm text-indigo-600 hover:text-indigo-800">
                + 添加选项
              </button>
            </div>
            
            <div id="options-container" class="space-y-2">
              <%# 注意：已从此处移除 phx-update="append"，建议使用 LiveView.JS 或 streams 来代替 %>
              <%= for {option, index} <- Enum.with_index(@options || []) do %>
                <div class="flex gap-2 items-center option-row" id={"option-#{index}"}>
                  <input
                    type="text"
                    name={"item[options][#{index}][label]"}
                    value={option.label}
                    placeholder="选项文本"
                    required
                    class="flex-1 px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500"
                    id={"option-#{index}-label"}
                    phx-change="form_change"
                  />
                  <input
                    type="text"
                    name={"item[options][#{index}][value]"}
                    value={option.value}
                    placeholder="选项值"
                    required
                    class="flex-1 px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500"
                    id={"option-#{index}-value"}
                    phx-change="form_change"
                  />
                  <button
                    type="button"
                    phx-click={@on_remove_option}
                    phx-value-index={index}
                    class="text-red-500 hover:text-red-700"
                    title="删除选项"
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                      <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM7 9a1 1 0 000 2h6a1 1 0 100-2H7z" clip-rule="evenodd" />
                    </svg>
                  </button>
                </div>
              <% end %>
            </div>
            
            <%= if Enum.empty?(@options || []) do %>
              <div class="text-sm text-gray-500 bg-gray-50 p-3 rounded-md mt-2">
                请添加至少一个选项
              </div>
            <% end %>
          </div>
        <% end %>
        
        <%= if @item.type == :rating || @item_type == "rating" do %>
          <div class="pt-4 border-t border-gray-200">
            <div class="mb-4">
              <label class="block text-sm font-medium text-gray-700 mb-1">最大评分值</label>
              <select
                name="item[max_rating]"
                class="w-40 px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500"
                id="max-rating-select"
              >
                <%= for val <- 3..10 do %>
                  <option value={val} selected={@item.max_rating == val || (@item.max_rating == nil && val == 5)}>
                    <%= val %> 星
                  </option>
                <% end %>
              </select>
            </div>
            
            <div class="rating-preview p-3 bg-gray-50 rounded-md">
              <div class="text-sm text-gray-700 mb-2">预览:</div>
              <div class="flex items-center">
                <%= for i <- 1..5 do %>
                  <span class={"text-2xl #{if i <= 3, do: "text-yellow-500", else: "text-gray-300"}"}>★</span>
                <% end %>
                <span class="ml-2 text-sm text-gray-600">3星</span>
              </div>
            </div>
          </div>
        <% end %>
        
        <%= if @item.type == :number || @item_type == "number" do %>
          <div class="pt-4 border-t border-gray-200">
            <label class="block text-sm font-medium text-gray-700 mb-2">数值范围设置</label>
            <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div>
                <label class="block text-sm text-gray-600 mb-1">最小值</label>
                <input 
                  type="number" 
                  name="item[min]" 
                  value={@item.min} 
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500"
                  placeholder="不限制"
                />
              </div>
              <div>
                <label class="block text-sm text-gray-600 mb-1">最大值</label>
                <input 
                  type="number" 
                  name="item[max]" 
                  value={@item.max} 
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500"
                  placeholder="不限制"
                />
              </div>
              <div>
                <label class="block text-sm text-gray-600 mb-1">步长</label>
                <input 
                  type="number" 
                  name="item[step]" 
                  value={@item.step || 1} 
                  min="0.001"
                  step="0.001"
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500"
                  placeholder="1"
                />
              </div>
            </div>
            <div class="mt-2 text-sm text-gray-500">设置数值输入的范围限制（可选）</div>
          </div>
        <% end %>

        <%= if @item.type == :email || @item_type == "email" do %>
          <div class="pt-4 border-t border-gray-200">
            <div class="flex items-center">
              <input
                type="checkbox"
                id="show-format-hint"
                name="item[show_format_hint]"
                checked={@item.show_format_hint}
                class="h-4 w-4 text-indigo-600 focus:ring-indigo-500"
              />
              <label for="show-format-hint" class="ml-2 text-sm text-gray-700">显示邮箱格式提示</label>
            </div>
          </div>
        <% end %>

        <%= if @item.type == :phone || @item_type == "phone" do %>
          <div class="pt-4 border-t border-gray-200">
            <div class="flex items-center">
              <input
                type="checkbox"
                id="format-display"
                name="item[format_display]"
                checked={@item.format_display}
                class="h-4 w-4 text-indigo-600 focus:ring-indigo-500"
              />
              <label for="format-display" class="ml-2 text-sm text-gray-700">启用格式提示和验证</label>
            </div>
            <div class="mt-2 text-sm text-gray-500">启用后将显示格式提示并验证手机号格式</div>
          </div>
        <% end %>
        
        <%= if @item.type == :date || @item_type == "date" do %>
          <div class="pt-4 border-t border-gray-200">
            <label class="block text-sm font-medium text-gray-700 mb-2">日期范围设置</label>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-sm text-gray-600 mb-1">最早可选日期</label>
                <input 
                  type="date" 
                  name="item[min_date]" 
                  value={@item.min_date} 
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500"
                />
              </div>
              <div>
                <label class="block text-sm text-gray-600 mb-1">最晚可选日期</label>
                <input 
                  type="date" 
                  name="item[max_date]" 
                  value={@item.max_date} 
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500"
                />
              </div>
            </div>
            <div class="mt-4">
              <label class="block text-sm text-gray-600 mb-1">日期格式</label>
              <select
                name="item[date_format]"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500"
              >
                <option value="yyyy-MM-dd" selected={@item.date_format == "yyyy-MM-dd" || is_nil(@item.date_format)}>年-月-日 (yyyy-MM-dd)</option>
                <option value="dd/MM/yyyy" selected={@item.date_format == "dd/MM/yyyy"}>日/月/年 (dd/MM/yyyy)</option>
                <option value="MM/dd/yyyy" selected={@item.date_format == "MM/dd/yyyy"}>月/日/年 (MM/dd/yyyy)</option>
              </select>
            </div>
            <div class="mt-2 text-sm text-gray-500">指定日期范围和显示格式</div>
          </div>
        <% end %>
        
        <%= if @item.type == :time || @item_type == "time" do %>
          <div class="pt-4 border-t border-gray-200">
            <label class="block text-sm font-medium text-gray-700 mb-2">时间范围设置</label>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-sm text-gray-600 mb-1">开始时间</label>
                <input 
                  type="time" 
                  name="item[min_time]" 
                  value={@item.min_time || "09:00"} 
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500"
                />
              </div>
              <div>
                <label class="block text-sm text-gray-600 mb-1">结束时间</label>
                <input 
                  type="time" 
                  name="item[max_time]" 
                  value={@item.max_time || "18:00"} 
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500"
                />
              </div>
            </div>
            <div class="mt-4">
              <label class="block text-sm text-gray-600 mb-1">时间格式</label>
              <select
                name="item[time_format]"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500"
              >
                <option value="24h" selected={@item.time_format == "24h" || is_nil(@item.time_format)}>24小时制 (HH:mm)</option>
                <option value="12h" selected={@item.time_format == "12h"}>12小时制 (hh:mm AM/PM)</option>
              </select>
            </div>
            <div class="mt-2 text-sm text-gray-500">指定可选时间范围和显示格式</div>
          </div>
        <% end %>
        
        <%= if @item.type == :region || @item_type == "region" do %>
          <div class="pt-4 border-t border-gray-200">
            <label class="block text-sm font-medium text-gray-700 mb-2">地区选择设置</label>
            <div>
              <label class="block text-sm text-gray-600 mb-1">地区级别</label>
              <select
                name="item[region_level]"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500"
              >
                <option value="1" selected={@item.region_level == 1}>仅省级</option>
                <option value="2" selected={@item.region_level == 2}>省市两级</option>
                <option value="3" selected={@item.region_level == 3 || is_nil(@item.region_level)}>省市区三级</option>
              </select>
            </div>
            <div class="mt-4">
              <label class="block text-sm text-gray-600 mb-1">默认省份</label>
              <select
                name="item[default_province]"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500"
              >
                <option value="" selected={is_nil(@item.default_province)}>无默认值</option>
                <%= for province <- MyApp.Regions.get_provinces() do %>
                  <option 
                    value={province.name}
                    selected={@item.default_province == province.name}
                  >
                    <%= province.name %>
                  </option>
                <% end %>
              </select>
            </div>
            <div class="mt-2 text-sm text-gray-500">配置地区选择的级别和默认值</div>
            
            <div class="mt-4 p-3 bg-gray-50 rounded-md">
              <div class="text-sm text-gray-700 mb-2">预览:</div>
              <div class="flex gap-2">
                <select 
                  disabled 
                  class="flex-1 px-3 py-2 border border-gray-300 rounded-md bg-white"
                >
                  <option><%= @item.default_province || "请选择省份" %></option>
                </select>
                
                <%= if @item.region_level == nil || @item.region_level >= 2 do %>
                  <select 
                    disabled 
                    class="flex-1 px-3 py-2 border border-gray-300 rounded-md bg-white"
                  >
                    <option>请选择城市</option>
                  </select>
                <% end %>
                
                <%= if @item.region_level == nil || @item.region_level >= 3 do %>
                  <select 
                    disabled 
                    class="flex-1 px-3 py-2 border border-gray-300 rounded-md bg-white"
                  >
                    <option>请选择区县</option>
                  </select>
                <% end %>
              </div>
              <div class="text-xs text-gray-500 mt-2">注意: 表单提交时会加载真实省市区数据</div>
            </div>
          </div>
        <% end %>
        
        <%= if @item.type == :matrix || @item_type == "matrix" do %>
          <div class="pt-4 border-t border-gray-200">
            <label class="block text-sm font-medium text-gray-700 mb-2">矩阵题设置</label>
            
            <!-- 矩阵类型选择 -->
            <div class="mb-4">
              <label class="block text-sm text-gray-600 mb-1">选择类型</label>
              <div class="flex space-x-4">
                <label class="inline-flex items-center">
                  <input 
                    type="radio" 
                    name="item[matrix_type]" 
                    value="single" 
                    checked={@item.matrix_type == :single || @item.matrix_type == nil}
                    class="h-4 w-4 text-indigo-600 focus:ring-indigo-500"
                  />
                  <span class="ml-2 text-sm text-gray-700">单选 (每行只能选择一个)</span>
                </label>
                <label class="inline-flex items-center">
                  <input 
                    type="radio" 
                    name="item[matrix_type]" 
                    value="multiple" 
                    checked={@item.matrix_type == :multiple}
                    class="h-4 w-4 text-indigo-600 focus:ring-indigo-500"
                  />
                  <span class="ml-2 text-sm text-gray-700">多选 (每行可选择多个)</span>
                </label>
              </div>
            </div>
            
            <!-- 矩阵行设置 -->
            <div class="mb-4">
              <div class="flex justify-between items-center mb-2">
                <label class="block text-sm font-medium text-gray-700">行标题 (问题)</label>
                <button type="button" phx-click="add_matrix_row" class="text-sm text-indigo-600 hover:text-indigo-800">
                  + 添加行
                </button>
              </div>
              
              <div class="space-y-2">
                <%= for {row, index} <- Enum.with_index(@item.matrix_rows || ["问题1", "问题2", "问题3"]) do %>
                  <div class="flex items-center gap-2">
                    <input 
                      type="text" 
                      name={"item[matrix_rows][#{index}]"} 
                      value={row}
                      placeholder="行标题"
                      class="flex-1 px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500"
                    />
                    <button 
                      type="button" 
                      phx-click="remove_matrix_row" 
                      phx-value-index={index}
                      class="text-red-500 hover:text-red-700"
                      title="删除行"
                      disabled={length(@item.matrix_rows || ["问题1", "问题2", "问题3"]) <= 1}
                    >
                      <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM7 9a1 1 0 000 2h6a1 1 0 100-2H7z" clip-rule="evenodd" />
                      </svg>
                    </button>
                  </div>
                <% end %>
              </div>
            </div>
            
            <!-- 矩阵列设置 -->
            <div class="mb-4">
              <div class="flex justify-between items-center mb-2">
                <label class="block text-sm font-medium text-gray-700">列标题 (选项)</label>
                <button type="button" phx-click="add_matrix_column" class="text-sm text-indigo-600 hover:text-indigo-800">
                  + 添加列
                </button>
              </div>
              
              <div class="space-y-2">
                <%= for {column, index} <- Enum.with_index(@item.matrix_columns || ["选项A", "选项B", "选项C"]) do %>
                  <div class="flex items-center gap-2">
                    <input 
                      type="text" 
                      name={"item[matrix_columns][#{index}]"} 
                      value={column}
                      placeholder="列标题"
                      class="flex-1 px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500"
                    />
                    <button 
                      type="button" 
                      phx-click="remove_matrix_column" 
                      phx-value-index={index}
                      class="text-red-500 hover:text-red-700"
                      title="删除列"
                      disabled={length(@item.matrix_columns || ["选项A", "选项B", "选项C"]) <= 1}
                    >
                      <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM7 9a1 1 0 000 2h6a1 1 0 100-2H7z" clip-rule="evenodd" />
                      </svg>
                    </button>
                  </div>
                <% end %>
              </div>
            </div>
            
            <!-- 矩阵预览 -->
            <div class="mt-4 p-3 bg-gray-50 rounded-md">
              <div class="text-sm text-gray-700 mb-2">预览:</div>
              <div class="overflow-x-auto">
                <table class="w-full border-collapse rounded-lg overflow-hidden">
                  <thead>
                    <tr>
                      <th class="p-2 border border-gray-300 bg-gray-100"></th>
                      <%= for column <- (@item.matrix_columns || ["选项A", "选项B", "选项C"]) do %>
                        <th class="p-2 border border-gray-300 bg-gray-100 text-center">
                          <%= column %>
                        </th>
                      <% end %>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for row <- (@item.matrix_rows || ["问题1", "问题2", "问题3"]) do %>
                      <tr>
                        <td class="p-2 border border-gray-300 font-medium bg-gray-50"><%= row %></td>
                        <%= for _column <- (@item.matrix_columns || ["选项A", "选项B", "选项C"]) do %>
                          <td class="p-2 border border-gray-300 text-center">
                            <%= if @item.matrix_type == :multiple do %>
                              <input type="checkbox" disabled class="h-4 w-4 text-indigo-600" />
                            <% else %>
                              <input type="radio" disabled class="h-4 w-4 text-indigo-600" />
                            <% end %>
                          </td>
                        <% end %>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
              <div class="text-xs text-gray-500 mt-2">
                矩阵类型: <%= if @item.matrix_type == :multiple, do: "多选 (复选框)", else: "单选 (单选按钮)" %>
              </div>
            </div>
          </div>
        <% end %>
        
        <%= if @item.type == :image_choice || @item_type == "image_choice" do %>
          <div class="pt-4 border-t border-gray-200">
            <label class="block text-sm font-medium text-gray-700 mb-2">图片选择设置</label>
            
            <!-- 选择类型设置 -->
            <div class="mb-4">
              <label class="block text-sm text-gray-600 mb-1">选择类型</label>
              <div class="flex space-x-4">
                <label class="inline-flex items-center">
                  <input 
                    type="radio" 
                    name="item[selection_type]" 
                    value="single" 
                    checked={@item.selection_type == :single || @item.selection_type == nil}
                    class="h-4 w-4 text-indigo-600 focus:ring-indigo-500"
                  />
                  <span class="ml-2 text-sm text-gray-700">单选 (只能选择一张图片)</span>
                </label>
                <label class="inline-flex items-center">
                  <input 
                    type="radio" 
                    name="item[selection_type]" 
                    value="multiple" 
                    checked={@item.selection_type == :multiple}
                    class="h-4 w-4 text-indigo-600 focus:ring-indigo-500"
                  />
                  <span class="ml-2 text-sm text-gray-700">多选 (可以选择多张图片)</span>
                </label>
              </div>
            </div>
            
            <!-- 图片标题位置设置 -->
            <div class="mb-4">
              <label class="block text-sm text-gray-600 mb-1">图片标题位置</label>
              <div class="flex space-x-4">
                <label class="inline-flex items-center">
                  <input 
                    type="radio" 
                    name="item[image_caption_position]" 
                    value="top" 
                    checked={@item.image_caption_position == :top}
                    class="h-4 w-4 text-indigo-600 focus:ring-indigo-500"
                  />
                  <span class="ml-2 text-sm text-gray-700">图片上方</span>
                </label>
                <label class="inline-flex items-center">
                  <input 
                    type="radio" 
                    name="item[image_caption_position]" 
                    value="bottom" 
                    checked={@item.image_caption_position == :bottom || @item.image_caption_position == nil}
                    class="h-4 w-4 text-indigo-600 focus:ring-indigo-500"
                  />
                  <span class="ml-2 text-sm text-gray-700">图片下方</span>
                </label>
                <label class="inline-flex items-center">
                  <input 
                    type="radio" 
                    name="item[image_caption_position]" 
                    value="none" 
                    checked={@item.image_caption_position == :none}
                    class="h-4 w-4 text-indigo-600 focus:ring-indigo-500"
                  />
                  <span class="ml-2 text-sm text-gray-700">不显示标题</span>
                </label>
              </div>
            </div>
            
            <!-- 图片选择预览 -->
            <div class="mt-4 p-3 bg-gray-50 rounded-md">
              <div class="text-sm text-gray-700 mb-2">预览:</div>
              <div class="flex flex-wrap gap-4">
                <div class="w-40 border border-gray-300 rounded-md overflow-hidden">
                  <%= if @item.image_caption_position == :top do %>
                    <div class="p-2 text-center bg-white text-sm">示例图片标题</div>
                  <% end %>
                  <div class="h-32 bg-gray-100 flex items-center justify-center">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-10 w-10 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                    </svg>
                  </div>
                  <%= if @item.image_caption_position == :bottom || @item.image_caption_position == nil do %>
                    <div class="p-2 text-center bg-white text-sm">示例图片标题</div>
                  <% end %>
                  <div class="p-1 border-t border-gray-300 bg-white text-center">
                    <input 
                      type={if @item.selection_type == :multiple, do: "checkbox", else: "radio"} 
                      disabled 
                      class="h-4 w-4 text-indigo-600"
                    />
                  </div>
                </div>
                
                <div class="w-40 border border-gray-300 rounded-md overflow-hidden">
                  <%= if @item.image_caption_position == :top do %>
                    <div class="p-2 text-center bg-white text-sm">示例图片标题</div>
                  <% end %>
                  <div class="h-32 bg-gray-100 flex items-center justify-center">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-10 w-10 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                    </svg>
                  </div>
                  <%= if @item.image_caption_position == :bottom || @item.image_caption_position == nil do %>
                    <div class="p-2 text-center bg-white text-sm">示例图片标题</div>
                  <% end %>
                  <div class="p-1 border-t border-gray-300 bg-white text-center">
                    <input 
                      type={if @item.selection_type == :multiple, do: "checkbox", else: "radio"} 
                      disabled 
                      class="h-4 w-4 text-indigo-600"
                    />
                  </div>
                </div>
              </div>
              <div class="text-xs text-gray-500 mt-2">
                选择类型: <%= if @item.selection_type == :multiple, do: "多选", else: "单选" %>, 
                标题位置: <%= case @item.image_caption_position do %>
                  <% :top -> %>图片上方
                  <% :bottom -> %>图片下方
                  <% :none -> %>不显示标题
                  <% _ -> %>图片下方
                <% end %>
              </div>
              <div class="text-xs text-gray-500 mt-2">
                注意: 实际图片上传功能将在表单提交页面实现
              </div>
            </div>
          </div>
        <% end %>
        
        <%= if @item.type == :file_upload || @item_type == "file_upload" do %>
          <div class="pt-4 border-t border-gray-200">
            <label class="block text-sm font-medium text-gray-700 mb-2">文件上传设置</label>
            
            <!-- 文件扩展名设置 -->
            <div class="mb-4">
              <label class="block text-sm text-gray-600 mb-1">允许的文件类型 (多个类型用逗号分隔)</label>
              <input 
                type="text" 
                name="item[allowed_extensions]" 
                value={if is_list(@item.allowed_extensions), do: Enum.join(@item.allowed_extensions, ", "), else: ""}
                placeholder=".pdf, .doc, .docx, .jpg, .png"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500"
              />
              <div class="text-xs text-gray-500 mt-1">
                例如: .pdf, .doc, .docx, .jpg, .png (必须以点号开头)
              </div>
            </div>
            
            <!-- 文件大小限制设置 -->
            <div class="mb-4">
              <label class="block text-sm text-gray-600 mb-1">最大文件大小 (MB)</label>
              <input 
                type="number" 
                name="item[max_file_size]" 
                value={@item.max_file_size || 5}
                min="0.1"
                max="20"
                step="0.1"
                class="w-40 px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500"
              />
              <div class="text-xs text-gray-500 mt-1">
                每个文件的最大大小限制 (最大20MB)
              </div>
            </div>
            
            <!-- 多文件上传设置 -->
            <div class="mb-4">
              <div class="flex items-center">
                <input
                  type="checkbox"
                  id="multiple-files"
                  name="item[multiple_files]"
                  checked={@item.multiple_files}
                  class="h-4 w-4 text-indigo-600 focus:ring-indigo-500"
                />
                <label for="multiple-files" class="ml-2 text-sm text-gray-700">允许上传多个文件</label>
              </div>
              
              <%= if @item.multiple_files do %>
                <div class="mt-3 ml-6">
                  <label class="block text-sm text-gray-600 mb-1">最大文件数量</label>
                  <input 
                    type="number" 
                    name="item[max_files]" 
                    value={@item.max_files || 3}
                    min="1"
                    max="10"
                    class="w-20 px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500"
                  />
                  <div class="text-xs text-gray-500 mt-1">
                    允许上传的最大文件数量 (最多10个)
                  </div>
                </div>
              <% end %>
            </div>
            
            <!-- 文件上传预览 -->
            <div class="mt-4 p-3 bg-gray-50 rounded-md">
              <div class="text-sm text-gray-700 mb-2">预览:</div>
              <div class="border-2 border-dashed border-gray-300 rounded-md p-6 text-center">
                <svg xmlns="http://www.w3.org/2000/svg" class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
                </svg>
                <div class="mt-2 text-sm text-gray-600">
                  点击或拖拽文件到此区域上传
                </div>
                <div class="mt-1 text-xs text-gray-500">
                  <%= if @item.allowed_extensions && @item.allowed_extensions != [] do %>
                    支持格式: <%= if is_list(@item.allowed_extensions), do: Enum.join(@item.allowed_extensions, ", "), else: @item.allowed_extensions %>
                  <% else %>
                    支持所有文件格式
                  <% end %>
                </div>
                <div class="mt-1 text-xs text-gray-500">
                  最大文件大小: <%= @item.max_file_size || 5 %> MB
                  <%= if @item.multiple_files do %>
                    , 最多 <%= @item.max_files || 3 %> 个文件
                  <% end %>
                </div>
                <button type="button" class="mt-3 inline-flex items-center px-3 py-1.5 border border-transparent text-xs rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500" disabled>
                  选择文件
                </button>
              </div>
              <div class="text-xs text-gray-500 mt-2">
                注意: 实际文件上传功能将在表单提交页面实现
              </div>
            </div>
          </div>
        <% end %>
        
        <div class="flex justify-end space-x-3 pt-4 border-t border-gray-200">
          <button
            type="button"
            phx-click={@on_cancel}
            class="px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50"
          >
            取消
          </button>
          <button
            type="submit"
            id="submit-form-item-btn"
            class="px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 submit-form-item-btn"
          >
            <%= if @item.id, do: "保存修改", else: "添加问题" %>
          </button>
        </div>
      </form>
    </div>
    """
  end

  # 辅助函数，将表单项类型转换为显示文本
  defp display_item_type(:text_input), do: "文本输入框"
  defp display_item_type(:radio), do: "单选按钮"
  defp display_item_type(:textarea), do: "文本区域"
  defp display_item_type(:dropdown), do: "下拉菜单"
  defp display_item_type(:checkbox), do: "复选框"
  defp display_item_type(:rating), do: "评分"
  defp display_item_type(:number), do: "数字输入"
  defp display_item_type(:email), do: "邮箱输入"
  defp display_item_type(:phone), do: "电话号码"
  defp display_item_type(:date), do: "日期选择"
  defp display_item_type(:time), do: "时间选择" 
  defp display_item_type(:region), do: "地区选择"
  defp display_item_type(:matrix), do: "矩阵题"
  defp display_item_type(:image_choice), do: "图片选择"
  defp display_item_type(:file_upload), do: "文件上传"
  defp display_item_type(_), do: "未知类型"
  
  @doc """
  渲染矩阵题字段组件
  
  ## 示例
      <.matrix_field
        field={@field}
        form_state={@form_state}
        error={@errors[@field.id]}
        disabled={@disabled}
      />
  """
  def matrix_field(assigns) do
    assigns = assign_new(assigns, :disabled, fn -> false end)
    
    ~H"""
    <div class="form-field form-item mb-6">
      <label class={"block text-sm font-medium mb-2 #{if @field.required, do: "required", else: ""}"}>
        <%= @field.label %>
        <%= if @field.required do %>
          <span class="form-item-required text-red-500">*</span>
        <% end %>
      </label>
      
      <%= if @field.description do %>
        <div class="text-sm text-gray-500 mb-2"><%= @field.description %></div>
      <% end %>
      
      <div class="overflow-x-auto">
        <table class="w-full border-collapse rounded-lg overflow-hidden">
          <thead>
            <tr>
              <th class="p-2 border border-gray-300 bg-gray-50"></th>
              <%= for column <- (@field.matrix_columns || []) do %>
                <th class="p-2 border border-gray-300 bg-gray-50 text-center">
                  <%= column %>
                </th>
              <% end %>
            </tr>
          </thead>
          <tbody>
            <%= for {row, row_idx} <- Enum.with_index(@field.matrix_rows || []) do %>
              <tr>
                <td class="p-2 border border-gray-300 font-medium bg-gray-50"><%= row %></td>
                <%= for {_column, col_idx} <- Enum.with_index(@field.matrix_columns || []) do %>
                  <td class="p-2 border border-gray-300 text-center">
                    <%= if @field.matrix_type == :multiple do %>
                      <input 
                        type="checkbox" 
                        id={"#{@field.id}_#{row_idx}_#{col_idx}"}
                        name={"#{@field.id}[#{row_idx}][#{col_idx}]"}
                        value="true"
                        checked={get_matrix_value(@form_state, @field.id, row_idx, col_idx)}
                        phx-change="matrix_change"
                        phx-value-field-id={@field.id}
                        phx-value-row-idx={row_idx}
                        phx-value-col-idx={col_idx}
                        class="h-4 w-4 text-indigo-600 focus:ring-indigo-500" 
                        disabled={@disabled}
                      />
                    <% else %>
                      <input 
                        type="radio" 
                        id={"#{@field.id}_#{row_idx}_#{col_idx}"}
                        name={"#{@field.id}[#{row_idx}]"}
                        value={col_idx}
                        checked={get_matrix_value(@form_state, @field.id, row_idx) == col_idx}
                        phx-change="matrix_change"
                        phx-value-field-id={@field.id}
                        phx-value-row-idx={row_idx}
                        phx-value-col-idx={col_idx}
                        required={@field.required}
                        class="h-4 w-4 text-indigo-600 focus:ring-indigo-500" 
                        disabled={@disabled}
                      />
                    <% end %>
                  </td>
                <% end %>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
      
      <!-- 隐藏的输入字段，用于存储矩阵值 -->
      <% matrix_value = Map.get(@form_state || %{}, @field.id) || %{} %>
      <% json_value = Phoenix.HTML.html_escape(Jason.encode!(matrix_value)) %>
      <input type="hidden" id={@field.id} name={@field.id} value={json_value} />
      
      <%= if @error do %>
        <div class="text-red-500 text-sm mt-1 field-error error-message"><%= @error %></div>
      <% end %>
    </div>
    """
  end
  
  # 辅助函数：获取矩阵单选题的值
  defp get_matrix_value(form_state, field_id, row_idx) do
    case form_state do
      %{^field_id => matrix_data} when is_map(matrix_data) ->
        Map.get(matrix_data, to_string(row_idx))
      _ -> nil
    end
  end
  
  # 辅助函数：获取矩阵多选题的值
  defp get_matrix_value(form_state, field_id, row_idx, col_idx) do
    case form_state do
      %{^field_id => matrix_data} when is_map(matrix_data) ->
        row_data = Map.get(matrix_data, to_string(row_idx), %{})
        Map.get(row_data, to_string(col_idx), false)
      _ -> false
    end
  end
  
  @doc """
  渲染图片选择字段组件
  
  ## 示例
      <.image_choice_field
        field={@field}
        form_state={@form_state}
        error={@errors[@field.id]}
        disabled={@disabled}
        options={@options}
      />
  """
  def image_choice_field(assigns) do
    assigns = assign_new(assigns, :disabled, fn -> false end)
    assigns = assign_new(assigns, :options, fn -> [] end)
    
    ~H"""
    <div class="form-field form-item mb-6">
      <fieldset>
        <legend class={"block text-sm font-medium mb-2 #{if @field.required, do: "required", else: ""}"}>
          <%= @field.label %>
          <%= if @field.required do %>
            <span class="form-item-required text-red-500">*</span>
          <% end %>
        </legend>
        
        <%= if @field.description do %>
          <div class="text-sm text-gray-500 mb-2"><%= @field.description %></div>
        <% end %>
        
        <div class="flex flex-wrap gap-4">
          <%= for {option, index} <- Enum.with_index(@options) do %>
            <div class="w-40 border border-gray-300 rounded-md overflow-hidden">
              <%= if @field.image_caption_position == :top do %>
                <div class="p-2 text-center bg-white text-sm"><%= option.label %></div>
              <% end %>
              
              <div class="h-32 bg-gray-100 flex items-center justify-center">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-10 w-10 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                </svg>
              </div>
              
              <%= if @field.image_caption_position == :bottom || @field.image_caption_position == nil do %>
                <div class="p-2 text-center bg-white text-sm"><%= option.label %></div>
              <% end %>
              
              <div class="p-1 border-t border-gray-300 bg-white text-center">
                <%= if @field.selection_type == :multiple do %>
                  <input 
                    type="checkbox"
                    id={"#{@field.id}_#{index}"}
                    name={"#{@field.id}[]"}
                    value={option.value}
                    checked={is_list(Map.get(@form_state, @field.id)) && option.value in Map.get(@form_state, @field.id, [])}
                    disabled={@disabled}
                    class="h-4 w-4 text-indigo-600 focus:ring-indigo-500"
                    phx-debounce="blur"
                  />
                <% else %>
                  <input 
                    type="radio"
                    id={"#{@field.id}_#{index}"}
                    name={@field.id}
                    value={option.value}
                    checked={Map.get(@form_state, @field.id) == option.value}
                    required={@field.required}
                    disabled={@disabled}
                    class="h-4 w-4 text-indigo-600 focus:ring-indigo-500"
                    phx-debounce="blur"
                  />
                <% end %>
              </div>
            </div>
          <% end %>
          
          <%= if Enum.empty?(@options) do %>
            <div class="w-full p-4 bg-gray-50 rounded-md text-center text-gray-500">
              暂无图片选项，请在编辑模式下添加图片选项
            </div>
          <% end %>
        </div>
        
        <%= if @error do %>
          <div class="text-red-500 text-sm mt-1 field-error error-message"><%= @error %></div>
        <% end %>
      </fieldset>
    </div>
    """
  end
  
  @doc """
  渲染文件上传字段组件

  ## 示例
      <.file_upload_field
        field={@field}
        form_state={@form_state}
        error={@errors[@field.id]}
        disabled={@disabled}
        uploads={@uploads}
      />
  """
  def file_upload_field(assigns) do
    assigns = assign_new(assigns, :disabled, fn -> false end)
    assigns = assign_new(assigns, :form_id, fn -> nil end)
    
    ~H"""
    <div class="form-field form-item mb-6 file-upload-container">
      <label for={@field.id} class={"block text-sm font-medium mb-2 #{if @field.required, do: "required", else: ""}"}>
        <%= @field.label %>
        <%= if @field.required do %>
          <span class="form-item-required text-red-500">*</span>
        <% end %>
      </label>
      
      <%= if @field.description do %>
        <div class="text-sm text-gray-500 mb-3"><%= @field.description %></div>
      <% end %>
      
      <div class="file-upload-dropzone" id={"dropzone-#{@field.id}"} phx-hook="FileUploadDropzone">
        <svg xmlns="http://www.w3.org/2000/svg" class="file-upload-icon" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
        </svg>
        
        <h3 class="file-upload-text">点击上传或拖放文件</h3>
        
        <p class="file-upload-hint">
          <%= if @field.allowed_extensions && length(@field.allowed_extensions) > 0 do %>
            <span class="font-medium">允许的文件类型:</span> <%= Enum.join(@field.allowed_extensions, ", ") %>
          <% else %>
            允许上传任何类型的文件
          <% end %>
        </p>
        
        <p class="file-upload-hint">
          <%= if @field.multiple_files do %>
            <span class="font-medium">最多可上传:</span> <%= @field.max_files || 5 %> 个文件
          <% else %>
            只能上传单个文件
          <% end %>
          
          <%= if @field.max_file_size do %>
            <span class="file-size-badge">每个文件最大 <%= @field.max_file_size %>MB</span>
          <% end %>
        </p>
          
        <div class="flex justify-center mt-4">
          <a 
            href={"/test-upload/#{@form_id}/#{@field.id}?return_to=#{URI.encode("/forms/#{@form_id}/submit")}"} 
            class="file-upload-button"
            id={"upload-button-#{@field.id}"}
          >
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M3 17a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zM6.293 6.707a1 1 0 010-1.414l3-3a1 1 0 011.414 0l3 3a1 1 0 01-1.414 1.414L11 5.414V13a1 1 0 11-2 0V5.414L7.707 6.707a1 1 0 01-1.414 0z" clip-rule="evenodd" />
            </svg>
            <%= if @form_state && @form_state[@field.id] && length(@form_state[@field.id]) > 0 do %>
              管理已上传文件
            <% else %>
              选择并上传文件
            <% end %>
          </a>
        </div>
        
        <%= if @form_state && @form_state[@field.id] && length(@form_state[@field.id]) > 0 do %>
          <div class="file-list-container">
            <h4 class="file-list-header">
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M3 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm0 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm0 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm0 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1z" clip-rule="evenodd" />
              </svg>
              已上传的文件
            </h4>
            <ul class="file-list">
              <%= for {file, index} <- Enum.with_index(@form_state[@field.id]) do %>
                <li class="file-item">
                  <svg xmlns="http://www.w3.org/2000/svg" class="file-item-icon" viewBox="0 0 20 20" fill="currentColor">
                    <path fill-rule="evenodd" d="M4 4a2 2 0 012-2h4.586A2 2 0 0112 2.586L15.414 6A2 2 0 0116 7.414V16a2 2 0 01-2 2H6a2 2 0 01-2-2V4z" clip-rule="evenodd" />
                  </svg>
                  <span class="file-item-name">
                    <%= file.original_filename %>
                  </span>
                  <span class="file-item-size">
                    <%= MyAppWeb.Helpers.format_file_size(file.size) %>
                  </span>
                  <div class="file-item-actions">
                    <a href={file.path} target="_blank" class="file-action-button">
                      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                        <path d="M10 12a2 2 0 100-4 2 2 0 000 4z" />
                        <path fill-rule="evenodd" d="M.458 10C1.732 5.943 5.522 3 10 3s8.268 2.943 9.542 7c-1.274 4.057-5.064 7-9.542 7S1.732 14.057.458 10zM14 10a4 4 0 11-8 0 4 4 0 018 0z" clip-rule="evenodd" />
                      </svg>
                      查看
                    </a>
                  </div>
                </li>
              <% end %>
            </ul>
          </div>
        <% end %>
      </div>
      
      <%= if @error do %>
        <div class="file-upload-error">
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
            <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
          </svg>
          <%= @error %>
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  渲染文本区域字段组件
  
  ## 示例
      <.textarea_field
        field={@field}
        form_state={@form_state}
        error={@errors[@field.id]}
        disabled={@disabled}
      />
  """
  def textarea_field(assigns) do
    assigns = assign_new(assigns, :disabled, fn -> false end)
    assigns = assign_new(assigns, :rows, fn -> 4 end)
    
    ~H"""
    <div class="form-field form-item mb-4">
      <label for={@field.id} class={"block text-sm font-medium mb-1 #{if @field.required, do: "required", else: ""}"}>
        <%= @field.label %>
        <%= if @field.required do %>
          <span class="form-item-required text-red-500">*</span>
        <% end %>
      </label>
      <textarea 
        id={@field.id}
        name={@field.id}
        rows={@rows}
        required={@field.required}
        disabled={@disabled}
        class={"w-full px-3 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500 #{if @error, do: "border-red-500", else: "border-gray-300"}"}
        phx-debounce="blur"
      ><%= Map.get(@form_state, @field.id, "") %></textarea>
      <%= if @error do %>
        <div class="text-red-500 text-sm mt-1 field-error error-message"><%= @error %></div>
      <% end %>
    </div>
    """
  end

  @doc """
  渲染下拉菜单字段组件
  
  ## 示例
      <.dropdown_field
        field={@field}
        options={@options}
        form_state={@form_state}
        error={@errors[@field.id]}
        disabled={@disabled}
      />
  """
  def dropdown_field(assigns) do
    assigns = assign_new(assigns, :disabled, fn -> false end)
    
    ~H"""
    <div class="form-field form-item mb-4">
      <label for={@field.id} class={"block text-sm font-medium mb-1 #{if @field.required, do: "required", else: ""}"}>
        <%= @field.label %>
        <%= if @field.required do %>
          <span class="form-item-required text-red-500">*</span>
        <% end %>
      </label>
      <select 
        id={@field.id}
        name={@field.id}
        required={@field.required}
        disabled={@disabled}
        class={"w-full px-3 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500 #{if @error, do: "border-red-500", else: "border-gray-300"}"}
        phx-debounce="blur"
      >
        <option value="" disabled selected={!Map.get(@form_state, @field.id, "")}>请选择...</option>
        <%= for option <- @options do %>
          <option value={option.value} selected={Map.get(@form_state, @field.id) == option.value}>
            <%= option.label %>
          </option>
        <% end %>
      </select>
      <%= if @error do %>
        <div class="text-red-500 text-sm mt-1 field-error error-message"><%= @error %></div>
      <% end %>
    </div>
    """
  end

  @doc """
  渲染复选框字段组件
  
  ## 示例
      <.checkbox_field
        field={@field}
        options={@options}
        form_state={@form_state}
        error={@errors[@field.id]}
        disabled={@disabled}
      />
  """
  def checkbox_field(assigns) do
    assigns = assign_new(assigns, :disabled, fn -> false end)
    
    ~H"""
    <div class="form-field form-item mb-4">
      <fieldset>
        <legend class={"block text-sm font-medium mb-2 #{if @field.required, do: "required", else: ""}"}>
          <%= @field.label %>
          <%= if @field.required do %>
            <span class="form-item-required text-red-500">*</span>
          <% end %>
        </legend>
        <div class="space-y-2">
          <%= for option <- @options do %>
            <div class="flex items-center form-item-option">
              <input 
                type="checkbox" 
                id={"#{@field.id}_#{option.id}"}
                name={"#{@field.id}[]"}
                value={option.value}
                checked={is_list(Map.get(@form_state, @field.id)) && option.value in Map.get(@form_state, @field.id, [])}
                disabled={@disabled}
                class="h-4 w-4 text-indigo-600 focus:ring-indigo-500" 
                phx-debounce="blur"
              />
              <label for={"#{@field.id}_#{option.id}"} class="ml-2 text-sm text-gray-700">
                <%= option.label %>
              </label>
            </div>
          <% end %>
        </div>
        <%= if @error do %>
          <div class="text-red-500 text-sm mt-1 field-error error-message"><%= @error %></div>
        <% end %>
      </fieldset>
    </div>
    """
  end
  
  @doc """
  渲染评分控件组件
  
  ## 示例
      <.rating_field
        field={@field}
        form_state={@form_state}
        error={@errors[@field.id]}
        disabled={@disabled}
        max_rating={5}
      />
  """
  def rating_field(assigns) do
    assigns = assign_new(assigns, :disabled, fn -> false end)
    assigns = assign_new(assigns, :max_rating, fn -> 5 end)
    
    ~H"""
    <div class="form-field form-item mb-4">
      <label for={@field.id} class={"block text-sm font-medium mb-1 #{if @field.required, do: "required", else: ""}"}>
        <%= @field.label %>
        <%= if @field.required do %>
          <span class="form-item-required text-red-500">*</span>
        <% end %>
      </label>
      <div class="rating-container py-2">
        <div class="flex items-center" id={"rating-stars-#{@field.id}"}>
          <%= for i <- 1..@max_rating do %>
            <button
              type="button"
              id={"rating-star-#{@field.id}-#{i}"}
              data-value={i}
              data-field-id={@field.id}
              class={"rating-star mx-1 text-2xl cursor-pointer hover:text-yellow-500 focus:outline-none transition-colors #{if Map.get(@form_state, @field.id) != nil && i <= String.to_integer(Map.get(@form_state, @field.id, "0")), do: "text-yellow-500", else: "text-gray-300"}"}
              phx-click="set_rating"
              phx-value-field-id={@field.id}
              phx-value-rating={i}
              disabled={@disabled}
            >
              ★
            </button>
          <% end %>
          <input 
            type="hidden" 
            id={@field.id}
            name={@field.id}
            value={Map.get(@form_state, @field.id, "")}
            required={@field.required}
          />
          <span class="ml-3 text-gray-600 rating-display" id={"rating-display-#{@field.id}"}>
            <%= if rating = Map.get(@form_state, @field.id), do: rating <> "星", else: "请评分" %>
          </span>
        </div>
      </div>
      <%= if @error do %>
        <div class="text-red-500 text-sm mt-1 field-error error-message"><%= @error %></div>
      <% end %>
    </div>
    """
  end

  @doc """
  渲染数字输入字段组件
  
  ## 示例
      <.number_field
        field={@field}
        form_state={@form_state}
        error={@errors[@field.id]}
        disabled={@disabled}
      />
  """
  def number_field(assigns) do
    assigns = assign_new(assigns, :disabled, fn -> false end)
    
    ~H"""
    <div class="form-field form-item mb-4">
      <label for={@field.id} class={"block text-sm font-medium mb-1 #{if @field.required, do: "required", else: ""}"}>
        <%= @field.label %>
        <%= if @field.required do %>
          <span class="form-item-required text-red-500">*</span>
        <% end %>
      </label>
      <input 
        type="number"
        id={@field.id}
        name={@field.id}
        value={Map.get(@form_state, @field.id, "")}
        required={@field.required}
        min={Map.get(@field, :min)}
        max={Map.get(@field, :max)}
        step={Map.get(@field, :step, 1)}
        disabled={@disabled}
        class={"w-full px-3 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500 #{if @error, do: "border-red-500", else: "border-gray-300"}"}
        phx-debounce="blur"
      />
      <%= if @error do %>
        <div class="text-red-500 text-sm mt-1 field-error error-message"><%= @error %></div>
      <% end %>
      <%= if Map.get(@field, :min) && Map.get(@field, :max) do %>
        <div class="text-gray-500 text-xs mt-1">有效范围: <%= @field.min %> - <%= @field.max %></div>
      <% end %>
    </div>
    """
  end

  @doc """
  渲染邮箱输入字段组件
  
  ## 示例
      <.email_field
        field={@field}
        form_state={@form_state}
        error={@errors[@field.id]}
        disabled={@disabled}
      />
  """
  def email_field(assigns) do
    assigns = assign_new(assigns, :disabled, fn -> false end)
    
    ~H"""
    <div class="form-field form-item mb-4">
      <label for={@field.id} class={"block text-sm font-medium mb-1 #{if @field.required, do: "required", else: ""}"}>
        <%= @field.label %>
        <%= if @field.required do %>
          <span class="form-item-required text-red-500">*</span>
        <% end %>
      </label>
      <input 
        type="email"
        id={@field.id}
        name={@field.id}
        value={Map.get(@form_state, @field.id, "")}
        required={@field.required}
        disabled={@disabled}
        class={"w-full px-3 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500 #{if @error, do: "border-red-500", else: "border-gray-300"}"}
        phx-debounce="blur"
      />
      <%= if @error do %>
        <div class="text-red-500 text-sm mt-1 field-error error-message"><%= @error %></div>
      <% end %>
      <%= if Map.get(@field, :show_format_hint, false) do %>
        <div class="text-gray-500 text-xs mt-1">示例格式: example@domain.com</div>
      <% end %>
    </div>
    """
  end

  @doc """
  渲染电话号码输入字段组件
  
  ## 示例
      <.phone_field
        field={@field}
        form_state={@form_state}
        error={@errors[@field.id]}
        disabled={@disabled}
      />
  """
  def phone_field(assigns) do
    assigns = assign_new(assigns, :disabled, fn -> false end)
    
    ~H"""
    <div class="form-field form-item mb-4">
      <label for={@field.id} class={"block text-sm font-medium mb-1 #{if @field.required, do: "required", else: ""}"}>
        <%= @field.label %>
        <%= if @field.required do %>
          <span class="form-item-required text-red-500">*</span>
        <% end %>
      </label>
      <input 
        type="tel"
        id={@field.id}
        name={@field.id}
        value={Map.get(@form_state, @field.id, "")}
        required={@field.required}
        disabled={@disabled}
        pattern={if Map.get(@field, :format_display, false), do: "[0-9]{11}", else: nil}
        placeholder={if Map.get(@field, :format_display, false), do: "13800138000", else: nil}
        class={"w-full px-3 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500 #{if @error, do: "border-red-500", else: "border-gray-300"}"}
        phx-debounce="blur"
      />
      <%= if @error do %>
        <div class="text-red-500 text-sm mt-1 field-error error-message"><%= @error %></div>
      <% end %>
      <%= if Map.get(@field, :format_display, false) do %>
        <div class="text-gray-500 text-xs mt-1">请输入11位手机号码</div>
      <% end %>
    </div>
    """
  end

  defp uploaded_files_list(assigns) do
    ~H"""
    <%= if @field.entries != [] do %>
      <div class="space-y-2">
        <%= for entry <- @field.entries do %>
          <div class="flex items-center justify-between p-2 bg-base-200 rounded-lg text-sm">
            <div class="flex items-center gap-2">
              <.live_img_preview entry={entry} class="h-8 w-8 object-cover rounded" />
              <div>
                <p class="font-medium"><%= entry.client_name %></p>
                <p class="text-xs text-base-content/70">
                  <%= entry.client_size |> MyAppWeb.Helpers.format_file_size() %>
                </p>
              </div>
            </div>
            <div class="flex items-center gap-4">
              <progress value={entry.progress} max="100" class="progress progress-primary w-24">
                <%= entry.progress %>%
              </progress>
              <%= unless @disabled do %>
                <button
                  type="button"
                  phx-click="cancel-upload"
                  phx-value-ref={entry.ref}
                  class="btn btn-ghost btn-sm btn-square"
                >
                  <.icon name="hero-x-mark" class="h-5 w-5" />
                </button>
              <% end %>
            </div>
          </div>
          <%= for err <- upload_errors(@field, entry) do %>
            <p class="text-sm text-error"><%= err %></p>
          <% end %>
        <% end %>
      </div>
    <% end %>
    """
  end
end