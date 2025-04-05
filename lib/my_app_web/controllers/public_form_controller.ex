defmodule MyAppWeb.PublicFormController do
  use MyAppWeb, :controller
  
  alias MyApp.Forms
  
  def success(conn, %{"id" => id}) do
    # 获取表单信息
    case Forms.get_form(id) do
      nil -> 
        conn
        |> put_flash(:error, "表单不存在")
        |> redirect(to: ~p"/")
        
      form -> 
        # 渲染成功页面
        render(conn, :success, form: form)
    end
  end
end