defmodule MyAppWeb.FormLive.EditPagesTest do
  use MyAppWeb.ConnCase

  import Phoenix.LiveViewTest
  import MyApp.AccountsFixtures
  import MyApp.FormsFixtures

  alias MyApp.Forms

  setup do
    user = user_fixture()
    form = form_fixture(%{user_id: user.id, title: "测试表单管理"})
    %{user: user, form: form}
  end

  describe "表单页面管理" do
    test "显示页面管理面板", %{conn: conn, user: user, form: form} do
      {:ok, view, html} = 
        conn
        |> log_in_user(user)
        |> live(~p"/forms/#{form.id}/edit")

      # 验证页面管理面板存在
      assert has_element?(view, "[data-test-id='form-pages-panel']")
      assert has_element?(view, "[data-test-id='add-page-button']")
    end

    test "添加新页面", %{conn: conn, user: user, form: form} do
      {:ok, view, _html} = 
        conn
        |> log_in_user(user)
        |> live(~p"/forms/#{form.id}/edit")

      # 点击添加页面按钮
      view
      |> element("[data-test-id='add-page-button']")
      |> render_click()

      # 验证打开页面编辑表单
      assert has_element?(view, "[data-test-id='page-form']")

      # 填写并提交表单
      view
      |> form("#page-form", %{
        "page" => %{
          "title" => "新页面",
          "description" => "这是一个新页面"
        }
      })
      |> render_submit()

      # 验证新页面已添加
      assert has_element?(view, "[data-test-id='page-item']", "新页面")
      assert render(view) =~ "这是一个新页面"
    end

    test "编辑现有页面", %{conn: conn, user: user, form: form} do
      # 创建测试页面
      {:ok, page} = Forms.create_form_page(form, %{
        title: "测试页面",
        description: "测试描述",
        order: 1
      })

      {:ok, view, _html} = 
        conn
        |> log_in_user(user)
        |> live(~p"/forms/#{form.id}/edit")

      # 验证页面显示
      assert has_element?(view, "[data-test-id='page-item']", "测试页面")

      # 点击编辑按钮
      view
      |> element("[data-test-id='edit-page-#{page.id}']")
      |> render_click()

      # 验证编辑表单已打开并预填充
      form_element = view |> element("#page-form")
      assert form_element |> render() =~ "测试页面"
      assert form_element |> render() =~ "测试描述"

      # 修改并提交表单
      view
      |> form("#page-form", %{
        "page" => %{
          "title" => "已更新的标题",
          "description" => "已更新的描述"
        }
      })
      |> render_submit()

      # 验证页面已更新
      assert has_element?(view, "[data-test-id='page-item']", "已更新的标题")
      assert render(view) =~ "已更新的描述"
    end

    test "删除页面", %{conn: conn, user: user, form: form} do
      # 创建测试页面
      {:ok, page} = Forms.create_form_page(form, %{
        title: "待删除页面",
        description: "即将被删除",
        order: 1
      })

      {:ok, view, _html} = 
        conn
        |> log_in_user(user)
        |> live(~p"/forms/#{form.id}/edit")

      # 确认页面存在
      assert has_element?(view, "[data-test-id='page-item']", "待删除页面")

      # 点击删除按钮
      view
      |> element("[data-test-id='delete-page-#{page.id}']")
      |> render_click()

      # 确认删除对话框
      view
      |> element("[data-test-id='confirm-delete-page']")
      |> render_click()

      # 验证页面已删除
      refute has_element?(view, "[data-test-id='page-item']", "待删除页面")
    end

    test "重新排序页面", %{conn: conn, user: user, form: form} do
      # 创建三个测试页面
      {:ok, page1} = Forms.create_form_page(form, %{title: "第一页", order: 1})
      {:ok, page2} = Forms.create_form_page(form, %{title: "第二页", order: 2})
      {:ok, page3} = Forms.create_form_page(form, %{title: "第三页", order: 3})

      {:ok, view, _html} = 
        conn
        |> log_in_user(user)
        |> live(~p"/forms/#{form.id}/edit")

      # 验证初始顺序
      page_items = element(view, "[data-test-id='form-pages-list']") |> render()
      assert page_items =~ ~r/第一页.*第二页.*第三页/s

      # 模拟拖动排序操作（LiveView测试不支持真实拖拽，使用事件模拟）
      reordered_ids = [page3.id, page1.id, page2.id]
      
      view
      |> element("[data-test-id='form-pages-list']")
      |> render_hook("pages_reordered", %{"pageIds" => reordered_ids})

      # 验证新顺序
      updated_page_items = element(view, "[data-test-id='form-pages-list']") |> render()
      assert updated_page_items =~ ~r/第三页.*第一页.*第二页/s
    end
  end

  describe "表单项页面分配" do
    setup %{form: form} do
      # 创建两个测试页面
      {:ok, page1} = Forms.create_form_page(form, %{title: "页面一", order: 1})
      {:ok, page2} = Forms.create_form_page(form, %{title: "页面二", order: 2})
      
      %{page1: page1, page2: page2}
    end

    test "新建表单项时选择页面", %{conn: conn, user: user, form: form, page1: page1, page2: page2} do
      {:ok, view, _html} = 
        conn
        |> log_in_user(user)
        |> live(~p"/forms/#{form.id}/edit")

      # 点击添加表单项按钮
      view
      |> element("[data-test-id='add-item-button']")
      |> render_click()

      # 验证页面选择器存在
      form_element = view |> element("#form-item-editor")
      assert form_element |> render() =~ "选择页面"
      assert form_element |> render() =~ page1.title
      assert form_element |> render() =~ page2.title

      # 选择第一个页面并填写表单
      view
      |> form("#form-item-editor form", %{
        "item" => %{
          "label" => "测试表单项",
          "type" => "text_input",
          "required" => "true",
          "page_id" => page1.id
        }
      })
      |> render_submit()

      # 验证表单项被添加到正确的页面
      assert has_element?(view, "[data-test-id='page-#{page1.id}-items']", "测试表单项")
    end

    test "编辑表单项时可以更改页面", %{conn: conn, user: user, form: form, page1: page1, page2: page2} do
      # 创建一个在page1的表单项
      {:ok, item} = Forms.add_form_item(form, %{
        label: "要移动的表单项",
        type: :text_input,
        page_id: page1.id
      })

      {:ok, view, _html} = 
        conn
        |> log_in_user(user)
        |> live(~p"/forms/#{form.id}/edit")

      # 验证表单项在page1
      assert has_element?(view, "[data-test-id='page-#{page1.id}-items']", "要移动的表单项")

      # 点击编辑按钮
      view
      |> element("#edit-item-#{item.id}")
      |> render_click()

      # 更改页面为page2
      view
      |> form("#form-item-editor form", %{
        "item" => %{
          "label" => "要移动的表单项",
          "page_id" => page2.id
        }
      })
      |> render_submit()

      # 验证表单项已移动到page2
      assert has_element?(view, "[data-test-id='page-#{page2.id}-items']", "要移动的表单项")
      refute has_element?(view, "[data-test-id='page-#{page1.id}-items']", "要移动的表单项")
    end

    test "拖拽表单项到不同页面", %{conn: conn, user: user, form: form, page1: page1, page2: page2} do
      # 创建几个测试表单项
      {:ok, item1} = Forms.add_form_item(form, %{label: "项目1", type: :text_input, page_id: page1.id})
      {:ok, item2} = Forms.add_form_item(form, %{label: "项目2", type: :radio, page_id: page1.id})

      {:ok, view, _html} = 
        conn
        |> log_in_user(user)
        |> live(~p"/forms/#{form.id}/edit")

      # 验证表单项在page1
      assert has_element?(view, "[data-test-id='page-#{page1.id}-items']", "项目1")
      assert has_element?(view, "[data-test-id='page-#{page1.id}-items']", "项目2")

      # 模拟拖拽item2到page2
      view
      |> element("[data-test-id='page-items-container']")
      |> render_hook("item_moved_to_page", %{
        "itemId" => item2.id,
        "targetPageId" => page2.id
      })

      # 验证item2已移动到page2
      assert has_element?(view, "[data-test-id='page-#{page1.id}-items']", "项目1")
      refute has_element?(view, "[data-test-id='page-#{page1.id}-items']", "项目2")
      assert has_element?(view, "[data-test-id='page-#{page2.id}-items']", "项目2")
    end
  end

  describe "表单页面预览" do
    setup %{form: form} do
      # 创建两个测试页面并添加表单项
      {:ok, page1} = Forms.create_form_page(form, %{title: "个人信息", order: 1})
      {:ok, page2} = Forms.create_form_page(form, %{title: "联系方式", order: 2})
      
      # 为每个页面添加表单项
      {:ok, _} = Forms.add_form_item(form, %{label: "姓名", type: :text_input, page_id: page1.id})
      {:ok, _} = Forms.add_form_item(form, %{label: "邮箱", type: :email, page_id: page2.id})
      
      %{page1: page1, page2: page2}
    end

    test "页面预览模式显示分页表单", %{conn: conn, user: user, form: form, page1: page1, page2: page2} do
      {:ok, view, _html} = 
        conn
        |> log_in_user(user)
        |> live(~p"/forms/#{form.id}/edit")

      # 点击预览按钮
      view
      |> element("[data-test-id='preview-button']")
      |> render_click()

      # 验证预览模式下显示第一页内容
      assert has_element?(view, "[data-test-id='form-preview']")
      assert has_element?(view, "[data-test-id='preview-page-title']", page1.title)
      assert render(view) =~ "姓名"
      refute render(view) =~ "邮箱"

      # 点击下一页按钮
      view
      |> element("[data-test-id='preview-next-page']")
      |> render_click()

      # 验证现在显示第二页内容
      assert has_element?(view, "[data-test-id='preview-page-title']", page2.title)
      assert render(view) =~ "邮箱"
      refute render(view) =~ "姓名"
    end

    test "返回到编辑模式", %{conn: conn, user: user, form: form} do
      {:ok, view, _html} = 
        conn
        |> log_in_user(user)
        |> live(~p"/forms/#{form.id}/edit")

      # 进入预览模式
      view
      |> element("[data-test-id='preview-button']")
      |> render_click()

      # 确认在预览模式
      assert has_element?(view, "[data-test-id='form-preview']")

      # 点击返回编辑按钮
      view
      |> element("[data-test-id='back-to-edit-button']")
      |> render_click()

      # 验证返回编辑模式
      assert has_element?(view, "[data-test-id='form-editor']")
      refute has_element?(view, "[data-test-id='form-preview']")
    end
  end
end