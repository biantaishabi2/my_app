defmodule MyAppWeb.UserSettingsLive do
  use MyAppWeb, :live_view

  alias MyApp.Accounts

  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_user, token) do
        :ok ->
          put_flash(socket, :info, "邮箱修改成功。")

        :error ->
          put_flash(socket, :error, "邮箱修改链接无效或已过期。")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    email_changeset = Accounts.change_user_email(user)
    password_changeset = Accounts.change_user_password(user)

    socket =
      socket
      |> assign(:current_password, nil)
      |> assign(:email_form_current_password, nil)
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)
      |> assign(:page_title, "账户设置")

    {:ok, socket}
  end

  def on_mount(:default, _params, _session, socket) do
    socket =
      socket
      |> Phoenix.Component.assign(:extra_body_classes, "is-settings")

    {:cont, socket}
  end

  def render(assigns) do
    ~H"""
    <div id="settings-page" phx-hook="SettingsLayout">
      <div class="md:hidden">
        <!-- 移动版布局：单列 -->
        <.header class="text-center">
          账户设置
          <:subtitle>管理您的账户邮箱地址和密码设置</:subtitle>
        </.header>

        <div class="space-y-8 divide-y settings-forms">
          <div class="settings-section">
            <h3 class="text-lg font-medium mb-4">修改邮箱地址</h3>
            <.simple_form
              for={@email_form}
              id="email_form_mobile"
              phx-submit="update_email"
              phx-change="validate_email"
              class="settings-form"
            >
              <.input field={@email_form[:email]} type="email" label="邮箱" required />
              <.input
                field={@email_form[:current_password]}
                name="current_password"
                id="current_password_for_email_mobile"
                type="password"
                label="当前密码"
                value={@email_form_current_password}
                required
              />
              <:actions>
                <.button phx-disable-with="修改中..." class="w-full">修改邮箱</.button>
              </:actions>
            </.simple_form>
          </div>
          <div class="settings-section pt-8">
            <h3 class="text-lg font-medium mb-4">修改密码</h3>
            <.simple_form
              for={@password_form}
              id="password_form_mobile"
              action={~p"/users/log_in?_action=password_updated"}
              method="post"
              phx-change="validate_password"
              phx-submit="update_password"
              phx-trigger-action={@trigger_submit}
              class="settings-form"
            >
              <input
                name={@password_form[:email].name}
                type="hidden"
                id="hidden_user_email_mobile"
                value={@current_email}
              />
              <.input field={@password_form[:password]} type="password" label="新密码" required />
              <.input
                field={@password_form[:password_confirmation]}
                type="password"
                label="确认新密码"
              />
              <.input
                field={@password_form[:current_password]}
                name="current_password"
                type="password"
                label="当前密码"
                id="current_password_for_password_mobile"
                value={@current_password}
                required
              />
              <:actions>
                <.button phx-disable-with="修改中..." class="w-full">修改密码</.button>
              </:actions>
            </.simple_form>
          </div>
        </div>
      </div>

      <div class="hidden md:block">
        <!-- 桌面版布局：两列 -->
        <div class="desktop-two-column mt-8">
          <div class="desktop-sidebar">
            <div class="desktop-sidebar-title">设置</div>
            <div class="desktop-sidebar-menu">
              <a href="#email" class="active">
                <div class="flex items-center">
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-5 w-5 mr-2"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"
                    />
                  </svg>
                  邮箱设置
                </div>
              </a>
              <a href="#password">
                <div class="flex items-center">
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-5 w-5 mr-2"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"
                    />
                  </svg>
                  密码设置
                </div>
              </a>
              <a href="/chat" class="mt-4">
                <div class="flex items-center">
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-5 w-5 mr-2"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"
                    />
                  </svg>
                  返回聊天
                </div>
              </a>
            </div>
          </div>

          <div class="desktop-main-content">
            <div class="settings-card">
              <.header>
                账户设置
                <:subtitle>管理您的账户邮箱地址和密码设置</:subtitle>
              </.header>

              <div class="settings-inner-content">
                <div class="settings-section mb-8" id="email">
                  <div class="flex items-center mb-3">
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class="h-6 w-6 mr-2 text-indigo-600"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"
                      />
                    </svg>
                    <h3 class="text-xl font-medium">修改邮箱地址</h3>
                  </div>
                  <p class="text-gray-600 mb-4">更新您的邮箱地址，确认后新邮箱将成为您的登录凭证</p>
                  <.simple_form
                    for={@email_form}
                    id="email_form"
                    phx-submit="update_email"
                    phx-change="validate_email"
                    class="settings-form"
                  >
                    <.input field={@email_form[:email]} type="email" label="邮箱" required />
                    <.input
                      field={@email_form[:current_password]}
                      name="current_password"
                      id="current_password_for_email"
                      type="password"
                      label="当前密码"
                      value={@email_form_current_password}
                      required
                    />
                    <:actions>
                      <.button phx-disable-with="修改中..." class="w-full md:w-auto">修改邮箱</.button>
                    </:actions>
                  </.simple_form>
                </div>

                <div class="settings-section" id="password">
                  <div class="flex items-center mb-3">
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class="h-6 w-6 mr-2 text-indigo-600"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"
                      />
                    </svg>
                    <h3 class="text-xl font-medium">修改密码</h3>
                  </div>
                  <p class="text-gray-600 mb-4">定期更新您的密码可以提高账户安全性</p>
                  <.simple_form
                    for={@password_form}
                    id="password_form"
                    action={~p"/users/log_in?_action=password_updated"}
                    method="post"
                    phx-change="validate_password"
                    phx-submit="update_password"
                    phx-trigger-action={@trigger_submit}
                    class="settings-form"
                  >
                    <input
                      name={@password_form[:email].name}
                      type="hidden"
                      id="hidden_user_email"
                      value={@current_email}
                    />
                    <div class="md:grid md:grid-cols-2 md:gap-6">
                      <div>
                        <.input
                          field={@password_form[:password]}
                          type="password"
                          label="新密码"
                          required
                        />
                      </div>
                      <div>
                        <.input
                          field={@password_form[:password_confirmation]}
                          type="password"
                          label="确认新密码"
                        />
                      </div>
                    </div>
                    <.input
                      field={@password_form[:current_password]}
                      name="current_password"
                      type="password"
                      label="当前密码"
                      id="current_password_for_password"
                      value={@current_password}
                      required
                    />
                    <:actions>
                      <.button phx-disable-with="修改中..." class="w-full md:w-auto">修改密码</.button>
                    </:actions>
                  </.simple_form>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("validate_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    email_form =
      socket.assigns.current_user
      |> Accounts.change_user_email(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form, email_form_current_password: password)}
  end

  def handle_event("update_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Accounts.apply_user_email(user, password, user_params) do
      {:ok, applied_user} ->
        Accounts.deliver_user_update_email_instructions(
          applied_user,
          user.email,
          &url(~p"/users/settings/confirm_email/#{&1}")
        )

        info = "确认您邮箱修改的链接已发送到新地址。"
        {:noreply, socket |> put_flash(:info, info) |> assign(email_form_current_password: nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :email_form, to_form(Map.put(changeset, :action, :insert)))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    password_form =
      socket.assigns.current_user
      |> Accounts.change_user_password(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form, current_password: password)}
  end

  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Accounts.update_user_password(user, password, user_params) do
      {:ok, user} ->
        password_form =
          user
          |> Accounts.change_user_password(user_params)
          |> to_form()

        {:noreply, assign(socket, trigger_submit: true, password_form: password_form)}

      {:error, changeset} ->
        {:noreply, assign(socket, password_form: to_form(changeset))}
    end
  end
end
