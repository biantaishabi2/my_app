defmodule MyAppWeb.FormLive.ShowTest do
  use MyAppWeb.ConnCase

  import Phoenix.LiveViewTest
  import MyApp.FormsFixtures
  import MyApp.AccountsFixtures

  alias MyApp.Forms

  setup :register_and_log_in_user

  describe "表单显示页面" do
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

    test "表单显示页面加载", %{conn: conn, form: form} do
      {:ok, view, html} = live(conn, ~p"/forms/#{form.id}")
      
      # 验证页面标题和表单信息
      assert html =~ form.title
      assert html =~ form.description
      assert has_element?(view, "h1", form.title)
      assert has_element?(view, "p", form.description)
    end

    test "表单项显示正确", %{conn: conn, form: form, text_item: text_item, radio_item: radio_item} do
      {:ok, view, _html} = live(conn, ~p"/forms/#{form.id}")
      
      # 验证文本输入表单项显示
      assert has_element?(view, ".form-item", text_item.label)
      assert has_element?(view, ".form-item-required", "必填")
      
      # 验证单选按钮表单项显示
      assert has_element?(view, ".form-item", radio_item.label)
      assert has_element?(view, ".form-item-option", "选项1")
      assert has_element?(view, ".form-item-option", "选项2")
    end

    test "提供编辑和填写链接", %{conn: conn, form: form} do
      {:ok, view, _html} = live(conn, ~p"/forms/#{form.id}")
      
      # 验证编辑链接
      assert has_element?(view, "a", "编辑表单")
      assert element(view, "a", "编辑表单") |> attribute("href") == "/forms/#{form.id}/edit"
      
      # 验证填写链接
      assert has_element?(view, "a", "填写表单")
      assert element(view, "a", "填写表单") |> attribute("href") == "/forms/#{form.id}/submit"
    end

    test "未发布表单显示状态", %{conn: conn, user: user} do
      # 创建未发布表单
      draft_form = form_fixture(%{user_id: user.id, title: "草稿表单", status: :draft})
      
      {:ok, view, _html} = live(conn, ~p"/forms/#{draft_form.id}")
      
      # 验证草稿状态显示
      assert has_element?(view, ".status-badge", "草稿")
    end

    test "已发布表单显示状态", %{conn: conn, form: form} do
      {:ok, view, _html} = live(conn, ~p"/forms/#{form.id}")
      
      # 验证发布状态显示
      assert has_element?(view, ".status-badge", "已发布")
    end

    test "其他用户不能查看草稿表单", %{conn: conn} do
      # 创建另一个用户的草稿表单
      other_user = user_fixture()
      other_form = form_fixture(%{user_id: other_user.id, title: "其他用户的草稿表单", status: :draft})
      
      # 尝试访问该表单
      assert {:error, {:live_redirect, %{to: path, flash: %{"error" => _}}}} = live(conn, ~p"/forms/#{other_form.id}")
      assert path =~ "/forms"
    end

    test "其他用户可以查看已发布表单", %{conn: conn} do
      # 创建另一个用户的已发布表单
      other_user = user_fixture()
      other_form = form_fixture(%{user_id: other_user.id, title: "其他用户的已发布表单"})
      {:ok, published_form} = Forms.publish_form(other_form)
      
      # 访问该表单
      {:ok, view, html} = live(conn, ~p"/forms/#{published_form.id}")
      
      # 验证可以查看表单
      assert html =~ published_form.title
      assert has_element?(view, "h1", published_form.title)
      
      # 但不应显示编辑链接
      refute has_element?(view, "a", "编辑表单")
    end
  end
end