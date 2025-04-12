defmodule MyAppWeb.UserConfirmationInstructionsLive do
  use MyAppWeb, :live_view

  alias MyApp.Accounts

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{}, as: "user"), page_title: "重发确认邮件")}
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        未收到确认说明？
        <:subtitle>我们将发送新的确认链接到您的邮箱</:subtitle>
      </.header>

      <.simple_form for={@form} id="resend_confirmation_form" phx-submit="send_instructions">
        <.input field={@form[:email]} type="email" placeholder="邮箱" required />
        <:actions>
          <.button phx-disable-with="发送中..." class="w-full">
            重新发送确认说明
          </.button>
        </:actions>
      </.simple_form>

      <p class="text-center mt-4">
        <.link href={~p"/users/register"}>注册</.link> | <.link href={~p"/users/log_in"}>登录</.link>
      </p>
    </div>
    """
  end

  def handle_event("send_instructions", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_confirmation_instructions(
        user,
        &url(~p"/users/confirm/#{&1}")
      )
    end

    info =
      "如果您的邮箱在我们的系统中且尚未确认，您将很快收到一封包含确认说明的邮件。"

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> redirect(to: ~p"/")}
  end
end
