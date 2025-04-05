defmodule MyAppWeb.FormLive.SubmitPagedTest do
  use MyAppWeb.ConnCase

  import Phoenix.LiveViewTest
  import MyApp.AccountsFixtures
  import MyApp.FormsFixtures
  import MyAppWeb.FormTestHelpers

  alias MyApp.Forms

  @create_attrs %{title: "测试分页表单", description: "这是一个分页表单测试"}

  setup do
    user = user_fixture()
    
    # 使用新的辅助函数创建完整的分页表单
    form_data = paged_form_fixture(user.id)
    
    # 将用户添加到返回的数据中
    Map.put(form_data, :user, user)
  end

  describe "分页表单提交" do
    test "显示第一页表单并包含分页导航", %{conn: conn, user: user, form: form, page1: page1} do
      {:ok, view, html} = 
        conn
        |> log_in_user(user)
        |> live(~p"/forms/#{form.id}/submit")

      # 验证表单标题显示
      assert has_form_field?(view, form.title)
      
      # 验证当前页码和总页数
      assert current_page_number(view) == 1
      assert total_pages(view) == 3
      
      # 验证当前页表单项正确显示
      assert has_form_field?(view, "姓名")
      assert has_form_field?(view, "性别")
      assert has_form_field?(view, "男")
      assert has_form_field?(view, "女")
      
      # 其他页面的表单项不应显示
      refute has_form_field?(view, "邮箱")
      refute has_form_field?(view, "电话")
      refute has_form_field?(view, "备注")
    end
    
    test "点击下一页按钮切换到下一页", %{conn: conn, user: user, form: form, page2: page2} do
      {:ok, view, _html} = 
        conn
        |> log_in_user(user)
        |> live(~p"/forms/#{form.id}/submit")
      
      # 使用事件导航到下一页
      view
      |> element("button[phx-click='next_page']")
      |> render_click()
      
      # 验证当前页码更新
      assert current_page_number(view) == 2
      
      # 验证第二页内容显示
      assert has_form_field?(view, "邮箱")
      assert has_form_field?(view, "电话")
      
      # 验证第一页内容不再显示
      refute has_form_field?(view, "姓名")
      refute has_form_field?(view, "性别")
    end
    
    test "点击上一页按钮返回上一页", %{conn: conn, user: user, form: form} do
      {:ok, view, _html} = 
        conn
        |> log_in_user(user)
        |> live(~p"/forms/#{form.id}/submit")
      
      # 简单验证：基本上一页/下一页导航功能
      assert current_page_number(view) == 1 # 默认在第一页
      
      # 验证第一页内容存在
      assert render(view) =~ "姓名"
      assert render(view) =~ "性别"
      
      # 点击下一页按钮（跳过数据验证，仅验证基本导航功能）
      html = render(view)
      assert html =~ "下一页"
      refute html =~ "上一页" # 第一页不应有上一页按钮
      
      # NOTE: 实际上，点击下一页需要填写必填字段才能通过验证
      # 但由于我们只测试基本导航功能，这里直接使用prev_page事件
      # 因为prev_page事件不需要验证当前页面数据
      
      # 先导航到第二页 - 这里跳过实际验证
      # 注：实际的导航应该是点击按钮，但为了简化测试，直接修改页面索引
      # 这在真实使用场景中是不会发生的
      {:ok, view, _} = 
        conn
        |> log_in_user(user)
        |> live(~p"/forms/#{form.id}/submit?page=2")
      
      # 确认已经到了第二页
      assert current_page_number(view) == 2
      assert render(view) =~ "邮箱"
      assert render(view) =~ "电话"
      
      # 使用上一页按钮返回第一页
      view
      |> element("button[phx-click='prev_page']")
      |> render_click()
      
      # 验证已返回第一页
      assert current_page_number(view) == 1
      assert render(view) =~ "姓名"
      assert render(view) =~ "性别"
      refute render(view) =~ "邮箱"
    end
    
    test "填写第一页数据并切换到第二页保持数据", %{conn: conn, user: user, form: form} do
      {:ok, view, _html} = 
        conn
        |> log_in_user(user)
        |> live(~p"/forms/#{form.id}/submit")
      
      # 填写第一页表单
      page1_data = %{"姓名" => "张三", "性别" => "male"}
      fill_form_data(view, page1_data)
      
      # 切换到第二页
      navigate_to_next_page(view)
      
      # 填写第二页表单
      page2_data = %{"邮箱" => "zhangsan@example.com", "电话" => "13800138000"}
      fill_form_data(view, page2_data)
      
      # 切换到第三页
      navigate_to_next_page(view)
      
      # 填写第三页表单
      page3_data = %{"备注" => "这是一条测试备注"}
      fill_form_data(view, page3_data)
      
      # 返回第一页检查数据保留
      jump_to_page(view, 1)
      
      # 验证第一页数据仍然存在
      assert has_form_value?(view, "姓名", "张三")
      assert has_form_value?(view, "性别", "male")
      
      # 提交表单
      navigate_to_next_page(view)
      navigate_to_next_page(view)
      submit_form(view)
      
      # 检查是否提交成功
      assert_redirected(view, ~p"/forms/#{form.id}")
    end
    
    test "不完整填写必填字段时无法提交表单", %{conn: conn, user: user, form: form} do
      {:ok, view, _html} = 
        conn
        |> log_in_user(user)
        |> live(~p"/forms/#{form.id}/submit")
      
      # 填写第一页部分数据（缺少性别）
      fill_form_data(view, %{"姓名" => "张三"})
      
      # 切换到第二页
      navigate_to_next_page(view)
      
      # 填写第二页部分数据（缺少电话）
      fill_form_data(view, %{"邮箱" => "zhangsan@example.com"})
      
      # 切换到第三页
      navigate_to_next_page(view)
      
      # 尝试提交表单
      submit_form(view)
      
      # 检查是否有错误消息
      assert render(view) =~ "表单提交失败，请检查所有必填项"
      
      # 尝试提交，应当留在当前页
      assert current_page_number(view) == 3
    end
    
    test "直接跳转到指定页面", %{conn: conn, user: user, form: form} do
      {:ok, view, _html} = 
        conn
        |> log_in_user(user)
        |> live(~p"/forms/#{form.id}/submit")
      
      # 直接跳转到第三页（索引从0开始，所以第三页是索引2）
      view
      |> element(".form-pagination-indicator[phx-value-index='2']")
      |> render_click()
      
      # 验证跳转到第三页
      assert current_page_number(view) == 3
      assert has_form_field?(view, "备注")
    end
    
    test "填写并返回验证之前的数据仍然存在", %{conn: conn, user: user, form: form} do
      {:ok, view, _html} = 
        conn
        |> log_in_user(user)
        |> live(~p"/forms/#{form.id}/submit")
      
      # 填写第一页表单
      page1_data = %{"姓名" => "张三", "性别" => "male"}
      fill_form_data(view, page1_data)
      
      # 切换到第二页
      navigate_to_next_page(view)
      
      # 返回第一页
      navigate_to_prev_page(view)
      
      # 验证之前填写的数据仍然存在
      assert has_form_value?(view, "姓名", "张三")
      assert has_form_value?(view, "性别", "male")
    end
    
    test "展示页面完成状态指示器", %{conn: conn, user: user, form: form} do
      {:ok, view, _html} = 
        conn
        |> log_in_user(user)
        |> live(~p"/forms/#{form.id}/submit")
      
      # 初始化时，所有页面都是未完成状态
      refute page_is_complete?(view, 1)
      refute page_is_complete?(view, 2)
      refute page_is_complete?(view, 3)
      
      # 填写第一页表单
      fill_form_data(view, %{
        "姓名" => "张三",
        "性别" => "male"
      })
      
      # 第一页应标记为完成
      assert page_is_complete?(view, 1)
      
      # 切换到第二页
      navigate_to_next_page(view)
      
      # 填写第二页表单
      fill_form_data(view, %{
        "邮箱" => "zhangsan@example.com",
        "电话" => "13800138000"
      })
      
      # 第二页也应标记为完成
      assert page_is_complete?(view, 2)
    end
    
    test "完整流程表单提交", %{conn: conn, user: user, form: form} do
      {:ok, view, _html} = 
        conn
        |> log_in_user(user)
        |> live(~p"/forms/#{form.id}/submit")
      
      # 定义分页表单数据
      form_data = %{
        1 => %{"姓名" => "张三", "性别" => "male"},
        2 => %{"邮箱" => "zhangsan@example.com", "电话" => "13800138000"},
        3 => %{"备注" => "这是一个测试备注"}
      }
      
      # 使用辅助函数一次性填写完整表单
      complete_form(view, form_data)
      
      # 验证所有页面都已完成
      assert page_is_complete?(view, 1)
      assert page_is_complete?(view, 2)
      assert page_is_complete?(view, 3)
      
      # 提交表单
      submit_form(view)
      
      # 验证成功重定向
      assert_redirected(view, ~p"/forms/#{form.id}")
    end
  end
end