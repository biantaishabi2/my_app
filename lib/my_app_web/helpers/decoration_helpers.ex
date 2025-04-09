defmodule MyAppWeb.DecorationHelpers do
  @moduledoc """
  Helper functions for rendering decoration elements.
  """
  use Phoenix.Component
  # Import LiveView specific components if not already via MyAppWeb
  import Phoenix.LiveView.Helpers
  import MyAppWeb.FormComponents
  import MyAppWeb.CoreComponents

  # Needed for format_bytes
  import Number.Delimit

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

  # Determines if the image source is an uploaded file path.
  defp is_uploaded_image?(src) when is_binary(src) do
    String.starts_with?(src, "/uploads/") # Or adjust based on your actual upload path prefix
  end
  defp is_uploaded_image?(_), do: false

  @doc """
  Renders a preview of a decoration element.
  Handles both URL and uploaded images.
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
        <% image_src = @element["image_url"] || @element[:image_url] || "" %>
        <% height = @element["height"] || @element[:height] || "200px" %>
        <div>
          <%= if image_src != "" do %>
            <img src={image_src} alt="题图" style={"height: #{height}; width: 100%; object-fit: cover; border-radius: 0.25rem;"} />
          <% else %>
            <div style={"height: #{height}; width: 100%; background-color: #f3f4f6; display: flex; align-items: center; justify-content: center; border-radius: 0.25rem;"}>
              <span class="text-gray-400">请设置图片URL或上传图片</span>
            </div>
          <% end %>
        </div>
      <% "inline_image" -> %>
        <% image_src = @element["image_url"] || @element[:image_url] || "" %>
        <% caption = @element["caption"] || @element[:caption] || "" %>
        <% width = @element["width"] || @element[:width] || "100%" %>
        <% align = @element["align"] || @element[:align] || "center" %>
        <div style={"text-align: #{align};"}>
          <%= if image_src != "" do %>
            <img src={image_src} alt={caption} style={"width: #{width}; max-width: 100%; border-radius: 0.25rem; margin-left: auto; margin-right: auto;"} />
          <% else %>
            <div style={"width: #{width}; max-width: 100%; margin: 0 auto; height: 150px; background-color: #f3f4f6; display: flex; align-items: center; justify-content: center; border-radius: 0.25rem;"}>
              <span class="text-gray-400">请设置图片URL或上传图片</span>
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
  Renders the editor interface for a specific decoration element.
  """
  attr :element, :map, required: true, doc: "The decoration element map."
  # Allow uploads to be nil or empty list
  attr :uploads, :list, default: [], doc: "List of upload entries for the element."
  # Allow config name to be nil
  attr :upload_config_name, :atom, default: nil, doc: "The dynamic upload config name."
  attr :myself, :any, required: true, doc: "The LiveView pid or component id for phx-target."

  def render_decoration_editor(assigns) do
    # Directly use passed attributes
    element = assigns.element
    uploads = assigns.uploads # Already defaulted to [] if not provided
    upload_config_name = assigns.upload_config_name # Already defaulted to nil
    myself = assigns.myself

    element_type = element["type"] || element[:type] # Handle both string and atom keys
    element_id = element["id"] || element[:id]

    # Create a form specific to this decoration element
    # Use the element itself as the source for the form
    form = Phoenix.HTML.FormData.to_form(element, as: "decoration")

    ~H"""
    <div class="space-y-4 border p-4 rounded-md bg-gray-50">
      <.form :let={f} for={form} phx-change="validate_decoration_element" phx-submit="save_decoration_element" phx-value-id={element_id} phx-target={myself}>
        <input type="hidden" name="id" value={element_id} />

        <%= case element_type do %>
          <% "title" -> %>
            <h2 class="text-lg font-semibold mb-2">编辑标题</h2>
            <.input field={{f, :title}} type="text" label="标题内容" value={element["title"] || element[:title]}/>
            <.input field={{f, :level}} type="select" label="标题级别" options={[{"H1", 1}, {"H2", 2}, {"H3", 3}, {"H4", 4}, {"H5", 5}, {"H6", 6}]} value={to_string(element["level"] || element[:level] || 2)} />
            <.input field={{f, :align}} type="select" label="对齐方式" options={[{"左对齐", "left"}, {"居中", "center"}, {"右对齐", "right"}]} value={element["align"] || element[:align] || "left"} />
          <% "paragraph" -> %>
            <h2 class="text-lg font-semibold mb-2">编辑段落</h2>
            <.input field={{f, :content}} type="textarea" label="段落内容" value={element["content"] || element[:content]}/>
          <% "section" -> %>
            <h2 class="text-lg font-semibold mb-2">编辑章节分隔</h2>
            <.input field={{f, :title}} type="text" label="章节标题（可选）" value={element["title"] || element[:title]} />
            <.input field={{f, :divider_style}} type="select" label="分隔线样式" options={[{"实线", "solid"}, {"虚线", "dashed"}, {"点状线", "dotted"}, {"无分隔线", "none"}]} value={element["divider_style"] || element[:divider_style] || "solid"} />
          <% "explanation" -> %>
            <h2 class="text-lg font-semibold mb-2">编辑说明框</h2>
            <.input field={{f, :content}} type="textarea" label="说明内容" value={element["content"] || element[:content]} />
            <.input field={{f, :note_type}} type="select" label="提示类型" options={[{"信息", "info"}, {"成功", "success"}, {"警告", "warning"}, {"危险", "danger"}]} value={element["note_type"] || element[:note_type] || "info"} />
          <% "header_image" -> %>
            <h2 class="text-lg font-semibold mb-2">编辑页眉图片</h2>
            <.input field={{f, :height}} type="text" label="图片高度 (e.g., 300px, 20rem)" value={element["height"] || element[:height] || "300px"} />
            <.input field={{f, :image_url}} type="text" label="图片URL (或点击下方按钮上传)" value={element["image_url"] || element[:image_url]} />

            <%# Button to initiate the upload process %>
            <.button type="button" phx-click="initiate_decoration_upload" phx-value-id={element_id} phx-target={myself} class="btn-secondary btn-sm mt-2">
              上传新图片
            </.button>

            <%# Display file input and progress only if upload is initiated (upload_config_name is set) %>
            <%= if upload_config_name do %>
              <div class="mt-4 border-t pt-4">
                <h3 class="text-md font-medium mb-2">上传新图片</h3>
                <.live_file_input upload={assigns.uploads[upload_config_name]} class="mt-2"/>
                <div class="mt-2 space-y-1">
                  <%= for entry <- assigns.uploads[upload_config_name].entries do %>
                    <div class="flex items-center justify-between p-2 border rounded"><span class="text-sm font-medium"><%= entry.client_name %> (<%= format_bytes(entry.client_size) %>)</span><button type="button" phx-click="cancel_decoration_upload" phx-value-ref={entry.ref} phx-value-config_name={Atom.to_string(upload_config_name)} phx-target={myself} aria-label="取消上传" class="text-red-500 hover:text-red-700">&times;</button></div>
                    <progress value={entry.progress} max="100" class="w-full h-2"></progress>
                  <% end %>
                </div>
                <%= for err <- Phoenix.Component.upload_errors(assigns.uploads[upload_config_name]) do %>
                  <p class="alert alert-danger"><%= error_to_string(err) %></p>
                <% end %>
                <%# Button to apply the uploaded image %>
                <.button type="button" phx-click="apply_decoration_upload" phx-value-id={element_id} phx-target={myself} class="btn-primary btn-sm mt-2" disabled={Enum.empty?(assigns.uploads[upload_config_name].entries)}>
                  应用上传的图片
                </.button>
              </div>
            <% else %>
              <p class="text-sm text-gray-500 mt-2">点击 "上传新图片" 按钮以选择文件。</p>
            <% end %>
          <% "inline_image" -> %>
            <h2 class="text-lg font-semibold mb-2">编辑行内图片</h2>
            <.input field={{f, :caption}} type="text" label="图片说明（可选）" value={element["caption"] || element[:caption]} />
            <.input field={{f, :width}} type="text" label="图片宽度 (e.g., 80%, 200px)" value={element["width"] || element[:width] || "100%"} />
            <.input field={{f, :align}} type="select" label="对齐方式" options={[{"左对齐", "left"}, {"居中", "center"}, {"右对齐", "right"}]} value={element["align"] || element[:align] || "center"} />
            <.input field={{f, :image_url}} type="text" label="图片URL (或点击下方按钮上传)" value={element["image_url"] || element[:image_url]} />

            <%# Button to initiate the upload process %>
            <.button type="button" phx-click="initiate_decoration_upload" phx-value-id={element_id} phx-target={myself} class="btn-secondary btn-sm mt-2">
              上传新图片
            </.button>

            <%# Display file input and progress only if upload is initiated (upload_config_name is set) %>
            <%= if upload_config_name do %>
              <div class="mt-4 border-t pt-4">
                <h3 class="text-md font-medium mb-2">上传新图片</h3>
                <.live_file_input upload={assigns.uploads[upload_config_name]} class="mt-2"/>
                <div class="mt-2 space-y-1">
                  <%= for entry <- assigns.uploads[upload_config_name].entries do %>
                    <div class="flex items-center justify-between p-2 border rounded"><span class="text-sm font-medium"><%= entry.client_name %> (<%= format_bytes(entry.client_size) %>)</span><button type="button" phx-click="cancel_decoration_upload" phx-value-ref={entry.ref} phx-value-config_name={Atom.to_string(upload_config_name)} phx-target={myself} aria-label="取消上传" class="text-red-500 hover:text-red-700">&times;</button></div>
                    <progress value={entry.progress} max="100" class="w-full h-2"></progress>
                  <% end %>
                </div>
                <%= for err <- Phoenix.Component.upload_errors(assigns.uploads[upload_config_name]) do %>
                  <p class="alert alert-danger"><%= error_to_string(err) %></p>
                <% end %>
                <%# Button to apply the uploaded image %>
                <.button type="button" phx-click="apply_decoration_upload" phx-value-id={element_id} phx-target={myself} class="btn-primary btn-sm mt-2" disabled={Enum.empty?(assigns.uploads[upload_config_name].entries)}>
                  应用上传的图片
                </.button>
              </div>
            <% else %>
              <p class="text-sm text-gray-500 mt-2">点击 "上传新图片" 按钮以选择文件。</p>
            <% end %>
          <% "spacer" -> %>
            <h2 class="text-lg font-semibold mb-2">编辑间距</h2>
            <.input field={{f, :height}} type="text" label="间距高度 (e.g., 1rem, 20px)" value={element["height"] || element[:height] || "1rem"} />
          <% _ -> %>
            <p>未知装饰类型：<%= element_type %></p>
        <% end %>

        <div class="flex justify-end space-x-2 mt-4">
          <.button type="button" phx-click="cancel_edit_decoration_element" phx-target={myself} class="btn-secondary">
            取消
          </.button>
          <.button type="submit" class="btn-primary" phx-disable-with="保存中...">
            保存
          </.button>
        </div>
      </.form>
    </div>
    """
  end

  # Helper to extract upload errors for a specific entry
  # Updated to accept upload_config and handle nil
  # Renamed to avoid conflict with Phoenix.Component.upload_errors/2
  # This helper seems redundant now as we can use Phoenix.Component.upload_errors directly.
  # Let's comment it out for now.
  # defp get_upload_errors_for_entry(upload_config, entry) do
  #   if upload_config && upload_config.errors do
  #     upload_config.errors
  #     |> Enum.filter(fn {ref, _error} -> ref == entry.ref end)
  #     |> Enum.map(fn {_ref, error} -> error end)
  #   else
  #     []
  #   end
  # end

  # Helper to convert upload error atoms to strings (similar to FormLive.Edit)
  defp error_to_string(:too_large), do: "文件太大"
  defp error_to_string(:too_many_files), do: "文件数量过多"
  defp error_to_string(:not_accepted), do: "文件类型不被接受"
  defp error_to_string(_), do: "无效的文件"

  # Helper to format bytes into KB/MB
  defp format_bytes(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_048_576 -> # 1 MB
        "#{Float.round(bytes / 1_048_576, 1)} MB"
      bytes >= 1024 -> # 1 KB
        "#{Float.round(bytes / 1024, 1)} KB"
      true ->
        "#{bytes} Bytes"
    end
  end
  defp format_bytes(_), do: "0 Bytes" # Handle non-integer input
end
