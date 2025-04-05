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
      _option1 = item_option_fixture(radio_item, %{label: "选项1", value: "option1"})
      _option2 = item_option_fixture(radio_item, %{label: "选项2", value: "option2"})
      
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
      assert has_element?(view, "[required]") # 验证有必填字段，更贴近用户体验而非实现细节
      
      # 验证单选按钮表单项显示
      assert has_element?(view, "label", radio_item.label)
      assert has_element?(view, "input[type='radio']")
      assert has_element?(view, "label", "选项1")
      assert has_element?(view, "label", "选项2")
    end

    test "表单验证 - 空表单提交显示错误提示", %{conn: conn, form: form} do
      {:ok, view, _html} = live(conn, ~p"/forms/#{form.id}/submit")
      
      # 提交空表单
      view
      |> form("#form-submission", %{})
      |> render_submit()
      
      # 验证错误提示显示 - 检查是否有错误消息，而不依赖特定CSS类或DOM结构
      assert has_element?(view, "[role='alert']") || 
             has_element?(view, "[id^='error_']") ||
             render(view) =~ "必填项"
    end

    test "表单验证 - 填写文本字段后无错误", %{conn: conn, form: form, text_item: text_item} do
      {:ok, view, _html} = live(conn, ~p"/forms/#{form.id}/submit")
      
      # 输入文本字段
      html = view
             |> form("#form-submission", %{"form" => %{"#{text_item.id}" => "我的回答"}})
             |> render_change()
      
      # 检查特定字段的错误消息是否不存在
      refute html =~ "id=\"error_#{text_item.id}\""
    end

    test "表单验证 - 选择单选按钮后无错误", %{conn: conn, form: form, radio_item: radio_item} do
      {:ok, view, _html} = live(conn, ~p"/forms/#{form.id}/submit")
      
      # 模拟选择单选按钮的行为，使用form提交而非特定DOM元素
      html = view
             |> form("#form-submission", %{"form" => %{"#{radio_item.id}" => "option1"}})
             |> render_change()
      
      # 验证没有该字段的错误消息
      refute html =~ "id=\"error_#{radio_item.id}\""
    end

    test "成功提交表单 - 创建表单响应", %{conn: conn, form: form, text_item: text_item, radio_item: radio_item} do
      {:ok, view, _html} = live(conn, ~p"/forms/#{form.id}/submit")
      
      # 填写表单并提交
      view
      |> form("#form-submission", %{
           "form" => %{
             "#{text_item.id}" => "我的文本回答",
             "#{radio_item.id}" => "option1"
           }
         })
      |> render_submit()
      
      # 给数据库操作一点时间完成
      Process.sleep(100)
      
      # 验证数据库中创建了响应
      responses = Responses.list_responses_for_form(form.id)
      assert length(responses) == 1
      
      # 验证基本的响应数据结构
      response = List.first(responses)
      assert Map.has_key?(response, :answers)
      assert length(response.answers) == 2
      
      # 验证文本答案 - 使用Map.get获取值，不关注内部存储格式
      text_answer = Enum.find(response.answers, fn a -> a.form_item_id == text_item.id end)
      assert Map.get(text_answer.value, "value") == "我的文本回答"
      
      # 验证单选答案 - 使用Map.get获取值，不关注内部存储格式
      radio_answer = Enum.find(response.answers, fn a -> a.form_item_id == radio_item.id end)
      assert Map.get(radio_answer.value, "value") == "option1"
    end

    test "草稿表单不能提交", %{conn: conn, user: user} do
      # 创建一个草稿表单
      draft_form = form_fixture(%{user_id: user.id, title: "草稿表单", status: :draft})
      
      # 尝试访问提交页面，检查是否被重定向
      conn = get(conn, ~p"/forms/#{draft_form.id}/submit")
      assert redirected_to(conn) =~ "/forms"
    end

    test "表单所有者可以提交自己的表单", %{conn: conn, form: form} do
      # 表单所有者应该可以提交自己的表单
      {:ok, view, _html} = live(conn, ~p"/forms/#{form.id}/submit")
      
      # 验证页面上有提交表单的能力，不依赖于具体按钮实现
      assert has_element?(view, "form#form-submission")
      assert has_element?(view, "button[type='submit']")
    end
  end
end