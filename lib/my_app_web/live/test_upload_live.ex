defmodule MyAppWeb.TestUploadLive do
  use MyAppWeb, :live_view
  require Logger

  @impl Phoenix.LiveView
  def mount(params, _session, socket) do
    form_id = params["form_id"]
    field_id = params["field_id"]
    
    Logger.info("Mounting TestUploadLive with form_id: #{inspect(form_id)}, field_id: #{inspect(field_id)}")
    
    {:ok,
     socket
     |> assign(:uploaded_files, [])
     |> assign(:form_id, form_id)
     |> assign(:field_id, field_id)
     |> assign(:return_to, Map.get(params, "return_to", "/"))
     |> allow_upload(:avatar, 
       accept: ~w(.jpg .jpeg .png .gif .mp4 .mov .webp),
       max_entries: 5,
       max_file_size: 10_000_000,
       chunk_size: 64_000,
       progress: &handle_progress/3
     )}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", params, socket) do
    Logger.info("Validating upload: #{inspect(params)}")
    
    # 只返回 socket，让 LiveView 自动处理验证
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    Logger.info("Canceling upload for ref: #{ref}")
    {:noreply, cancel_upload(socket, :avatar, ref)}
  end

  @impl Phoenix.LiveView
  def handle_event("save", params, socket) do
    Logger.info("Saving upload: #{inspect(params)}")
    
    form_id = socket.assigns.form_id
    field_id = socket.assigns.field_id
    
    # 构建保存目录（包含表单和字段ID）
    upload_dir = if form_id && field_id do
      Path.join(["uploads", form_id, field_id])
    else
      "uploads"
    end
    
    # 确保目录存在
    full_upload_dir = Path.join([:code.priv_dir(:my_app), "static", upload_dir])
    File.mkdir_p!(full_upload_dir)
    
    uploaded_files =
      consume_uploaded_entries(socket, :avatar, fn %{path: path}, entry ->
        Logger.info("Processing file: #{entry.client_name}")
        
        # 生成唯一文件名
        ext = Path.extname(entry.client_name)
        filename = "#{Ecto.UUID.generate()}#{ext}"
        dest = Path.join(full_upload_dir, filename)
        
        # 复制文件
        File.cp!(path, dest)
        
        # 返回文件信息和URL
        file_url = Path.join(["/", upload_dir, filename])
        file_info = %{
          original_filename: entry.client_name,
          filename: filename,
          size: entry.client_size,
          type: entry.client_type,
          path: file_url
        }
        
        {:ok, file_info}
      end)

    {:noreply, 
      socket
      |> update(:uploaded_files, &(&1 ++ uploaded_files))
      |> put_flash(:info, "文件上传成功！")}
  end

  @impl Phoenix.LiveView
  def handle_event("return", _params, socket) do
    return_url = socket.assigns.return_to
    form_id = socket.assigns.form_id
    
    # 如果有表单ID，构建返回到表单提交页的URL
    submit_url = if form_id do
      "/forms/#{form_id}/submit"
    else
      return_url
    end
    
    {:noreply, push_navigate(socket, to: submit_url)}
  end

  defp handle_progress(:avatar, entry, socket) do
    if entry.done? do
      Logger.info("Upload completed for #{entry.client_name}")
    else
      Logger.info("Upload progress for #{entry.client_name}: #{entry.progress}%")
    end
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-2xl py-8" phx-drop-target={@uploads.avatar.ref}>
      <div class="mb-6">
        <h1 class="text-xl font-bold mb-2">文件上传</h1>
        <%= if @form_id && @field_id do %>
          <p class="text-gray-600">为表单 <%= @form_id %> 的字段 <%= @field_id %> 上传文件</p>
        <% else %>
          <p class="text-gray-600">测试文件上传功能</p>
        <% end %>
      </div>
      
      <.form
        for={%{}}
        id="upload-form"
        phx-submit="save"
        phx-change="validate"
      >
        <div class="space-y-6">
          <div>
            <.label>选择文件</.label>
            <div class="mt-2">
              <.live_file_input upload={@uploads.avatar} />
            </div>
          </div>

          <div :if={@uploads.avatar.entries != []}>
            <h3 class="text-lg font-medium">已选择的文件:</h3>
            <div :for={entry <- @uploads.avatar.entries} class="mt-2">
              <div class="flex items-center gap-4">
                <.live_img_preview entry={entry} width={60} />
                <div>
                  <div><%= entry.client_name %></div>
                  <div class="text-sm text-gray-600">
                    <%= entry.client_type %> - <%= format_bytes(entry.client_size) %>
                  </div>
                  <div :if={entry.progress < 100} class="text-sm text-blue-600">
                    <%= entry.progress %>%
                  </div>
                  <div :if={entry.progress == 100} class="text-sm text-green-600">
                    Ready
                  </div>
                </div>
                <button type="button" phx-click="cancel-upload" phx-value-ref={entry.ref} class="text-red-500">
                  &times;
                </button>
              </div>

              <div :for={err <- upload_errors(@uploads.avatar, entry)} class="text-red-500 text-sm mt-1">
                <%= error_to_string(err) %>
              </div>
            </div>
          </div>

          <div :if={@uploads.avatar.errors != []}>
            <div :for={err <- upload_errors(@uploads.avatar)} class="text-red-500 text-sm mt-1">
              <%= error_to_string(err) %>
            </div>
          </div>

          <div :if={@uploaded_files != []}>
            <h3 class="text-lg font-medium mt-6">已上传的文件:</h3>
            <div :for={file_info <- @uploaded_files} class="mt-2 border p-3 rounded">
              <div class="flex items-start gap-4">
                <%= if String.ends_with?(file_info.path, ~w(.jpg .jpeg .png .gif .webp)) do %>
                  <img src={file_info.path} width="60" />
                <% else %>
                  <div class="w-[60px] h-[60px] bg-gray-200 flex items-center justify-center">
                    <div class="text-xs text-center"><%= Path.extname(file_info.original_filename) %></div>
                  </div>
                <% end %>
                <div>
                  <div><%= file_info.original_filename %></div>
                  <div class="text-sm text-gray-600">
                    <%= file_info.type %> - <%= format_bytes(file_info.size) %>
                  </div>
                  <div class="text-sm break-all mt-1">
                    <a href={file_info.path} target="_blank" class="text-blue-600 hover:underline">
                      <%= file_info.path %>
                    </a>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div class="flex gap-4">
            <.button type="submit">上传文件</.button>
            <.button type="button" phx-click="return" class="bg-gray-500">返回表单</.button>
          </div>
        </div>
      </.form>
    </div>
    """
  end

  # 格式化文件大小显示
  defp format_bytes(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_000_000 ->
        "#{Float.round(bytes / 1_000_000, 1)} MB"
      bytes >= 1_000 ->
        "#{Float.round(bytes / 1_000, 1)} KB"
      true ->
        "#{bytes} B"
    end
  end
  defp format_bytes(_), do: "Unknown size"

  defp error_to_string(:too_large), do: "文件过大"
  defp error_to_string(:too_many_files), do: "文件数量超过限制"
  defp error_to_string(:not_accepted), do: "不支持的文件类型"
end 