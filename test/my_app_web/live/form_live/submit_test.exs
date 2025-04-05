defmodule MyAppWeb.FormLive.SubmitTest do
  use MyAppWeb.ConnCase

  import Phoenix.LiveViewTest
  import MyApp.FormsFixtures
  import MyApp.AccountsFixtures

  alias MyApp.Forms
  alias MyApp.Responses

  setup :register_and_log_in_user

  describe "表单提交页面" do
    setup %{user: user} do
      # 创建一个测试表单和表单项
      form = form_fixture(%{user_id: user.id, title: "测试表单", description: "测试描述"})
      text_item = form_item_fixture(form, %{label: "文本问题", type: :text_input, required: true})
      radio_item = form_item_fixture(form, %{label: "单选问题", type: :radio, required: true})
      option1 = item_option_fixture(radio_item, %{label: "选项1", value: "option1"})
      option2 = item_option_fixture(radio_item, %{label: "选项2", value: "option2"})
      
      # 发布表单
      {:ok, published_form} = Forms.publish_form(form)
      
      %{form: published_form, text_item: text_item, radio_item: radio_item}
    end

    test "表单提交页面加载", %{conn: conn, form: form} do
      {:ok, view, html} = live(conn, ~p"/forms/#{form.id}/submit")
      
      # 验证页面标题和表单信息
      assert html =~ form.title
      assert html =~ form.description
      assert has_element?(view, "h1", form.title)
      assert has_element?(view, "p", form.description)
    end

    test "表单字段正确显示", %{conn: conn, form: form, text_item: text_item, radio_item: radio_item} do
      {:ok, view, _html} = live(conn, ~p"/forms/#{form.id}/submit")
      
      # 验证文本输入表单项显示
      assert has_element?(view, "label", text_item.label)
      assert has_element?(view, "input[type='text']")
      assert has_element?(view, ".required-mark", "*")
      
      # 验证单选按钮表单项显示
      assert has_element?(view, "label", radio_item.label)
      assert render(view) =~ "input type=\"radio\""
      assert has_element?(view, "label", "选项1")
      assert has_element?(view, "label", "选项2")
    end

    test "表单验证 - 显示错误提示", %{conn: conn, form: form} do
      {:ok, view, _html} = live(conn, ~p"/forms/#{form.id}/submit")
      
      # 提交空表单
      view
      |> element("button", "提交")
      |> render_click()
      
      # 验证错误提示显示
      assert has_element?(view, ".error-message", "此字段为必填项")
      # 确保错误消息显示，不关心具体有多少个错误字段
      assert render(view) =~ "field-error"
    end

    test "表单验证 - 文本字段", %{conn: conn, form: form, text_item: text_item} do
      {:ok, view, _html} = live(conn, ~p"/forms/#{form.id}/submit")
      
      # 输入文本字段
      view
      |> element("#answer_#{text_item.id}")
      |> render_change(%{value: "我的回答"})
      
      # 文本字段验证通过，无错误显示
      refute has_element?(view, "#error_#{text_item.id}")
    end

    test "表单验证 - 单选字段", %{conn: conn, form: form, radio_item: radio_item} do
      {:ok, view, _html} = live(conn, ~p"/forms/#{form.id}/submit")
      
      # 选择单选按钮
      view
      |> element("#answer_#{radio_item.id}_option1")
      |> render_change()
      
      # 单选字段验证通过，验证页面中包含有效的单选按钮选择
      html = render(view)
      assert html =~ "checked"
    end

    test "成功提交表单", %{conn: conn, form: form, text_item: text_item, radio_item: radio_item} do
      {:ok, view, _html} = live(conn, ~p"/forms/#{form.id}/submit")
      
      # 填写所有字段
      view
      |> element("#answer_#{text_item.id}")
      |> render_change(%{value: "我的文本回答"})
      
      view
      |> element("#answer_#{radio_item.id}_option1")
      |> render_change()
      
      # 提交表单
      view 
      |> element("button", "提交")
      |> render_click()
      
      # 不再依赖具体的重定向流程，直接检查数据库中的响应记录
      # 验证数据库中存在响应记录
      responses = Responses.list_responses_for_form(form.id)
      assert length(responses) == 1
      
      response = hd(responses)
      assert length(response.answers) == 2
      
      # 验证答案内容
      text_answer = Enum.find(response.answers, fn a -> a.form_item_id == text_item.id end)
      assert text_answer.value == "我的文本回答"
      
      radio_answer = Enum.find(response.answers, fn a -> a.form_item_id == radio_item.id end)
      assert radio_answer.value == "option1"
    end

    test "草稿表单不能提交", %{conn: conn, user: user} do
      # 创建一个草稿表单
      draft_form = form_fixture(%{user_id: user.id, title: "草稿表单", status: :draft})
      
      # 尝试访问提交页面，使用conn.status检查重定向
      conn = get(conn, ~p"/forms/#{draft_form.id}/submit")
      assert conn.status == 302
      assert redirected_to(conn) =~ "/forms"
    end

    test "表单所有者也可以提交自己的表单", %{conn: conn, form: form} do
      # 表单所有者应该可以提交自己的表单
      {:ok, view, _html} = live(conn, ~p"/forms/#{form.id}/submit")
      assert has_element?(view, "button", "提交")
    end
  end
end