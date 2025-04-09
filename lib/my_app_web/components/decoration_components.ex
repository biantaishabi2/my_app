defmodule MyAppWeb.DecorationComponents do
  use Phoenix.Component
  import Phoenix.LiveView.Helpers
  import MyAppWeb.CoreComponents
  import Phoenix.HTML

  # 标题组件
  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :level, :integer, default: 1
  attr :style, :string, default: nil
  attr :align, :string, default: "left" # left, center, right

  def title_element(assigns) do
    assigns = assign_new(assigns, :tag, fn ->
      case assigns.level do
        1 -> "h1"
        2 -> "h2"
        3 -> "h3"
        _ -> "h4"
      end
    end)

    ~H"""
    <div id={@id} class="decoration-title decoration-element">
      <div class={"title-level-#{@level}"} style={"text-align: #{@align};"}>
        <%= Phoenix.HTML.Tag.content_tag @tag, @title, class: "decoration-title-text", style: @style %>
      </div>
    </div>
    """
  end

  # 题图组件
  attr :id, :string, required: true
  attr :image_url, :string, required: true
  attr :height, :string, default: "300px"
  attr :alt, :string, default: ""

  def header_image(assigns) do
    ~H"""
    <div id={@id} class="decoration-header-image decoration-element">
      <img src={@image_url} alt={@alt} style={"height: #{@height}; width: 100%; object-fit: cover;"} />
    </div>
    """
  end

  # 内容段落
  attr :id, :string, required: true
  attr :content, :string, required: true
  attr :style, :string, default: nil

  def content_paragraph(assigns) do
    ~H"""
    <div id={@id} class="decoration-paragraph decoration-element" style={@style}>
      <div class="rich-text-content">
        <%= raw(@content) %>
      </div>
    </div>
    """
  end

  # 章节划分
  attr :id, :string, required: true
  attr :title, :string, default: nil
  attr :divider_style, :string, default: "solid"

  def section_divider(assigns) do
    ~H"""
    <div id={@id} class="decoration-divider decoration-element">
      <div class="section-divider">
        <hr class={"divider-#{@divider_style}"} />
        <%= if @title do %>
          <h3 class="section-title"><%= @title %></h3>
        <% end %>
      </div>
    </div>
    """
  end

  # 解释文本
  attr :id, :string, required: true
  attr :content, :string, required: true
  attr :icon, :string, default: "info"
  attr :type, :string, default: "info" # info, warning, tip

  def explanation_box(assigns) do
    ~H"""
    <div id={@id} class={"decoration-explanation decoration-element explanation-#{@type}"}>
      <div class="explanation-header">
        <span class="explanation-icon"><%= @icon %></span>
        <span class="explanation-title"><%= String.capitalize(@type) %></span>
      </div>
      <div class="explanation-content">
        <%= raw(@content) %>
      </div>
    </div>
    """
  end

  # 中间插图
  attr :id, :string, required: true
  attr :image_url, :string, required: true
  attr :caption, :string, default: nil
  attr :width, :string, default: "100%"
  attr :align, :string, default: "center" # left, center, right

  def inline_image(assigns) do
    ~H"""
    <div id={@id} class="decoration-inline-image decoration-element" style={"text-align: #{@align};"}>
      <img src={@image_url} alt={@caption} style={"width: #{@width}; max-width: 100%;"} />
      <%= if @caption do %>
        <div class="image-caption"><%= @caption %></div>
      <% end %>
    </div>
    """
  end

  # 装饰元素编辑器组件
  attr :id, :string, required: true
  attr :element, :map, required: true
  attr :on_change, :string, default: "update_decoration_element"
  attr :on_delete, :string, default: "delete_decoration_element"

  def decoration_element_editor(assigns) do
    ~H"""
    <div id={"editor-#{@id}"} class="decoration-element-editor">
      <div class="element-editor-header">
        <div class="element-type">
          <%= display_element_type(@element.type) %>
        </div>
        <div class="element-actions">
          <button
            type="button"
            phx-click={@on_delete}
            phx-value-id={@id}
            class="delete-element-btn"
          >
            删除
          </button>
        </div>
      </div>
      <div class="element-editor-body">
        <%= render_element_editor(@element) %>
      </div>
    </div>
    """
  end

  # 辅助函数 - 显示元素类型的友好名称
  def display_element_type(type) do
    case type do
      "title" -> "标题"
      "header_image" -> "题图"
      "paragraph" -> "内容段落"
      "section" -> "章节划分"
      "explanation" -> "解释文本"
      "inline_image" -> "插图"
      _ -> "未知元素"
    end
  end

  # 辅助函数 - 根据元素类型渲染对应的编辑表单
  def render_element_editor(element) do
    case element.type do
      "title" -> render_title_editor(element)
      "header_image" -> render_image_editor(element)
      "paragraph" -> render_paragraph_editor(element)
      "section" -> render_section_editor(element)
      "explanation" -> render_explanation_editor(element)
      "inline_image" -> render_inline_image_editor(element)
      _ -> render_unknown_editor(element)
    end
  end

  # 以下是各类元素编辑器的渲染函数，实际实现取决于您的需求
  defp render_title_editor(element) do
    assigns = %{}
    ~H"""
    <div class="title-editor">
      <div class="form-group">
        <label>标题文本</label>
        <input type="text" name="title" value={element.title} phx-change="update_decoration_element" phx-value-id={element.id} phx-value-field="title" />
      </div>
      <div class="form-group">
        <label>标题层级</label>
        <select name="level" phx-change="update_decoration_element" phx-value-id={element.id} phx-value-field="level">
          <option value="1" selected={element.level == 1}>大标题 (H1)</option>
          <option value="2" selected={element.level == 2}>中标题 (H2)</option>
          <option value="3" selected={element.level == 3}>小标题 (H3)</option>
          <option value="4" selected={element.level == 4}>微标题 (H4)</option>
        </select>
      </div>
      <div class="form-group">
        <label>对齐方式</label>
        <select name="align" phx-change="update_decoration_element" phx-value-id={element.id} phx-value-field="align">
          <option value="left" selected={element.align == "left"}>左对齐</option>
          <option value="center" selected={element.align == "center"}>居中</option>
          <option value="right" selected={element.align == "right"}>右对齐</option>
        </select>
      </div>
    </div>
    """
  end

  defp render_image_editor(element) do
    assigns = %{}
    ~H"""
    <div class="image-editor">
      <div class="form-group">
        <label>图片URL</label>
        <input type="text" name="image_url" value={element.image_url} phx-change="update_decoration_element" phx-value-id={element.id} phx-value-field="image_url" />
      </div>
      <div class="form-group">
        <label>高度</label>
        <input type="text" name="height" value={element.height} phx-change="update_decoration_element" phx-value-id={element.id} phx-value-field="height" />
      </div>
      <div class="form-group">
        <label>替代文本</label>
        <input type="text" name="alt" value={element.alt} phx-change="update_decoration_element" phx-value-id={element.id} phx-value-field="alt" />
      </div>
    </div>
    """
  end

  defp render_paragraph_editor(element) do
    assigns = %{}
    ~H"""
    <div class="paragraph-editor">
      <div class="form-group">
        <label>段落内容</label>
        <textarea name="content" rows="4" phx-change="update_decoration_element" phx-value-id={element.id} phx-value-field="content">{element.content}</textarea>
      </div>
    </div>
    """
  end

  defp render_section_editor(element) do
    assigns = %{}
    ~H"""
    <div class="section-editor">
      <div class="form-group">
        <label>章节标题（可选）</label>
        <input type="text" name="title" value={element.title} phx-change="update_decoration_element" phx-value-id={element.id} phx-value-field="title" />
      </div>
      <div class="form-group">
        <label>分隔线样式</label>
        <select name="divider_style" phx-change="update_decoration_element" phx-value-id={element.id} phx-value-field="divider_style">
          <option value="solid" selected={element.divider_style == "solid"}>实线</option>
          <option value="dashed" selected={element.divider_style == "dashed"}>虚线</option>
          <option value="dotted" selected={element.divider_style == "dotted"}>点线</option>
          <option value="double" selected={element.divider_style == "double"}>双线</option>
        </select>
      </div>
    </div>
    """
  end

  defp render_explanation_editor(element) do
    assigns = %{}
    ~H"""
    <div class="explanation-editor">
      <div class="form-group">
        <label>解释内容</label>
        <textarea name="content" rows="4" phx-change="update_decoration_element" phx-value-id={element.id} phx-value-field="content">{element.content}</textarea>
      </div>
      <div class="form-group">
        <label>类型</label>
        <select name="type" phx-change="update_decoration_element" phx-value-id={element.id} phx-value-field="type">
          <option value="info" selected={element.type == "info"}>信息</option>
          <option value="warning" selected={element.type == "warning"}>警告</option>
          <option value="tip" selected={element.type == "tip"}>提示</option>
        </select>
      </div>
    </div>
    """
  end

  defp render_inline_image_editor(element) do
    assigns = %{}
    ~H"""
    <div class="inline-image-editor">
      <div class="form-group">
        <label>图片URL</label>
        <input type="text" name="image_url" value={element.image_url} phx-change="update_decoration_element" phx-value-id={element.id} phx-value-field="image_url" />
      </div>
      <div class="form-group">
        <label>图片说明</label>
        <input type="text" name="caption" value={element.caption} phx-change="update_decoration_element" phx-value-id={element.id} phx-value-field="caption" />
      </div>
      <div class="form-group">
        <label>宽度</label>
        <input type="text" name="width" value={element.width} phx-change="update_decoration_element" phx-value-id={element.id} phx-value-field="width" />
      </div>
      <div class="form-group">
        <label>对齐方式</label>
        <select name="align" phx-change="update_decoration_element" phx-value-id={element.id} phx-value-field="align">
          <option value="left" selected={element.align == "left"}>左对齐</option>
          <option value="center" selected={element.align == "center"}>居中</option>
          <option value="right" selected={element.align == "right"}>右对齐</option>
        </select>
      </div>
    </div>
    """
  end

  defp render_unknown_editor(element) do
    assigns = %{}
    ~H"""
    <div class="unknown-element-editor">
      <p>未知的元素类型: <%= element.type %></p>
    </div>
    """
  end
end
