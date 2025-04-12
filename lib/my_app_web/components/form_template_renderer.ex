defmodule MyAppWeb.FormTemplateRenderer do
  @moduledoc """
  表单模板渲染模块。
  
  提供表单模板的加载、渲染和处理功能，支持将表单控件和装饰元素组合显示。
  """
  
  use Phoenix.Component
  import Phoenix.HTML
  
  alias MyApp.FormTemplates
  alias MyApp.Forms
  alias MyAppWeb.FormLive.ItemRendererComponent
  
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
    
    assigns = %{
      form: form,
      template: template,
      form_items: form_items,
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
        <%= render_decoration(decoration) %>
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
          <%= render_decoration(decoration) %>
        <% end %>
        
        <!-- 渲染表单项 -->
        <ItemRendererComponent.render_item item={item} mode={:display} form_data={@form_data} errors={@errors} />
        
        <!-- 渲染"after"装饰元素 -->
        <%= for decoration <- Enum.filter(@decorations, fn d -> 
            position = Map.get(d, "position") || Map.get(d, :position) || %{}
            position_type = Map.get(position, "type") || Map.get(position, :type)
            target_id = Map.get(position, "target_id") || Map.get(position, :target_id)
            position_type == "after" && target_id == item.id
          end) do %>
          <%= render_decoration(decoration) %>
        <% end %>
      <% end %>
      
      <!-- 3. 渲染位置为"end"的装饰元素 -->
      <%= for decoration <- Enum.filter(@decorations, fn d -> 
          position = Map.get(d, "position") || Map.get(d, :position) || %{}
          position_type = Map.get(position, "type") || Map.get(position, :type)
          position_type == "end"
        end) do %>
        <%= render_decoration(decoration) %>
      <% end %>
      
      <!-- 4. 渲染没有指定位置的装饰元素 -->
      <%= for decoration <- Enum.filter(@decorations, fn d -> 
          position = Map.get(d, "position") || Map.get(d, :position) || %{}
          position_type = Map.get(position, "type") || Map.get(position, :type)
          is_nil(position_type) || (position_type not in ["start", "end", "before", "after"])
        end) do %>
        <%= render_decoration(decoration) %>
      <% end %>
    </div>
    """
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
    # 从模板中筛选出属于当前页面的装饰元素
    # 假设装饰元素有page_id属性表示它们属于哪个页面
    current_page_id = current_page.id
    
    # 筛选与当前页面相关的装饰元素
    page_decorations = 
      if template && template.decoration && is_list(template.decoration) do
        Enum.filter(template.decoration, fn decoration ->
          # 如果装饰元素有page_id属性且匹配当前页面，或者没有page_id属性（全局装饰）
          page_id = Map.get(decoration, "page_id") || Map.get(decoration, :page_id)
          is_nil(page_id) || page_id == current_page_id
        end)
      else
        []
      end
    
    # 构建当前页面的表单项映射
    page_items_map = Enum.reduce(page_items, %{}, fn item, acc -> 
      Map.put(acc, item.id, item)
    end)
    
    assigns = %{
      form: form,
      template: template,
      current_page: current_page,
      page_items: page_items,
      page_items_map: page_items_map,
      page_decorations: page_decorations,
      form_data: form_data,
      errors: errors
    }
    
    # 使用优化的页面渲染逻辑
    ~H"""
    <div class="form-page-items">
      <%= if Enum.empty?(@page_decorations) do %>
        <!-- 如果没有装饰元素，直接渲染表单项 -->
        <%= for item <- @page_items do %>
          <ItemRendererComponent.render_item item={item} mode={:display} form_data={@form_data} errors={@errors} />
        <% end %>
      <% else %>
        <!-- 有装饰元素，按位置插入 -->
        <!-- 1. 首先渲染位置为"start"的装饰元素 -->
        <%= for decoration <- Enum.filter(@page_decorations, fn d -> 
            position = Map.get(d, "position") || Map.get(d, :position) || %{}
            position_type = Map.get(position, "type") || Map.get(position, :type)
            position_type == "start"
          end) do %>
          <%= render_decoration(decoration) %>
        <% end %>
        
        <!-- 2. 遍历表单项，将"before"和"after"的装饰元素插入适当位置 -->
        <%= for item <- @page_items do %>
          <!-- 渲染"before"装饰元素 -->
          <%= for decoration <- Enum.filter(@page_decorations, fn d -> 
              position = Map.get(d, "position") || Map.get(d, :position) || %{}
              position_type = Map.get(position, "type") || Map.get(position, :type)
              target_id = Map.get(position, "target_id") || Map.get(position, :target_id)
              position_type == "before" && target_id == item.id
            end) do %>
            <%= render_decoration(decoration) %>
          <% end %>
          
          <!-- 渲染表单项 -->
          <ItemRendererComponent.render_item item={item} mode={:display} form_data={@form_data} errors={@errors} />
          
          <!-- 渲染"after"装饰元素 -->
          <%= for decoration <- Enum.filter(@page_decorations, fn d -> 
              position = Map.get(d, "position") || Map.get(d, :position) || %{}
              position_type = Map.get(position, "type") || Map.get(position, :type)
              target_id = Map.get(position, "target_id") || Map.get(position, :target_id)
              position_type == "after" && target_id == item.id
            end) do %>
            <%= render_decoration(decoration) %>
          <% end %>
        <% end %>
        
        <!-- 3. 最后渲染位置为"end"的装饰元素 -->
        <%= for decoration <- Enum.filter(@page_decorations, fn d -> 
            position = Map.get(d, "position") || Map.get(d, :position) || %{}
            position_type = Map.get(position, "type") || Map.get(position, :type)
            position_type == "end"
          end) do %>
          <%= render_decoration(decoration) %>
        <% end %>
        
        <!-- 4. 渲染没有指定位置的装饰元素 -->
        <%= for decoration <- Enum.filter(@page_decorations, fn d -> 
            position = Map.get(d, "position") || Map.get(d, :position) || %{}
            position_type = Map.get(position, "type") || Map.get(position, :type)
            is_nil(position_type) || (position_type not in ["start", "end", "before", "after"])
          end) do %>
          <%= render_decoration(decoration) %>
        <% end %>
      <% end %>
    </div>
    """
  end
  
  # 渲染单个装饰元素
  defp render_decoration(decoration) do
    elem_id = Map.get(decoration, "id") || Map.get(decoration, :id)
    type = Map.get(decoration, "type") || Map.get(decoration, :type)
    
    case type do
      "title" ->
        title = Map.get(decoration, "title") || Map.get(decoration, :title) || "未命名标题"
        level = Map.get(decoration, "level") || Map.get(decoration, :level) || 2
        align = Map.get(decoration, "align") || Map.get(decoration, :align) || "left"
        
        title_html = render_title_html(title, level, align)
        assigns = %{elem_id: elem_id}
        ~H"""
        <div class="decoration-title" id={@elem_id}>
          <%= raw(title_html) %>
        </div>
        """
        
      "paragraph" ->
        content = Map.get(decoration, "content") || Map.get(decoration, :content) || ""
        assigns = %{content: content, elem_id: elem_id}
        ~H"""
        <div class="decoration-paragraph" id={@elem_id}>
          <p><%= @content %></p>
        </div>
        """
        
      "section" ->
        title = Map.get(decoration, "title") || Map.get(decoration, :title)
        divider_style = Map.get(decoration, "divider_style") || Map.get(decoration, :divider_style) || "solid"
        
        assigns = %{title: title, divider_style: divider_style, elem_id: elem_id}
        ~H"""
        <div class="decoration-section" id={@elem_id}>
          <hr class={"divider-#{@divider_style}"}>
          <%= if @title do %>
            <h3 class="section-title"><%= @title %></h3>
          <% end %>
        </div>
        """
        
      "explanation" ->
        content = Map.get(decoration, "content") || Map.get(decoration, :content) || ""
        note_type = Map.get(decoration, "note_type") || Map.get(decoration, :note_type) || "info"
        
        assigns = %{content: content, note_type: note_type, elem_id: elem_id}
        ~H"""
        <div class={"decoration-explanation explanation-#{@note_type}"} id={@elem_id}>
          <div class="explanation-content"><%= @content %></div>
        </div>
        """
        
      "header_image" ->
        image_url = Map.get(decoration, "image_url") || Map.get(decoration, :image_url) || ""
        height = Map.get(decoration, "height") || Map.get(decoration, :height) || "300px"
        alt = Map.get(decoration, "alt") || Map.get(decoration, :alt) || ""
        
        assigns = %{image_url: image_url, height: height, alt: alt, elem_id: elem_id}
        ~H"""
        <div class="decoration-header-image" id={@elem_id}>
          <img src={@image_url} alt={@alt} style={"height: #{@height}; width: 100%; object-fit: cover;"}>
        </div>
        """
        
      "inline_image" ->
        image_url = Map.get(decoration, "image_url") || Map.get(decoration, :image_url) || ""
        caption = Map.get(decoration, "caption") || Map.get(decoration, :caption)
        width = Map.get(decoration, "width") || Map.get(decoration, :width) || "100%"
        align = Map.get(decoration, "align") || Map.get(decoration, :align) || "center"
        
        assigns = %{image_url: image_url, caption: caption, width: width, align: align, elem_id: elem_id}
        ~H"""
        <div class="decoration-inline-image" id={@elem_id} style={"text-align: #{@align};"}>
          <img src={@image_url} alt={@caption || ""} style={"width: #{@width}; max-width: 100%;"}>
          <%= if @caption do %>
            <div class="image-caption"><%= @caption %></div>
          <% end %>
        </div>
        """
        
      "spacer" ->
        height = Map.get(decoration, "height") || Map.get(decoration, :height) || "20px"
        
        assigns = %{height: height, elem_id: elem_id}
        ~H"""
        <div class="decoration-spacer" id={@elem_id} style={"height: #{@height};"}></div>
        """
        
      _ ->
        # 默认情况，未知装饰元素类型
        assigns = %{type: type, elem_id: elem_id}
        ~H"""
        <div class="decoration-unknown" id={@elem_id}>
          <p>未知装饰元素类型: <%= @type %></p>
        </div>
        """
    end
  end
  
  # 渲染标题标签
  defp render_title_html(title, level, align) do
    tag_name = case level do
      1 -> "h1"
      2 -> "h2"
      3 -> "h3"
      _ -> "h4"
    end
    
    "<#{tag_name} style=\"text-align: #{align};\" class=\"decoration-title-text\">#{title}</#{tag_name}>"
  end
  
  # 无模板时渲染特定页面
  defp render_page_without_template(current_page, page_items, form_data, errors) do
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
end