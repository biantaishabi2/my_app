defmodule MyAppWeb.FormLive.Show do
  use MyAppWeb, :live_view
  alias MyAppWeb.FormTemplateRenderer

  alias MyApp.Forms

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    current_user = socket.assigns.current_user

    case Forms.get_form(id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "表单不存在")
         |> push_navigate(to: ~p"/forms")}

      form ->
        if form.user_id == current_user.id || form.status == :published do
          # 加载表单模板
          form_template = FormTemplateRenderer.load_form_template(form)

          {:ok,
           socket
           |> assign(:page_title, form.title)
           |> assign(:form, form)
           |> assign(:form_template, form_template)}
        else
          {:ok,
           socket
           |> put_flash(:error, "您没有权限查看此表单")
           |> push_navigate(to: ~p"/forms")}
        end
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end
end
