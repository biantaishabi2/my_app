defmodule MyAppWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is set as the default
  layout on both `use MyAppWeb, :controller` and
  `use MyAppWeb, :live_view`.
  """
  use MyAppWeb, :html
  import Phoenix.Component, except: [form: 1]

  embed_templates "layouts/*"

  def render("empty.html", assigns) do
    ~H"""
    <%= @inner_content %>
    """
  end

  def render("account.html", assigns) do
    account(assigns)
  end

  def render("form.html", assigns) do
    form(assigns)
  end

  # 如果不使用嵌入模板，则移除这个函数
  # def render("account_settings.html", assigns) do
  #   account_settings(assigns)
  # end
end
