defmodule MyAppWeb.FormLive.EditTest do
  use MyAppWeb.ConnCase

  import Phoenix.LiveViewTest
  import MyApp.FormsFixtures
  import MyApp.AccountsFixtures

  alias MyApp.Forms

  setup :register_and_log_in_user

  describe "表单编辑页面" do
    setup %{user: user} do
      # 创建一个测试表单和表单项
      form = form_fixture(%{user_id: user.id, title: "测试表单", description: "测试描述"})
      text_item = form_item_fixture(form, %{label: "文本问题", type: :text_input, required: true})
      radio_item = form_item_fixture(form, %{label: "单选问题", type: :radio, required: true})
      _option1 = item_option_fixture(radio_item, %{label: "选项1", value: "option1"})
      _option2 = item_option_fixture(radio_item, %{label: "选项2", value: "option2"})
      
      %{form: form, text_item: text_item, radio_item: radio_item}
    end

    test "访问编辑页面", %{conn: conn, form: form} do
      {:ok, view, html} = live(conn, ~p"/forms/#{form.id}/edit")
      
      # 验证页面标题和表单信息
      assert html =~ form.title
      assert html =~ "编辑表单"
      assert has_element?(view, "input#form-title[value='#{form.title}']")
      assert has_element?(view, "textarea#form-description", form.description)
    end

    test "编辑表单信息", %{conn: conn, form: form} do
      {:ok, view, _html} = live(conn, ~p"/forms/#{form.id}/edit")
      
      # 更新表单标题和描述
      updated_title = "更新后的标题"
      updated_description = "更新后的描述"
      
      view
      |> element("#form-title")
      |> render_change(%{value: updated_title})
      
      view
      |> element("#form-description")
      |> render_change(%{value: updated_description})
      
      # 点击保存按钮
      view
      |> element("button", "保存")
      |> render_click()
      
      # 验证更新成功
      updated_form = Forms.get_form(form.id)
      assert updated_form.title == updated_title
      assert updated_form.description == updated_description
    end

    test "添加文本输入表单项", %{conn: conn, form: form} do
      {:ok, view, _html} = live(conn, ~p"/forms/#{form.id}/edit")
      
      # 点击添加表单项按钮
      view
      |> element("#add-new-form-item-button")
      |> render_click()
      
      # 选择文本输入类型
      view
      |> element("button", "文本输入")
      |> render_click()
      
      # 填写表单项信息
      new_label = "新文本问题"
      
      view
      |> element("#new-item-label")
      |> render_change(%{value: new_label})
      
      view
      |> element("#new-item-required")
      |> render_change(%{value: "true"})
      
      # 保存新表单项
      view
      |> element("#submit-form-item-btn")
      |> render_click()
      
      # 验证表单项添加成功
      assert has_element?(view, ".form-item", new_label)
      
      # 验证数据库中存在新表单项
      updated_form = Forms.get_form(form.id)
      assert Enum.any?(updated_form.items, fn item -> item.label == new_label end)
    end

    test "添加单选按钮表单项", %{conn: conn, form: form} do
      {:ok, view, _html} = live(conn, ~p"/forms/#{form.id}/edit")
      
      # 点击添加表单项按钮
      view
      |> element("#add-new-form-item-button")
      |> render_click()
      
      # 选择单选按钮类型
      view
      |> element("button", "单选按钮")
      |> render_click()
      
      # 填写表单项信息
      new_label = "新单选问题"
      
      view
      |> element("#new-item-label")
      |> render_change(%{value: new_label})
      
      # 添加选项1
      view
      |> element("button", "添加选项")
      |> render_click()
      
      view
      |> element("#option-0-label")
      |> render_change(%{value: "选项A"})
      
      view
      |> element("#option-0-value")
      |> render_change(%{value: "a"})
      
      # 添加选项2
      view
      |> element("button", "添加选项")
      |> render_click()
      
      view
      |> element("#option-1-label")
      |> render_change(%{value: "选项B"})
      
      view
      |> element("#option-1-value")
      |> render_change(%{value: "b"})
      
      # 保存新表单项
      view
      |> element("#submit-form-item-btn")
      |> render_click()
      
      # 验证表单项添加成功
      assert has_element?(view, ".form-item", new_label)
      assert has_element?(view, ".form-item", "选项A")
      assert has_element?(view, ".form-item", "选项B")
      
      # 验证数据库中存在新表单项和选项
      updated_form = Forms.get_form(form.id)
      new_item = Enum.find(updated_form.items, fn item -> item.label == new_label end)
      assert new_item
      assert length(new_item.options) == 2
      assert Enum.any?(new_item.options, fn opt -> opt.label == "选项A" end)
      assert Enum.any?(new_item.options, fn opt -> opt.label == "选项B" end)
    end

    test "编辑表单项", %{conn: conn, form: form, text_item: text_item} do
      {:ok, view, _html} = live(conn, ~p"/forms/#{form.id}/edit")
      
      # 点击编辑表单项按钮
      view
      |> element("#edit-item-#{text_item.id}")
      |> render_click()
      
      # 修改表单项标签
      updated_label = "修改后的文本问题"
      
      view
      |> element("#edit-item-label")
      |> render_change(%{value: updated_label})
      
      # 保存修改
      view
      |> element("#submit-form-item-btn")
      |> render_click()
      
      # 验证表单项更新成功
      assert has_element?(view, ".form-item", updated_label)
      
      # 验证数据库中表单项已更新
      updated_form = Forms.get_form(form.id)
      updated_item = Enum.find(updated_form.items, fn item -> item.id == text_item.id end)
      assert updated_item.label == updated_label
    end

    test "删除表单项", %{conn: conn, form: form, text_item: text_item} do
      {:ok, view, _html} = live(conn, ~p"/forms/#{form.id}/edit")
      
      # 点击删除表单项按钮
      view
      |> element("#delete-item-#{text_item.id}")
      |> render_click()
      
      # 确认删除
      view
      |> element("button", "确认删除")
      |> render_click()
      
      # 验证表单项已从页面移除
      refute has_element?(view, "#item-#{text_item.id}")
      
      # 验证数据库中表单项已删除
      updated_form = Forms.get_form(form.id)
      refute Enum.any?(updated_form.items, fn item -> item.id == text_item.id end)
    end

    test "发布表单", %{conn: conn, form: form} do
      {:ok, view, _html} = live(conn, ~p"/forms/#{form.id}/edit")
      
      # 点击发布按钮
      view
      |> element("button", "发布表单")
      |> render_click()
      
      # 确认发布
      view
      |> element("button", "确认发布")
      |> render_click()
      
      # 验证发布状态更新
      assert has_element?(view, ".status-published", "已发布")
      
      # 验证数据库中表单状态已更新
      updated_form = Forms.get_form(form.id)
      assert updated_form.status == :published
    end

    test "未经授权用户不能编辑表单", %{conn: conn} do
      # 创建一个不属于当前用户的表单
      other_user = user_fixture()
      other_form = form_fixture(%{user_id: other_user.id, title: "其他用户的表单"})
      
      # 尝试访问该表单的编辑页面
      assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/forms/#{other_form.id}/edit")
      assert path =~ "/forms"
    end
  end
end