defmodule MyAppWeb.FlashTestLive do
  use MyAppWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_event("test_flash_info", _params, socket) do
    {:noreply, put_flash(socket, :info, "这是一条测试信息消息")}
  end

  @impl true
  def handle_event("test_flash_error", _params, socket) do
    {:noreply, put_flash(socket, :error, "这是一条测试错误消息")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-4">
      <h1 class="text-2xl font-bold mb-4">Flash消息测试页面</h1>

      <div class="flex space-x-4 mb-4">
        <button
          phx-click="test_flash_info"
          class="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"
        >
          测试成功消息
        </button>

        <button
          phx-click="test_flash_error"
          class="px-4 py-2 bg-red-500 text-white rounded hover:bg-red-600"
        >
          测试错误消息
        </button>
      </div>

      <div class="mt-8 p-4 bg-gray-100 rounded">
        <h2 class="text-lg font-semibold mb-2">调试信息</h2>
        <pre class="bg-gray-200 p-2 rounded"><%= inspect(@flash, pretty: true) %></pre>
      </div>
    </div>
    """
  end
end
