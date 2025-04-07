defmodule MyAppWeb.TestUploadLive do
  use MyAppWeb, :live_view
  require Logger

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:uploaded_files, [])
     |> allow_upload(:avatar, 
       accept: ~w(.jpg .jpeg .png .gif .mp4 .mov .webp),
       max_entries: 2,
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
    
    uploaded_files =
      consume_uploaded_entries(socket, :avatar, fn %{path: path}, entry ->
        Logger.info("Processing file: #{entry.client_name}")
        dest = Path.join([:code.priv_dir(:my_app), "static", "uploads", Path.basename(path)])
        File.cp!(path, dest)
        {:ok, ~p"/uploads/#{Path.basename(dest)}"}
      end)

    {:noreply, update(socket, :uploaded_files, &(&1 ++ uploaded_files))}
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
      <.form
        for={%{}}
        id="upload-form"
        phx-submit="save"
        phx-change="validate"
      >
        <div class="space-y-6">
          <div>
            <.label>Upload Avatar</.label>
            <div class="mt-2">
              <.live_file_input upload={@uploads.avatar} />
            </div>
          </div>

          <div :if={@uploads.avatar.entries != []}>
            <h3>Selected Files:</h3>
            <div :for={entry <- @uploads.avatar.entries} class="mt-2">
              <div class="flex items-center gap-4">
                <.live_img_preview entry={entry} width={60} />
                <div>
                  <div><%= entry.client_name %></div>
                  <div class="text-sm text-gray-600">
                    <%= entry.client_type %> - <%= entry.client_size %> bytes
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
            <h3>Uploaded Files:</h3>
            <div :for={url <- @uploaded_files} class="mt-2">
              <img src={url} width="60" />
            </div>
          </div>

          <div>
            <.button type="submit">Save</.button>
          </div>
        </div>
      </.form>
    </div>
    """
  end

  defp error_to_string(:too_large), do: "Too large"
  defp error_to_string(:too_many_files), do: "Too many files"
  defp error_to_string(:not_accepted), do: "You have selected an unacceptable file type"
end 