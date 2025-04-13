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

  def render_form_with_decorations(assigns) do
    ~H"""
    <div class="form-container">
      <%= if @form_template do %>
        <%= render_with_template(@form, @form_template, @form_data, @mode, @errors) %>
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

  def render_page_with_decorations(assigns) do
    ~H"""
    <div class="form-page">
      <%= if @form_template do %>
        <%= render_page_with_template(@form, @form_template, @current_page, @page_items, @form_data, @errors) %>
      <% else %>
        <%= render_page_without_template(@current_page, @page_items, @form_data, @errors) %>
      <% end %>
    </div>
    """
  end

  # 使用模板渲染完整表单
  defp render_with_template(form, template, form_data, mode, errors) do
    case mode do
      :display ->
        if template && template.decoration && is_list(template.decoration) && !Enum.empty?(template.decoration) do
          # 有装饰元素时，使用优化的渲染方法
          render_template_with_decorations(form, template, form_data, errors)
        else
          # 无装饰元素或模板时，使用简单的模板渲染
          template_html = FormTemplates.render_template(template, form_data)
          raw(template_html)
        end

      :edit_preview ->
        # 在编辑预览模式下使用定制渲染，可能需要额外的控制
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

  # 使用装饰元素渲染完整表单
  defp render_template_with_decorations(form, template, form_data, errors) do
    # 筛选表单项
    form_items = form.items || []

    # 获取所有装饰元素
    decorations = template.decoration || []

    # 构建表单项映射
    items_map = Enum.reduce(form_items, %{}, fn item, acc ->
      Map.put(acc, item.id, item)
    end)
    
    # 预处理表单项的可见性状态
    form_items_with_visibility = Enum.map(form_items, fn item ->
      # 检查常规可见性条件
      visibility_condition_result = is_nil(item.visibility_condition) || 
                                   MyApp.FormLogic.should_show_item?(item, form_data)
      
      # 检查模板逻辑中的条件
      template_logic = Map.get(item, :logic) || Map.get(item, "logic")
      
      should_show = evaluate_item_visibility(item, template_logic, form_data, visibility_condition_result)
      
      Logger.info("表单项 #{item.id} (#{item.label || "无标签"}) 的可见性结果: #{should_show}")
      
      # 将可见性状态添加到表单项
      Map.put(item, :should_show, should_show)
    end)

    assigns = %{
      form: form,
      template: template,
      form_items: form_items_with_visibility,
      decorations: decorations,
      items_map: items_map,
      form_data: form_data,
      errors: errors
    }

    ~H"""
    <div class="form-container-with-decorations">
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
        <!-- 渲染"before"装饰元素 -->
        <%= for decoration <- Enum.filter(@decorations, fn d ->
            position = Map.get(d, "position") || Map.get(d, :position) || %{}
            position_type = Map.get(position, "type") || Map.get(position, :type)
            target_id = Map.get(position, "target_id") || Map.get(position, :target_id)
            position_type == "before" && target_id == item.id
          end) do %>
          <.render_decoration element={decoration} />
        <% end %>

        <!-- 渲染表单项，检查条件可见性 -->
        <%= if Map.get(item, :should_show, true) do %>
          <div data-item-id={item.id}>
            <ItemRendererComponent.render_item item={item} mode={:display} form_data={@form_data} errors={@errors} />
          </div>
        <% end %>

        <!-- 渲染"after"装饰元素 -->
        <%= for decoration <- Enum.filter(@decorations, fn d ->
            position = Map.get(d, "position") || Map.get(d, :position) || %{}
            position_type = Map.get(position, "type") || Map.get(position, :type)
            target_id = Map.get(position, "target_id") || Map.get(position, :target_id)
            position_type == "after" && target_id == item.id
          end) do %>
          <.render_decoration element={decoration} />
        <% end %>
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

  # 使用模板渲染特定页面
  defp render_page_with_template(form, template, current_page, page_items, form_data, errors) do
    # 获取所有装饰元素
    decorations = template.decoration || []

    # 获取当前页码和总页数 (假设 form.pages 是一个列表，并且 current_page 有 order)
    pages = form.pages || []
    total_pages = length(pages)
    current_page_number = current_page.order # 假设 current_page.order 代表页码 (从1开始)
    
    # 预处理表单项的可见性状态
    page_items_with_visibility = Enum.map(page_items, fn item ->
      # 检查常规可见性条件
      visibility_condition_result = is_nil(item.visibility_condition) || 
                                   MyApp.FormLogic.should_show_item?(item, form_data)
      
      # 检查模板逻辑中的条件
      template_logic = Map.get(item, :logic) || Map.get(item, "logic")
      
      should_show = evaluate_item_visibility(item, template_logic, form_data, visibility_condition_result)
      
      Logger.info("表单项 #{item.id} (#{item.label || "无标签"}) 的可见性结果: #{should_show}")
      
      # 将可见性状态添加到表单项
      Map.put(item, :should_show, should_show)
    end)

    assigns = %{
      form: form,
      template: template,
      current_page: current_page,
      page_items: page_items_with_visibility,
      form_data: form_data,
      errors: errors,
      decorations: decorations,
      current_page_number: current_page_number,
      total_pages: total_pages
    }

    ~H"""
    <div class="form-page-items">
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
        <!-- 渲染 "before" 装饰元素 -->
        <%= for decoration <- Enum.filter(@decorations, fn d ->
            position = Map.get(d, "position") || Map.get(d, :position) || %{}
            position_type = Map.get(position, "type") || Map.get(position, :type)
            target_id = Map.get(position, "target_id") || Map.get(position, :target_id)
            position_type == "before" && target_id == item.id
          end) do %>
          <.render_decoration element={decoration} />
        <% end %>

        <!-- 渲染表单项，检查条件可见性 -->
        <%= if Map.get(item, :should_show, true) do %>
          <div data-item-id={item.id}>
            <ItemRendererComponent.render_item item={item} mode={:display} form_data={@form_data} errors={@errors} />
          </div>
        <% end %>

        <!-- 渲染 "after" 装饰元素 -->
        <%= for decoration <- Enum.filter(@decorations, fn d ->
            position = Map.get(d, "position") || Map.get(d, :position) || %{}
            position_type = Map.get(position, "type") || Map.get(position, :type)
            target_id = Map.get(position, "target_id") || Map.get(position, :target_id)
            position_type == "after" && target_id == item.id
          end) do %>
          <.render_decoration element={decoration} />
        <% end %>
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
  
  # 评估表单项可见性
  defp evaluate_item_visibility(item, template_logic, form_data, default_visibility) do
    if template_logic && (Map.get(template_logic, "type") == "visibility" || Map.get(template_logic, "type") == "jump") do
      # 从模板逻辑中提取条件
      condition = Map.get(template_logic, "condition") || %{}
      source_id = Map.get(template_logic, "source_id") || Map.get(template_logic, :source_id) || 
                   Map.get(condition, "source_id") || Map.get(condition, :source_id)
      operator = Map.get(condition, "operator") || Map.get(condition, :operator)
      value = Map.get(condition, "value") || Map.get(condition, :value)
      
      Logger.info("评估模板条件逻辑 - 项目: #{item.id}, 源: #{source_id}, 操作符: #{operator}, 值: #{inspect(value)}")
      
      # 创建简单条件并评估
      if source_id && operator && value do
        # 如果是跳转逻辑，处理方式稍有不同
        if Map.get(template_logic, "type") == "jump" do
          # 获取源字段的值和目标ID
          source_value = Map.get(form_data, source_id)
          target_id = Map.get(template_logic, "target_id")
          
          # 评估条件
          simple_condition = %{"type" => "simple", "source_item_id" => source_id, "operator" => operator, "value" => value}
          condition_result = MyApp.FormLogic.evaluate_condition(simple_condition, form_data)
          
          # 如果条件满足，则只显示目标项；如果不满足，显示所有项
          if condition_result do
            # 跳转逻辑满足时，只有目标项显示
            item.id == target_id
          else
            # 跳转逻辑不满足时，显示所有项
            true
          end
        else
          # 标准可见性逻辑
          simple_condition = %{"type" => "simple", "source_item_id" => source_id, "operator" => operator, "value" => value}
          MyApp.FormLogic.evaluate_condition(simple_condition, form_data)
        end
      else
        true # 如果条件不完整，默认显示
      end
    else
      default_visibility # 如果没有模板逻辑，使用传入的默认可见性
    end
  end
end
