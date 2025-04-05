defmodule MyAppWeb.FormComponents do
  use Phoenix.Component
  
  # 这些导入虽然当前未直接使用，但在组件开发中可能需要
  # 保留以备将来扩展组件功能时使用
  # HTML标记处理 - 用于HTML转义和安全处理
  # import Phoenix.HTML
  
  # 表单辅助函数 - 用于生成表单和表单元素
  # import Phoenix.HTML.Form
  
  # LiveView辅助函数 - 用于事件处理和DOM操作
  # import Phoenix.LiveView.Helpers

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
        </div>
        
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">描述（可选）</label>
          <textarea
            name="item[description]"
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500"
            rows="2"
            placeholder="请输入描述信息"
          ><%= @item.description || "" %></textarea>
        </div>
        
        <div class="flex items-center">
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
        
        <%= if @item.type in [:radio, :dropdown, :checkbox] || @item_type in ["radio", "dropdown", "checkbox"] do %>
          <div class="pt-4 border-t border-gray-200">
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
  defp display_item_type(_), do: "未知类型"

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
end