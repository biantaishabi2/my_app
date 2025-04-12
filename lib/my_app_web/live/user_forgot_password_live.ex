defmodule MyAppWeb.UserForgotPasswordLive do
  use MyAppWeb, :live_view

  alias MyApp.Accounts

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{}, as: "user"), page_title: "忘记密码")}
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        忘记密码？
        <:subtitle>我们将发送重置密码链接到您的邮箱</:subtitle>
      </.header>

      <.simple_form for={@form} id="reset_password_form" phx-submit="send_email">
        <.input field={@form[:email]} type="email" placeholder="邮箱" required />
        <:actions>
          <.button phx-disable-with="发送中..." class="w-full">
            发送密码重置指引
          </.button>
        </:actions>
      </.simple_form>
      <p class="text-center text-sm mt-4">
        <.link href={~p"/users/register"}>注册</.link> | <.link href={~p"/users/log_in"}>登录</.link>
      </p>
    </div>
    """
  end

  def handle_event("send_email", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_reset_password_instructions(
        user,
        &url(~p"/users/reset_password/#{&1}")
      )
    end

    info =
      "如果您的邮箱在我们的系统中，您将很快收到重置密码的指引。"

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> redirect(to: ~p"/")}
  end
end
