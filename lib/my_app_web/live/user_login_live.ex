defmodule MyAppWeb.UserLoginLive do
  use MyAppWeb, :live_view

  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "user")
    {:ok, assign(socket, form: form, page_title: "登录"), temporary_assigns: [form: form]}
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        账户登录
        <:subtitle>
          还没有账户？
          <.link navigate={~p"/users/register"} class="font-semibold text-brand hover:underline">
            立即注册
          </.link>
          一个新账户。
        </:subtitle>
      </.header>

      <.simple_form for={@form} id="login_form" action={~p"/users/log_in"} phx-update="ignore">
        <.input field={@form[:email]} type="email" label="邮箱" required />
        <.input field={@form[:password]} type="password" label="密码" required />

        <:actions>
          <.input field={@form[:remember_me]} type="checkbox" label="保持登录状态" />
          <.link href={~p"/users/reset_password"} class="text-sm font-semibold">
            忘记密码？
          </.link>
        </:actions>
        <:actions>
          <.button phx-disable-with="登录中..." class="w-full">
            登录 <span aria-hidden="true">→</span>
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end
end
