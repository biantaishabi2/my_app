defmodule MyAppWeb.DecorationHelpers do
  @moduledoc """
  Helper functions for rendering decoration elements.
  """
  use Phoenix.Component

  @doc """
  Displays the user-friendly name for a decoration element type.
  """
  def display_decoration_type(nil), do: "未知类型"
  def display_decoration_type("title"), do: "标题"
  def display_decoration_type("paragraph"), do: "段落"
  def display_decoration_type("section"), do: "章节分隔"
  def display_decoration_type("explanation"), do: "解释框"
  def display_decoration_type("header_image"), do: "题图"
  def display_decoration_type("inline_image"), do: "插图"
  def display_decoration_type("spacer"), do: "空间"
  def display_decoration_type(atom) when is_atom(atom), do: display_decoration_type(Atom.to_string(atom))
  def display_decoration_type(_), do: "未知类型"

  @doc """
  Truncates a string to a maximum length, adding ellipsis if truncated.
  """
  def truncate(text, max_length) when is_binary(text) and is_integer(max_length) and max_length >= 0 do
    if String.length(text) > max_length do
      String.slice(text, 0, max_length) <> "..."
    else
      text
    end
  end
  def truncate(text, _max_length) when is_binary(text), do: text # Handle invalid max_length
  def truncate(_, _), do: "" # Handle non-binary text

  @doc """
  Renders a preview of a decoration element.
  """
  attr :element, :map, required: true, doc: "The decoration element map."
  def render_decoration_preview(assigns) do
    ~H"""
    <%= case @element["type"] || @element[:type] do %>
      <% "title" -> %>
        <div style={"text-align: #{@element["align"] || @element[:align] || "left"};"}>
          <%= case @element["level"] || @element[:level] || 1 do %>
            <% 1 -> %><h1 style="font-size: 1.5rem; font-weight: 700;"><%= @element["title"] || @element[:title] || "未命名标题" %></h1>
            <% 2 -> %><h2 style="font-size: 1.25rem; font-weight: 600;"><%= @element["title"] || @element[:title] || "未命名标题" %></h2>
            <% 3 -> %><h3 style="font-size: 1.125rem; font-weight: 500;"><%= @element["title"] || @element[:title] || "未命名标题" %></h3>
            <% _ -> %><h4 style="font-size: 1rem; font-weight: 500;"><%= @element["title"] || @element[:title] || "未命名标题" %></h4>
          <% end %>
        </div>
      <% "paragraph" -> %>
        <div class="text-gray-700 prose prose-sm max-w-none">
          <%= Phoenix.HTML.raw(@element["content"] || @element[:content] || "") %>
        </div>
      <% "section" -> %>
        <% title = @element["title"] || @element[:title] %>
        <% divider_style = @element["divider_style"] || @element[:divider_style] || "solid" %>
        <div>
          <hr style={"border-style: #{divider_style}; border-color: #e5e7eb;"} />
          <%= if title do %>
            <h3 style="font-size: 1.125rem; font-weight: 500; margin-top: 0.5rem;"><%= title %></h3>
          <% end %>
        </div>
      <% "explanation" -> %>
        <% content = @element["content"] || @element[:content] || "" %>
        <% note_type = @element["note_type"] || @element[:note_type] || "info" %>
        <% bg_color = case note_type do "warning" -> "#fff7ed"; "tip" -> "#f0fdf4"; _ -> "#f0f9ff" end %>
        <% border_color = case note_type do "warning" -> "#fdba74"; "tip" -> "#86efac"; _ -> "#bae6fd" end %>
        <% icon = case note_type do "warning" -> "⚠️"; "tip" -> "💡"; _ -> "ℹ️" end %>
        <div style={"background-color: #{bg_color}; border-left: 4px solid #{border_color}; padding: 1rem; border-radius: 0.25rem;"}>
          <div style="display: flex; align-items: flex-start; gap: 0.5rem;">
            <div style="font-size: 1.25rem; line-height: 1.25;"><%= icon %></div>
            <div>
              <div style="font-weight: 500; margin-bottom: 0.25rem;"><%= String.capitalize(note_type) %></div>
              <div class="text-gray-700 prose prose-sm max-w-none">
                <%= Phoenix.HTML.raw(content) %>
              </div>
            </div>
          </div>
        </div>
      <% "header_image" -> %>
        <% image_url = @element["image_url"] || @element[:image_url] || "" %>
        <% height = @element["height"] || @element[:height] || "200px" %>
        <div>
          <%= if image_url != "" do %>
            <img src={image_url} alt="题图" style={"height: #{height}; width: 100%; object-fit: cover; border-radius: 0.25rem;"} />
          <% else %>
            <div style={"height: #{height}; width: 100%; background-color: #f3f4f6; display: flex; align-items: center; justify-content: center; border-radius: 0.25rem;"}>
              <span class="text-gray-400">请设置图片URL</span>
            </div>
          <% end %>
        </div>
      <% "inline_image" -> %>
        <% image_url = @element["image_url"] || @element[:image_url] || "" %>
        <% caption = @element["caption"] || @element[:caption] || "" %>
        <% width = @element["width"] || @element[:width] || "100%" %>
        <% align = @element["align"] || @element[:align] || "center" %>
        <div style={"text-align: #{align};"}>
          <%= if image_url != "" do %>
            <img src={image_url} alt={caption} style={"width: #{width}; max-width: 100%; border-radius: 0.25rem; margin-left: auto; margin-right: auto;"} />
          <% else %>
            <div style={"width: #{width}; max-width: 100%; margin: 0 auto; height: 150px; background-color: #f3f4f6; display: flex; align-items: center; justify-content: center; border-radius: 0.25rem;"}>
              <span class="text-gray-400">请设置图片URL</span>
            </div>
          <% end %>
          <%= if caption != "" do %>
            <div style="margin-top: 0.5rem; font-size: 0.875rem; color: #6b7280;"><%= caption %></div>
          <% end %>
        </div>
      <% "spacer" -> %>
        <div style={"height: #{@element["height"] || @element[:height] || "1rem"};"} class="spacer"></div>
      <% _ -> %>
        <div class="text-gray-500">未知元素预览</div>
    <% end %>
    """
  end

  @doc """
  Renders an editor form for a decoration element.
  """
  attr :element, :map, required: true, doc: "The decoration element map."
  def render_decoration_editor(assigns) do
    ~H"""
    <%= case @element["type"] || @element[:type] do %>
      <% "title" -> %>
        <% title = @element["title"] || @element[:title] || "" %>
        <% level = @element["level"] || @element[:level] || 2 %>
        <% align = @element["align"] || @element[:align] || "left" %>
        <form phx-submit="save_decoration_element" phx-value-id={@element["id"] || @element[:id]}>
          <div class="space-y-3">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">标题文本</label>
              <input type="text" name="title" value={title} required class="block w-full px-3 py-2 bg-white border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm" />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">标题级别</label>
              <select name="level" class="block w-full px-3 py-2 bg-white border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm">
                <option value="1" selected={level == 1}>大标题 (H1)</option>
                <option value="2" selected={level == 2}>中标题 (H2)</option>
                <option value="3" selected={level == 3}>小标题 (H3)</option>
                <option value="4" selected={level == 4}>微标题 (H4)</option>
              </select>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">对齐方式</label>
              <select name="align" class="block w-full px-3 py-2 bg-white border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm">
                <option value="left" selected={align == "left"}>左对齐</option>
                <option value="center" selected={align == "center"}>居中</option>
                <option value="right" selected={align == "right"}>右对齐</option>
              </select>
            </div>
            <.form_actions />
          </div>
        </form>
      <% "paragraph" -> %>
        <% content = @element["content"] || @element[:content] || "" %>
        <form phx-submit="save_decoration_element" phx-value-id={@element["id"] || @element[:id]}>
          <div class="space-y-3">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">段落内容</label>
              <textarea name="content" rows="5" class="block w-full px-3 py-2 bg-white border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm"><%= content %></textarea>
              <p class="mt-1 text-xs text-gray-500">支持基本的HTML标签</p>
            </div>
            <.form_actions />
          </div>
        </form>
      <% "section" -> %>
         <% title = @element["title"] || @element[:title] || "" %>
         <% divider_style = @element["divider_style"] || @element[:divider_style] || "solid" %>
        <form phx-submit="save_decoration_element" phx-value-id={@element["id"] || @element[:id]}>
          <div class="space-y-3">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">章节标题（可选）</label>
              <input type="text" name="title" value={title} class="block w-full px-3 py-2 bg-white border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm" />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">分隔线样式</label>
              <select name="divider_style" class="block w-full px-3 py-2 bg-white border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm">
                <option value="solid" selected={divider_style == "solid"}>实线</option>
                <option value="dashed" selected={divider_style == "dashed"}>虚线</option>
                <option value="dotted" selected={divider_style == "dotted"}>点线</option>
                <option value="double" selected={divider_style == "double"}>双线</option>
              </select>
            </div>
            <.form_actions />
          </div>
        </form>
      <% "explanation" -> %>
         <% content = @element["content"] || @element[:content] || "" %>
         <% note_type = @element["note_type"] || @element[:note_type] || "info" %>
        <form phx-submit="save_decoration_element" phx-value-id={@element["id"] || @element[:id]}>
          <div class="space-y-3">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">说明内容</label>
              <textarea name="content" rows="4" class="block w-full px-3 py-2 bg-white border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm"><%= content %></textarea>
              <p class="mt-1 text-xs text-gray-500">支持基本的HTML标签</p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">提示类型</label>
              <select name="note_type" class="block w-full px-3 py-2 bg-white border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm">
                <option value="info" selected={note_type == "info"}>信息 (蓝色)</option>
                <option value="tip" selected={note_type == "tip"}>提示 (绿色)</option>
                <option value="warning" selected={note_type == "warning"}>警告 (黄色)</option>
              </select>
            </div>
            <.form_actions />
          </div>
        </form>
      <% "header_image" -> %>
        <% image_url = @element["image_url"] || @element[:image_url] || "" %>
        <% height = @element["height"] || @element[:height] || "200px" %>
        <form phx-submit="save_decoration_element" phx-value-id={@element["id"] || @element[:id]}>
          <div class="space-y-3">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">图片URL</label>
              <input type="url" name="image_url" value={image_url} required class="block w-full px-3 py-2 bg-white border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm" />
              <p class="mt-1 text-xs text-gray-500">输入完整的图片URL地址</p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">高度</label>
              <input type="text" name="height" value={height} pattern="^(\d+)(px|rem|em|vh|%)$" title="e.g. 200px, 15rem, 50vh" class="block w-full px-3 py-2 bg-white border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm" />
              <p class="mt-1 text-xs text-gray-500">例如: 200px, 15rem, 50vh</p>
            </div>
            <.form_actions />
          </div>
        </form>
      <% "inline_image" -> %>
         <% image_url = @element["image_url"] || @element[:image_url] || "" %>
         <% caption = @element["caption"] || @element[:caption] || "" %>
         <% width = @element["width"] || @element[:width] || "100%" %>
         <% align = @element["align"] || @element[:align] || "center" %>
        <form phx-submit="save_decoration_element" phx-value-id={@element["id"] || @element[:id]}>
          <div class="space-y-3">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">图片URL</label>
              <input type="url" name="image_url" value={image_url} required class="block w-full px-3 py-2 bg-white border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm" />
              <p class="mt-1 text-xs text-gray-500">输入完整的图片URL地址</p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">图片说明（可选）</label>
              <input type="text" name="caption" value={caption} class="block w-full px-3 py-2 bg-white border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm" />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">图片宽度</label>
              <input type="text" name="width" value={width} pattern="^(\d+)(px|rem|em|%)?$" title="e.g. 50%, 300px" class="block w-full px-3 py-2 bg-white border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm" />
              <p class="mt-1 text-xs text-gray-500">例如: 50%, 300px</p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">对齐方式</label>
              <select name="align" class="block w-full px-3 py-2 bg-white border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm">
                <option value="left" selected={align == "left"}>左对齐</option>
                <option value="center" selected={align == "center"}>居中</option>
                <option value="right" selected={align == "right"}>右对齐</option>
              </select>
            </div>
            <.form_actions />
          </div>
        </form>
      <% "spacer" -> %>
        <% height = @element["height"] || @element[:height] || "1rem" %>
        <form phx-submit="save_decoration_element" phx-value-id={@element["id"] || @element[:id]}>
          <div class="space-y-3">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">空间高度</label>
              <input type="text" name="height" value={height} required pattern="^(\d+(\.\d+)?)(px|rem|em|vh)$" title="e.g. 1rem, 20px, 5vh" class="block w-full px-3 py-2 bg-white border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm" />
              <p class="mt-1 text-xs text-gray-500">例如: 1rem, 20px, 5vh</p>
            </div>
            <.form_actions />
          </div>
        </form>
      <% _ -> %>
        <div class="text-gray-500 p-4">无法编辑未知类型的元素</div>
    <% end %>
    """
  end

  # Helper component for form actions
  defp form_actions(assigns) do
    ~H"""
    <div class="pt-3 flex justify-end space-x-2">
      <button
        type="button"
        phx-click="close_decoration_editor"
        class="bg-white py-2 px-4 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
      >
        取消
      </button>
      <button
        type="submit"
        class="py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
      >
        保存
      </button>
    </div>
    """
  end
end
