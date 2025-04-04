defmodule MyAppWeb.PageController do
  use MyAppWeb, :controller

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false)
  end
  
  def test_form(conn, _params) do
    conn
    |> assign(:page_title, "表单创建测试")
    |> render(:test_form)
  end
end
