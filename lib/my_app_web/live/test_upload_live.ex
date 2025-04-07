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
    <div class="container mx-auto p-6">
      <div class="max-w-3xl mx-auto bg-white rounded-lg shadow-lg overflow-hidden">
        <div class="px-6 py-4 border-b border-gray-200">
          <h1 class="text-2xl font-bold">文件上传</h1>
          <%= if @form_id && @field_id do %>
            <p class="mt-2 text-gray-600">为表单字段上传文件</p>
          <% else %>
            <p class="mt-2 text-gray-600">测试文件上传功能</p>
          <% end %>
        </div>
        
        <div class="p-6" phx-drop-target={@uploads.avatar.ref}>
          <.form
            for={%{}}
            id="upload-form"
            phx-submit="save"
            phx-change="validate"
          >
            <div class="space-y-6">
              <div>
                <div class="flex flex-col md:flex-row md:items-end gap-4 mb-6">
                  <div class="flex-1">
                    <.label class="block text-sm font-medium mb-1">选择文件</.label>
                    <div class="mt-2">
                      <.live_file_input upload={@uploads.avatar} class="w-full text-sm text-slate-500
                        file:mr-4 file:py-2 file:px-4
                        file:rounded-md file:border-0
                        file:text-sm file:font-medium
                        file:bg-indigo-50 file:text-indigo-700
                        hover:file:bg-indigo-100" />
                    </div>
                  </div>
                  <div class="md:mb-2">
                    <.button type="submit" class="w-full md:w-auto px-4 py-2 bg-indigo-600 text-white rounded hover:bg-indigo-700">
                      <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2 inline" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
                      </svg>
                      上传文件
                    </.button>
                  </div>
                </div>
                
                <div class="text-xs text-gray-500 flex flex-col md:flex-row gap-2 md:gap-6 mb-2">
                  <div>
                    支持格式: JPG, JPEG, PNG, GIF, MP4, MOV, WEBP
                  </div>
                  <div>
                    单个文件最大 10MB
                  </div>
                  <div>
                    最多上传 5 个文件
                  </div>
                </div>
              </div>

              <div :if={@uploads.avatar.entries != []}>
                <div class="border-t border-gray-200 pt-4 mb-2">
                  <h3 class="text-lg font-medium">待上传的文件</h3>
                  <p class="text-sm text-gray-500">点击上传按钮保存这些文件</p>
                </div>
                <div :for={entry <- @uploads.avatar.entries} class="mt-2 bg-gray-50 rounded-lg p-3 shadow-sm">
                  <div class="flex items-center gap-4">
                    <div class="w-16 h-16 bg-white rounded shadow-inner overflow-hidden flex items-center justify-center">
                      <.live_img_preview entry={entry} width={64} />
                    </div>
                    <div class="flex-1 min-w-0">
                      <div class="text-sm font-medium truncate"><%= entry.client_name %></div>
                      <div class="text-xs text-gray-600 flex gap-3 items-center">
                        <span><%= entry.client_type %></span>
                        <span><%= format_bytes(entry.client_size) %></span>
                        <div :if={entry.progress < 100} class="flex-1 bg-gray-200 rounded-full h-2 overflow-hidden">
                          <div class="bg-indigo-600 h-full" style={"width: #{entry.progress}%"}></div>
                        </div>
                        <span :if={entry.progress < 100} class="text-xs text-indigo-600 whitespace-nowrap">
                          <%= entry.progress %>%
                        </span>
                        <span :if={entry.progress == 100} class="text-xs text-green-600 whitespace-nowrap">
                          上传准备就绪
                        </span>
                      </div>
                    </div>
                    <button type="button" phx-click="cancel-upload" phx-value-ref={entry.ref} 
                      class="p-1 rounded-full hover:bg-gray-200 text-gray-500 hover:text-red-500 transition">
                      <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                      </svg>
                    </button>
                  </div>

                  <div :for={err <- upload_errors(@uploads.avatar, entry)} class="text-red-500 text-xs mt-1">
                    <%= error_to_string(err) %>
                  </div>
                </div>
              </div>

              <div :if={@uploads.avatar.errors != []}>
                <div class="bg-red-50 border-l-4 border-red-500 p-4 rounded">
                  <div class="flex">
                    <div class="flex-shrink-0">
                      <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-red-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                      </svg>
                    </div>
                    <div class="ml-3">
                      <h3 class="text-sm font-medium text-red-700">上传错误</h3>
                      <div class="mt-1 text-xs text-red-600">
                        <ul class="list-disc list-inside">
                          <%= for err <- upload_errors(@uploads.avatar) do %>
                            <li><%= error_to_string(err) %></li>
                          <% end %>
                        </ul>
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              <div :if={@uploaded_files != []}>
                <div class="border-t border-gray-200 pt-4 mb-2">
                  <h3 class="text-lg font-medium">已上传的文件</h3>
                  <p class="text-sm text-gray-500">这些文件已成功上传保存</p>
                </div>
                
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <%= for file_info <- @uploaded_files do %>
                    <div class="bg-white border rounded-lg p-3 shadow-sm hover:shadow-md transition">
                      <div class="flex gap-3">
                        <div class="w-14 h-14 bg-gray-100 rounded shadow-inner overflow-hidden flex items-center justify-center">
                          <%= if String.ends_with?(file_info.path, ~w(.jpg .jpeg .png .gif .webp)) do %>
                            <img src={file_info.path} class="max-w-full max-h-full object-contain" />
                          <% else %>
                            <div class="w-full h-full flex items-center justify-center bg-gray-200">
                              <div class="text-xs text-center font-semibold"><%= Path.extname(file_info.original_filename) %></div>
                            </div>
                          <% end %>
                        </div>
                        <div class="flex-1 min-w-0">
                          <div class="text-sm font-medium truncate"><%= file_info.original_filename %></div>
                          <div class="text-xs text-gray-500 truncate">
                            <%= file_info.type %> | <%= format_bytes(file_info.size) %>
                          </div>
                          <a href={file_info.path} target="_blank" class="text-xs text-indigo-600 hover:text-indigo-800 hover:underline inline-flex items-center mt-1">
                            查看文件
                            <svg xmlns="http://www.w3.org/2000/svg" class="h-3 w-3 ml-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                            </svg>
                          </a>
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>
                
                <div class="mt-6 text-center bg-indigo-50 border border-indigo-100 rounded-lg p-3">
                  <p class="text-indigo-800 text-sm">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 inline-block mr-1 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                    上传成功后，文件将与表单回答关联。点击"返回表单"按钮继续填写表单。
                  </p>
                </div>
              </div>

              <div class="mt-10 border-t border-gray-200 pt-4 flex justify-end">
                <.button type="button" phx-click="return" class="px-4 py-2 bg-gray-600 text-white rounded hover:bg-gray-700">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 inline-block mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 17l-5-5m0 0l5-5m-5 5h12" />
                  </svg>
                  返回表单
                </.button>
              </div>
            </div>
          </.form>
        </div>
      </div>
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