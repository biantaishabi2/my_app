defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  import MyAppWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MyAppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  # 为账户相关页面创建单独的布局管道
  pipeline :account_browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MyAppWeb.Layouts, :account}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  # 为表单相关页面创建单独的布局管道
  pipeline :form_browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {MyAppWeb.Layouts, :form}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", MyAppWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/test-form", PageController, :test_form
    live "/test-upload", TestUploadLive
    live "/test-upload/:form_id/:field_id", TestUploadLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", MyAppWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:my_app, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: MyAppWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", MyAppWeb do
    # 使用账户布局管道
    pipe_through [:account_browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{MyAppWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/register", UserRegistrationLive, :new
      live "/users/log_in", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", MyAppWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{MyAppWeb.UserAuth, :ensure_authenticated}] do
      live "/chat", ChatLive.Index, :index
      live "/chat/:id", ChatLive.Index, :show
    end
  end

  # 表单系统管理路由
  scope "/", MyAppWeb do
    pipe_through [:form_browser, :require_authenticated_user]

    live_session :form_system,
      on_mount: [{MyAppWeb.UserAuth, :ensure_authenticated}] do
      live "/forms", FormLive.Index, :index
      live "/forms/new", FormLive.Index, :new
      live "/forms/:id", FormLive.Show, :show
      live "/forms/:id/edit", FormLive.Edit, :edit
      live "/forms/:id/responses", FormLive.Responses, :index
      live "/forms/:form_id/responses/:id", FormLive.Responses, :show
      live "/forms/:id/statistics", FormLive.Statistics, :index
      live "/forms/:id/show/edit", FormLive.Show, :edit

      # 表单模板演示页面 (旧)
      live "/form-templates/demo", FormTemplateLive, :index
      # 新：模板结构拖放 Demo 页面
      live "/form-structures/demo", FormStructureDemoLive, :index
      # 新：模板结构编辑器页面
      live "/form-templates/:id/edit", FormTemplateEditorLive, :edit
    end
  end

  # 表单填写路由 (已登录用户)
  scope "/", MyAppWeb do
    pipe_through [:form_browser, :require_authenticated_user]

    live_session :form_submission,
      on_mount: [{MyAppWeb.UserAuth, :ensure_authenticated}] do
      live "/forms/:id/submit", FormLive.Submit, :new
    end
  end

  # 公开表单路由 (无需登录)
  scope "/", MyAppWeb do
    pipe_through [:form_browser]

    live_session :public_form_submission do
      live "/public/forms/:id", PublicFormLive.Show, :show
      live "/public/forms/:id/submit", PublicFormLive.Submit, :new
    end

    get "/public/forms/:id/success", PublicFormController, :success
  end

  # 为用户设置页面单独使用account_browser布局
  scope "/", MyAppWeb do
    pipe_through [:account_browser, :require_authenticated_user]

    live_session :user_settings,
      on_mount: [
        {MyAppWeb.UserAuth, :ensure_authenticated},
        {MyAppWeb.UserSettingsLive, :default}
      ],
      root_layout: {MyAppWeb.Layouts, :account} do
      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email
    end
  end

  scope "/", MyAppWeb do
    # 使用账户布局管道用于确认相关页面
    pipe_through [:account_browser]

    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{MyAppWeb.UserAuth, :mount_current_user}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end
end
