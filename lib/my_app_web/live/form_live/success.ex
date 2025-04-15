defmodule MyAppWeb.FormLive.Success do
  use MyAppWeb, :live_view
  alias MyApp.Forms

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Forms.get_form(id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "表单不存在")
         |> push_navigate(to: ~p"/forms")}

      form ->
        # 初始化通知组件状态
        socket =
          socket
          |> assign(:notification, nil)
          |> assign(:notification_type, nil) 
          |> assign(:notification_timer, nil)
          |> assign(:page_title, "#{form.title} - 提交成功")
          |> assign(:form, form)

        # 发送成功通知
        socket = MyAppWeb.NotificationComponent.notify(socket, "表单提交成功！", :info)

        {:ok, socket}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(:clear_notification, socket) do
    {:noreply,
     socket
     |> assign(:notification, nil)
     |> assign(:notification_timer, nil)}
  end
end