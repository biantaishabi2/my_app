defmodule MyAppWeb.PublicFormLive.Success do
  use MyAppWeb, :live_view
  alias MyApp.Forms
  
  require Logger

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case get_published_form(id) do
      {:ok, form} ->
        # 初始化通知组件状态
        socket =
          socket
          |> assign(:notification, nil)
          |> assign(:notification_type, nil) 
          |> assign(:notification_timer, nil)
          |> assign(:page_title, "#{form.title} - 提交成功")
          |> assign(:form, form)

        # 发送成功通知
        socket = MyAppWeb.NotificationComponent.notify(socket, "表单已成功提交！", :info)

        {:ok, socket}

      {:error, reason} ->
        Logger.error("Error loading public form: #{inspect(reason)}")
        {:ok,
         socket
         |> put_flash(:error, "无法加载表单")
         |> push_navigate(to: ~p"/")}
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
  
  # 获取已发布的表单（仅已发布的表单）
  defp get_published_form(id) do
    case Forms.get_form(id) do
      nil -> {:error, :not_found}
      %Forms.Form{status: :published} = form -> {:ok, form}
      _ -> {:error, :not_published}
    end
  end
end