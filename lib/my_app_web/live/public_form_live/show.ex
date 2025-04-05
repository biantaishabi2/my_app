defmodule MyAppWeb.PublicFormLive.Show do
  use MyAppWeb, :live_view

  alias MyApp.Forms
  alias MyApp.Forms.Form

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    # 获取表单（仅加载已发布的表单）
    case get_published_form(id) do
      {:ok, form} ->
        socket =
          socket
          |> assign(:page_title, form.title)
          |> assign(:form, form)
        {:ok, socket}

      {:error, :not_found} ->
        {:ok, 
          socket
          |> put_flash(:error, "表单不存在或未发布")
          |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :show, _params) do
    socket
    |> assign(:page_title, "查看表单 - #{socket.assigns.form.title}")
  end

  # 获取已发布的表单及其表单项和选项
  defp get_published_form(id) do
    case Forms.get_form(id) do
      nil -> 
        {:error, :not_found}
      %Form{status: :published} = form -> 
        # 预加载表单项和选项（已包含页面加载）
        form = Forms.preload_form_items_and_options(form)
        
        {:ok, form}
      %Form{} -> 
        {:error, :not_found}
    end
  end
end