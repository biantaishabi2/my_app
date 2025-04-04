defmodule MyAppWeb.FormLive.IndexTest do
  use MyAppWeb.ConnCase

  import Phoenix.LiveViewTest
  import MyApp.FormsFixtures
  import MyApp.AccountsFixtures

  setup :register_and_log_in_user

  describe "表单列表页面" do
    test "显示创建新表单按钮", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/forms")
      assert has_element?(view, "button", "创建新表单")
    end

    test "未登录用户被重定向到登录页面", %{conn: conn} do
      # 登出用户
      conn = delete_session(conn, :user_token)
      conn = assign(conn, :current_user, nil)
      
      # 尝试访问表单页面
      assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/forms")
      assert path =~ "/users/log_in"
    end

    test "显示用户的表单列表", %{conn: conn, user: user} do
      # 创建两个测试表单
      form1 = form_fixture(%{user_id: user.id, title: "测试表单1"})
      form2 = form_fixture(%{user_id: user.id, title: "测试表单2"})
      
      {:ok, view, _html} = live(conn, ~p"/forms")
      
      # 验证表单显示
      assert has_element?(view, "td", "测试表单1")
      assert has_element?(view, "td", "测试表单2")
    end

    test "只显示当前用户的表单", %{conn: conn, user: user} do
      # 创建另一个用户和表单
      other_user = user_fixture()
      other_form = form_fixture(%{user_id: other_user.id, title: "其他用户的表单"})
      
      {:ok, view, _html} = live(conn, ~p"/forms")
      
      # 确认不显示其他用户的表单
      refute has_element?(view, "td", "其他用户的表单")
    end
  end

  describe "表单创建功能" do
    test "点击创建按钮显示表单创建界面", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/forms")
      
      # 点击创建按钮
      view |> element("button", "创建新表单") |> render_click()
      
      # 验证创建表单界面显示
      assert has_element?(view, "h2", "创建新表单")
      assert has_element?(view, "input#form_title")
    end

    test "成功创建表单后跳转到编辑页面", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/forms")
      
      # 显示创建表单界面
      view |> element("button", "创建新表单") |> render_click()
      
      # 提交表单
      form_data = %{
        "form[title]" => "新表单测试",
        "form[description]" => "这是一个测试表单"
      }
      
      # 提交表单并跟随重定向
      {:ok, view, _html} = view 
                        |> form("form", form_data)
                        |> render_submit()
                        |> follow_redirect(conn)
      
      # 验证跳转到编辑页面
      assert view.module == MyAppWeb.FormLive.Edit
      assert has_element?(view, "h1", "新表单测试")
    end

    test "表单标题为空时显示错误", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/forms")
      
      # 显示创建表单界面
      view |> element("button", "创建新表单") |> render_click()
      
      # 提交空标题的表单
      form_data = %{
        "form[title]" => "",
        "form[description]" => "这是一个测试表单"
      }
      
      html = view 
           |> form("form", form_data)
           |> render_submit()
      
      # 验证错误信息显示
      assert html =~ "不能为空"
      
      # 确认表单仍然显示
      assert has_element?(view, "h2", "创建新表单")
    end

    test "取消创建表单操作", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/forms")
      
      # 显示创建表单界面
      view |> element("button", "创建新表单") |> render_click()
      assert has_element?(view, "h2", "创建新表单")
      
      # 点击取消按钮
      view |> element("button", "取消") |> render_click()
      
      # 验证创建表单界面已关闭
      refute has_element?(view, "h2", "创建新表单")
    end
  end
end