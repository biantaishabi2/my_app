defmodule MyAppWeb.NotificationComponent do
  @moduledoc """
  一个独立的通知组件，用于显示成功、错误等消息。

  使用方法：
  1. 在LiveView mount中初始化:
     socket = assign(socket, :notification, nil)
     socket = assign(socket, :notification_type, nil)
     socket = assign(socket, :notification_timer, nil)

  2. 在模板中渲染组件:
     <.live_component module={MyAppWeb.NotificationComponent} id="notification"
       notification={@notification}
       notification_type={@notification_type} />

  3. 在事件处理函数中发送通知:
     socket = MyAppWeb.NotificationComponent.notify(socket, "操作成功", :info)
  """
  use Phoenix.LiveComponent

  @default_timeout 3000

  @doc """
  显示通知消息

  ## 参数
    - socket: LiveView socket
    - message: 要显示的消息
    - type: 消息类型 (:info 或 :error)
    - timeout: 自动消失时间（毫秒），默认3000ms

  ## 返回值
    更新后的socket
  """
  def notify(socket, message, type, timeout \\ @default_timeout) do
    # 取消之前的定时器
    if socket.assigns[:notification_timer] do
      Process.cancel_timer(socket.assigns.notification_timer)
    end

    # 使用send_update发送消息到组件自身
    timer_ref =
      Process.send_after(
        self(),
        :clear_notification,
        timeout
      )

    socket
    |> assign(:notification, message)
    |> assign(:notification_type, type)
    |> assign(:notification_timer, timer_ref)
  end

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def handle_event("close_notification", _params, socket) do
    # 手动关闭通知
    if socket.assigns[:notification_timer] do
      Process.cancel_timer(socket.assigns.notification_timer)
    end

    {:noreply,
     socket
     |> assign(:notification, nil)
     |> assign(:notification_timer, nil)}
  end

  # handle_info不是LiveComponent的标准回调，移除@impl标记
  def handle_info(:clear_notification, socket) do
    {:noreply,
     socket
     |> assign(:notification, nil)
     |> assign(:notification_timer, nil)}
  end

  # 添加对新消息格式的处理
  def handle_info({:clear_notification, _id}, socket) do
    {:noreply,
     socket
     |> assign(:notification, nil)
     |> assign(:notification_timer, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <%= if @notification do %>
        <div
          id="notification-component"
          phx-click="close_notification"
          phx-target={@myself}
          style="position: fixed; top: 20px; left: 50%; transform: translateX(-50%); z-index: 9999; width: 80%; max-width: 600px; cursor: pointer;"
        >
          <%= if @notification_type == :info do %>
            <div
              style="background-color: #d1fae5; border-left: 4px solid #10b981; color: #065f46; padding: 16px; margin-bottom: 16px; border-radius: 4px; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);"
              role="alert"
            >
              <div style="display: flex; justify-content: space-between; align-items: center;">
                <p style="margin: 0; font-weight: 500;">{@notification}</p>
                <span style="font-size: 18px; font-weight: bold;">×</span>
              </div>
            </div>
          <% end %>

          <%= if @notification_type == :error do %>
            <div
              style="background-color: #fee2e2; border-left: 4px solid #ef4444; color: #7f1d1d; padding: 16px; margin-bottom: 16px; border-radius: 4px; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);"
              role="alert"
            >
              <div style="display: flex; justify-content: space-between; align-items: center;">
                <p style="margin: 0; font-weight: 500;">{@notification}</p>
                <span style="font-size: 18px; font-weight: bold;">×</span>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
end
