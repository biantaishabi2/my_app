defmodule MyAppWeb.FormTemplateRenderer do
  @moduledoc """
  表单模板渲染模块。

  提供表单模板的加载、渲染和处理功能，支持将表单控件和装饰元素组合显示。
  """

  use Phoenix.Component
  import Phoenix.HTML
  require Logger

  alias MyApp.FormTemplates
  alias MyApp.Forms
  alias MyAppWeb.FormLive.ItemRendererComponent
  alias MyAppWeb.DecorationComponents

  @doc """
  加载表单关联的模板。

  ## 参数
    - form: 表单结构体

  ## 返回值
    表单模板结构体或nil（如果没有关联模板）
  """
  def load_form_template(form) do
    if form.form_template_id do
      FormTemplates.get_template(form.form_template_id)
    else
      nil
    end
  end

  @doc """
  加载表单的完整数据，包括关联的模板。

  ## 参数
    - form_id: 表单ID

  ## 返回值
    包含表单和关联模板的结构体
  """
  def load_form_with_template(form_id) do
    with form when not is_nil(form) <- Forms.get_form(form_id),
         template <- load_form_template(form) do
      %{form: form, template: template}
    else
      nil -> %{form: nil, template: nil}
      error -> error
    end
  end

  @doc """
  渲染完整表单，包含装饰元素。

  ## 参数
    - assigns: 包含表单和模板数据的assigns
      - form: 表单结构体
      - form_template: 表单模板结构体
      - form_data: 表单数据（可选）
      - mode: 渲染模式，:display（默认）或 :edit_preview

  ## 示例
    ```heex
    <.render_form_with_decorations
      form={@form}
      form_template={@form_template}
      form_data={@form_data}
    />
    ```
  """
  attr :form, :map, required: true
  attr :form_template, :map
  attr :form_data, :map, default: %{}
  attr :mode, :atom, default: :display
  attr :errors, :map, default: %{}
  # === Add jump_state attribute ===
  attr :jump_state, :map, default: %{active: false, target_id: nil}

  def render_form_with_decorations(assigns) do
    # --- LOGGING AT FUNCTION ENTRY ---
    Logger.debug("[FormTemplateRenderer ENTRY] Received assigns: #{inspect(assigns)}")
    Logger.debug("[FormTemplateRenderer ENTRY] Received form_data specifically: #{inspect(assigns[:form_data])}")
    # --- END LOGGING ---

    ~H"""
    <div id="form-renderer-#{@form.id}" class="form-container">
      <%= if @form_template do %>
        <%!-- === Pass jump_state down === --%>
        <%= render_with_template(@form, @form_template, @form_data, @mode, @errors, @jump_state) %>
      <% else %>
        <%= render_without_template(@form, @form_data, @mode, @errors) %>
      <% end %>
    </div>
    """
  end

  @doc """
  渲染特定页面，包含装饰元素。
  适用于分页表单场景。

  ## 参数
    - assigns: 包含表单、页面和模板数据的assigns
      - form: 表单结构体
      - form_template: 表单模板结构体
      - current_page: 当前页面
      - page_items: 当前页面的表单项
      - form_data: 表单数据（可选）
      - errors: 表单错误信息（可选）
  """
  attr :form, :map, required: true
  attr :form_template, :map
  attr :current_page, :map, required: true
  attr :page_items, :list, required: true
  attr :form_data, :map, default: %{}
  attr :errors, :map, default: %{}
  # === Add jump_state attribute for page rendering ===
  attr :jump_state, :map, default: %{active: false, target_id: nil}
  attr :form_render_key, :any # Keep this if added previously

  def render_page_with_decorations(assigns) do
    # --- LOGGING AT FUNCTION ENTRY ---
    Logger.debug("[FormTemplateRenderer Page ENTRY] Received assigns: #{inspect(assigns)}")
    Logger.debug("[FormTemplateRenderer Page ENTRY] Received form_data specifically: #{inspect(assigns[:form_data])}")
    # --- END LOGGING ---

    ~H"""
    <div id="form-renderer-page-#{@current_page.id}" class="form-page">
      <%= if @form_template do %>
        <%!-- === Pass jump_state down === --%>
        <%= render_page_with_template(@form, @form_template, @current_page, @page_items, @form_data, @errors, @jump_state) %>
      <% else %>
        <%= render_page_without_template(@current_page, @page_items, @form_data, @errors) %>
      <% end %>
    </div>
    """
  end

  # 使用模板渲染完整表单
  defp render_with_template(form, template, form_data, mode, errors, jump_state) do
    case mode do
      :display ->
        if template && template.decoration && is_list(template.decoration) && !Enum.empty?(template.decoration) do
          # 有装饰元素时，使用优化的渲染方法
          # === Pass jump_state down ===
          render_template_with_decorations(form, template, form_data, errors, jump_state)
        else
          # 无装饰元素或模板时，使用简单的模板渲染
          # Simple rendering doesn't use jump_state directly, maybe FormTemplates.render_template does?
          # Assuming it doesn't need jump_state for now.
          template_html = FormTemplates.render_template(template, form_data)
          raw(template_html)
        end

      :edit_preview ->
        # Edit preview likely doesn't need jump logic applied
        assigns = %{
          form: form,
          form_data: form_data,
          errors: errors
        }
        ~H"""
        <div class="form-template-preview">
          <div class="form-items">
            <%= for item <- @form.items do %>
              <ItemRendererComponent.render_item item={item} mode={:edit_preview} form_data={@form_data} errors={@errors} />
            <% end %>
          </div>
        </div>
        """
    end
  end

  # 构建表单项ID映射
  defp build_items_map(items) do
    Enum.reduce(items, %{}, fn item, acc ->
      Map.put(acc, to_string(item.id), item)
    end)
  end

  # 使用装饰元素渲染完整表单
  defp render_template_with_decorations(form, template, form_data, errors, jump_state) do
    require Logger

    form_items = form.items || []
    decorations = template.decoration || []
    items_map = build_items_map(form_items) # Build map from original items

    # Log the received jump_state
    Logger.debug("[Renderer] Received jump_state: #{inspect(jump_state)}")

    # === Fix assigns name and include jump_state ===
    assigns = %{
      form: form,
      template: template,
      form_items: form_items, # Pass original items
      decorations: decorations,
      items_map: items_map,
      form_data: form_data,
      form_state: form_data,  # Add form_state (same as form_data for compatibility)
      errors: errors,
      jump_state: jump_state # Pass jump_state to HEEx context
    }

    # === Restore original HEEx structure with correct jump_state usage ===
    ~H"""
    <div class="form-container-with-decorations">
      <!-- 显示跳转状态指示器（如果激活） -->
      <%= if @jump_state && @jump_state.active do %>
        <div class="bg-blue-100 border-l-4 border-blue-500 text-blue-700 p-4 mb-4" role="alert">
          <p class="font-bold">已跳转到指定问题</p>
          <p>根据您的选择，已跳过中间问题直接显示目标问题。</p>
        </div>
      <% end %>

      <!-- 1. 首先渲染位置为"start"的装饰元素 -->
      <%= for decoration <- Enum.filter(@decorations, fn d ->
          position = Map.get(d, "position") || Map.get(d, :position) || %{}
          position_type = Map.get(position, "type") || Map.get(position, :type)
          position_type == "start"
        end) do %>
        <.render_decoration element={decoration} />
      <% end %>

      <!-- 2. 遍历表单项，将"before"和"after"的装饰元素插入适当位置 -->
      <%= for item <- @form_items do %>
        <%!-- Determine visibility based on jump_state FIRST --%>
        <%{
          show_item = if @jump_state && @jump_state.active do
            # Jump active: only show source and target
            to_string(item.id) == to_string(@jump_state.source_id) || to_string(item.id) == to_string(@jump_state.target_id)
          else
            # Jump not active: show item by default
            true
          end
        }%>
        <%!-- === 使用CSS隐藏而非条件渲染 === --%>
        <div phx-key={item.id} style={if !show_item, do: "display: none;", else: ""}>
          <%
            # --- LOGGING BEFORE CALLING ItemRendererComponent ---
            Logger.debug("[FormTemplateRenderer] About to render item ID: #{inspect(item.id)}. Current @form_data: #{inspect(@form_data)}")
            # --- END LOGGING ---
          %>
          <!-- 渲染"before"装饰元素 -->
          <%= for decoration <- Enum.filter(@decorations, fn d ->
              position = Map.get(d, "position") || Map.get(d, :position) || %{}
              position_type = Map.get(position, "type") || Map.get(position, :type)
              target_id = Map.get(position, "target_id") || Map.get(position, :target_id)
              position_type == "before" && to_string(target_id) == to_string(item.id)
            end) do %>
            <.render_decoration element={decoration} />
          <% end %>

          <div data-item-id={item.id} class={if @jump_state.active && to_string(item.id) == to_string(@jump_state.target_id), do: "p-4 border-l-4 border-green-500 bg-green-50", else: ""}>
            <ItemRendererComponent.render_item item={item} mode={:display} form_data={@form_state} errors={@errors} />
          </div>

          <!-- 渲染"after"装饰元素 -->
          <%= for decoration <- Enum.filter(@decorations, fn d ->
              position = Map.get(d, "position") || Map.get(d, :position) || %{}
              position_type = Map.get(position, "type") || Map.get(position, :type)
              target_id = Map.get(position, "target_id") || Map.get(position, :target_id)
              position_type == "after" && to_string(target_id) == to_string(item.id)
            end) do %>
            <.render_decoration element={decoration} />
          <% end %>
        </div>
      <% end %>

      <!-- 3. 渲染位置为"end"的装饰元素 -->
      <%= for decoration <- Enum.filter(@decorations, fn d ->
          position = Map.get(d, "position") || Map.get(d, :position) || %{}
          position_type = Map.get(position, "type") || Map.get(position, :type)
          position_type == "end"
        end) do %>
        <.render_decoration element={decoration} />
      <% end %>

      <!-- 4. 渲染没有指定位置的装饰元素 -->
      <%= for decoration <- Enum.filter(@decorations, fn d ->
          position = Map.get(d, "position") || Map.get(d, :position) || %{}
          position_type = Map.get(position, "type") || Map.get(position, :type)
          is_nil(position_type) || (position_type not in ["start", "end", "before", "after"])
        end) do %>
        <.render_decoration element={decoration} />
      <% end %>
    </div>
    """
  end

  # 新增：渲染单个装饰元素的辅助函数
  # 它会根据元素类型调用 DecorationComponents 中的组件
  # 注意：这里假设 DecorationComponents 已经定义了相应的组件
  # 例如：DecorationComponents.title, DecorationComponents.paragraph 等
  # 并且这些组件接受一个 :element 的 assign，其中包含元素的所有属性。
  attr :element, :map, required: true
  defp render_decoration(assigns) do
    # 从 assigns map 中获取 element
    element = assigns.element
    type = element["type"] || element[:type]
    # 提取通用 ID，确保有值
    elem_id = element["id"] || element[:id] || Ecto.UUID.generate()

    case type do
      "title" ->
        title = Map.get(element, "title", Map.get(element, :title, "未命名标题"))
        level = Map.get(element, "level", Map.get(element, :level, 2))
        align = Map.get(element, "align", Map.get(element, :align, "left"))
        style = Map.get(element, "style", Map.get(element, :style))
        # 将需要传递的变量放入 assigns map
        assigns = %{
          elem_id: elem_id,
          title: title,
          level: level,
          align: align,
          style: style
        }
        # 将参数传递给 title_element 组件
        ~H"""
        <DecorationComponents.title_element
          id={@elem_id}
          title={@title}
          level={@level}
          align={@align}
          style={@style}
        />
        """
      "paragraph" ->
        content = Map.get(element, "content", Map.get(element, :content, ""))
        style = Map.get(element, "style", Map.get(element, :style))
        assigns = %{
          elem_id: elem_id,
          content: content,
          style: style
        }
        # 将参数传递给 content_paragraph 组件
        ~H"""
        <DecorationComponents.content_paragraph
          id={@elem_id}
          content={@content}
          style={@style}
        />
        """
      "section" ->
        title = Map.get(element, "title", Map.get(element, :title))
        divider_style = Map.get(element, "divider_style", Map.get(element, :divider_style, "solid"))
        assigns = %{
          elem_id: elem_id,
          title: title,
          divider_style: divider_style
        }
        # 将参数传递给 section_divider 组件
        ~H"""
        <DecorationComponents.section_divider
          id={@elem_id}
          title={@title}
          divider_style={@divider_style}
        />
        """
      "explanation" ->
        content = Map.get(element, "content", Map.get(element, :content, ""))
        icon = Map.get(element, "icon", Map.get(element, :icon, "info")) # 假设编辑器保存了icon, 否则用默认值
        note_type = Map.get(element, "note_type", Map.get(element, :note_type, "info"))
        assigns = %{
          elem_id: elem_id,
          content: content,
          icon: icon,
          note_type: note_type
        }
        # 将参数传递给 explanation_box 组件
        ~H"""
        <DecorationComponents.explanation_box
          id={@elem_id}
          content={@content}
          icon={@icon}
          type={@note_type}
        />
        """
      "header_image" ->
        image_url = Map.get(element, "image_url", Map.get(element, :image_url, ""))
        height = Map.get(element, "height", Map.get(element, :height, "300px"))
        alt = Map.get(element, "alt", Map.get(element, :alt, ""))
        assigns = %{
          elem_id: elem_id,
          image_url: image_url,
          height: height,
          alt: alt
        }
        # 直接传递独立参数给 header_image 组件
        ~H"""
        <DecorationComponents.header_image
          id={@elem_id}
          image_url={@image_url}
          height={@height}
          alt={@alt}
        />
        """
      "inline_image" ->
        image_url = Map.get(element, "image_url", Map.get(element, :image_url, ""))
        caption = Map.get(element, "caption", Map.get(element, :caption))
        width = Map.get(element, "width", Map.get(element, :width, "100%"))
        align = Map.get(element, "align", Map.get(element, :align, "center"))
        assigns = %{
          elem_id: elem_id,
          image_url: image_url,
          caption: caption,
          width: width,
          align: align
        }
        # 直接传递独立参数给 inline_image 组件
        ~H"""
        <DecorationComponents.inline_image
          id={@elem_id}
          image_url={@image_url}
          caption={@caption}
          width={@width}
          align={@align}
        />
        """
      # spacer 暂时不处理，归入未知类型
      # "spacer" -> ...
      _ ->
        # 对于未知类型或 spacer，渲染一个占位符或错误信息
        # 确保 assigns 包含 type 供 ~H 使用
        assigns = %{type: type}
        ~H"""
        <div class="text-red-500">未知或暂未处理的装饰元素类型: <%= @type %></div>
        """
    end
  end

  # 无模板时的渲染（回退到传统渲染）
  defp render_without_template(form, form_data, mode, errors) do
    assigns = %{
      form: form,
      form_data: form_data,
      mode: mode,
      errors: errors
    }
    ~H"""
    <div class="form-items">
      <%= for item <- @form.items do %>
        <ItemRendererComponent.render_item item={item} mode={@mode} form_data={@form_data} errors={@errors} />
      <% end %>
    </div>
    """
  end

  # === Modify to accept jump_state, fix assigns, restore HEEx ===
  defp render_page_with_template(form, template, current_page, page_items, form_data, errors, jump_state) do
    decorations = template.decoration || []
    pages = form.pages || []
    total_pages = length(pages)
    current_page_number = current_page.order

    # Log the received jump_state
    Logger.debug("[Renderer Page] Received jump_state: #{inspect(jump_state)}")

    # === Fix assigns name and include jump_state ===
    assigns = %{
      form: form,
      template: template,
      current_page: current_page,
      page_items: page_items, # Pass original page items
      form_data: form_data,
      form_state: form_data,  # Add form_state (same as form_data for compatibility) 
      errors: errors,
      decorations: decorations,
      current_page_number: current_page_number,
      total_pages: total_pages,
      jump_state: jump_state # Pass jump_state to HEEx context
    }

    # === Restore original HEEx structure with correct jump_state usage ===
    ~H"""
    <div class="form-page-items">
      <!-- 显示跳转状态指示器（如果激活） -->
      <%= if @jump_state && @jump_state.active do %>
        <div class="bg-blue-100 border-l-4 border-blue-500 text-blue-700 p-4 mb-4" role="alert">
          <p class="font-bold">已跳转到指定问题</p>
          <p>根据您的选择，已跳过中间问题直接显示目标问题。</p>
        </div>
      <% end %>

      <!-- 1. 仅在第一页渲染 "start" 装饰元素 -->
      <%= if @current_page_number == 1 do %>
        <%= for decoration <- Enum.filter(@decorations, fn d ->
            position = Map.get(d, "position") || Map.get(d, :position) || %{}
            position_type = Map.get(position, "type") || Map.get(position, :type)
            position_type == "start"
          end) do %>
          <.render_decoration element={decoration} />
        <% end %>
      <% end %>

      <!-- 2. 遍历当前页的表单项，渲染 before/after 装饰元素 -->
      <%= for item <- @page_items do %>
        <%!-- Determine visibility based on jump_state FIRST --%>
        <%{
          show_item = if @jump_state && @jump_state.active do
            # Jump active: only show source and target
            to_string(item.id) == to_string(@jump_state.source_id) || to_string(item.id) == to_string(@jump_state.target_id)
          else
            # Jump not active: show item by default
            true
          end
        }%>
        <%!-- === 使用CSS隐藏而非条件渲染 === --%>
        <div phx-key={item.id} style={if !show_item, do: "display: none;", else: ""}>
          <%
            # --- LOGGING BEFORE CALLING ItemRendererComponent ---
            Logger.debug("[FormTemplateRenderer] About to render item ID: #{inspect(item.id)}. Current @form_data: #{inspect(@form_data)}")
            # --- END LOGGING ---
          %>
          <!-- 渲染 "before" 装饰元素 -->
          <%= for decoration <- Enum.filter(@decorations, fn d ->
              position = Map.get(d, "position") || Map.get(d, :position) || %{}
              position_type = Map.get(position, "type") || Map.get(position, :type)
              target_id = Map.get(position, "target_id") || Map.get(position, :target_id)
              position_type == "before" && to_string(target_id) == to_string(item.id)
            end) do %>
            <.render_decoration element={decoration} />
          <% end %>

          <div data-item-id={item.id} class={if @jump_state.active && to_string(item.id) == to_string(@jump_state.target_id), do: "p-4 border-l-4 border-green-500 bg-green-50", else: ""}>
            <ItemRendererComponent.render_item item={item} mode={:display} form_data={@form_state} errors={@errors} />
          </div>

          <!-- 渲染 "after" 装饰元素 -->
          <%= for decoration <- Enum.filter(@decorations, fn d ->
              position = Map.get(d, "position") || Map.get(d, :position) || %{}
              position_type = Map.get(position, "type") || Map.get(position, :type)
              target_id = Map.get(position, "target_id") || Map.get(position, :target_id)
              position_type == "after" && to_string(target_id) == to_string(item.id)
            end) do %>
            <.render_decoration element={decoration} />
          <% end %>
        </div>
      <% end %>

      <!-- 3. 仅在最后一页渲染 "end" 装饰元素 -->
      <%= if @current_page_number == @total_pages do %>
        <%= for decoration <- Enum.filter(@decorations, fn d ->
            position = Map.get(d, "position") || Map.get(d, :position) || %{}
            position_type = Map.get(position, "type") || Map.get(position, :type)
            position_type == "end"
          end) do %>
          <.render_decoration element={decoration} />
        <% end %>
      <% end %>

      <!-- 4. 不渲染无位置或未知位置的装饰元素 -->

    </div>
    """
  end

  # 无模板时渲染特定页面
  defp render_page_without_template(current_page, page_items, form_data, errors) do
    # !!! FIX: Create assigns map for ~H sigil !!!
    assigns = %{
      current_page: current_page,
      page_items: page_items,
      form_data: form_data,
      errors: errors
    }

    ~H"""
    <div class="form-page-items">
      <%= for item <- @page_items do %>
        <ItemRendererComponent.render_item item={item} mode={:display} form_data={@form_data} errors={@errors} />
      <% end %>
    </div>
    """
  end

  # 其他辅助函数可以在这里添加...

  # 其他辅助函数可以在这里添加...

  # Note: These functions have been commented out as they are now handled directly in the HEEx templates
  # using the jump_state map passed through assigns.

  # For future reference, if we need to reimplement complex visibility logic:
  # defp evaluate_item_visibility(item, template_logic, jump_state, default_visibility) do
  #   # Logic for determining item visibility based on jump_state and template_logic
  # end
end
