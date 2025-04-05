defmodule MyApp.FormPagesTest do
  use MyApp.DataCase, async: false

  alias MyApp.Forms
  alias MyApp.Forms.FormPage
  alias MyApp.Forms.FormItem
  import MyApp.AccountsFixtures
  import MyApp.FormsFixtures

  describe "form_pages" do
    setup do
      user = user_fixture()
      form = form_fixture(%{user_id: user.id, title: "测试多页表单"})
      %{user: user, form: form}
    end

    test "create_form_page/2 创建表单页面", %{form: form} do
      attrs = %{
        title: "第一页",
        description: "这是表单的第一页",
        order: 1
      }

      assert {:ok, %FormPage{} = page} = Forms.create_form_page(form, attrs)
      assert page.title == "第一页"
      assert page.description == "这是表单的第一页"
      assert page.order == 1
      assert page.form_id == form.id
    end

    test "create_form_page/2 验证必填字段", %{form: form} do
      # 缺少标题
      assert {:error, %Ecto.Changeset{}} = Forms.create_form_page(form, %{
        description: "缺少标题的页面",
        order: 1
      })

      # 缺少顺序
      assert {:error, %Ecto.Changeset{}} = Forms.create_form_page(form, %{
        title: "缺少顺序的页面",
        description: "测试页面"
      })
    end

    test "get_form_page/1 获取页面", %{form: form} do
      # 创建测试页面
      {:ok, page} = Forms.create_form_page(form, %{
        title: "测试页面",
        description: "用于测试get_form_page的页面",
        order: 1
      })

      # 测试获取页面
      assert %FormPage{} = retrieved_page = Forms.get_form_page(page.id)
      assert retrieved_page.id == page.id
      assert retrieved_page.title == page.title
    end

    test "get_form_page/1 返回nil当页面不存在时" do
      assert is_nil(Forms.get_form_page(Ecto.UUID.generate()))
    end

    test "list_form_pages/1 列出表单所有页面", %{form: form} do
      # 创建三个页面
      {:ok, page1} = Forms.create_form_page(form, %{title: "第一页", order: 1})
      {:ok, page2} = Forms.create_form_page(form, %{title: "第二页", order: 2})
      {:ok, page3} = Forms.create_form_page(form, %{title: "第三页", order: 3})

      # 获取页面列表
      pages = Forms.list_form_pages(form.id)
      
      # 验证页面数量和顺序
      assert length(pages) == 3
      assert Enum.map(pages, & &1.id) == [page1.id, page2.id, page3.id]
      assert Enum.map(pages, & &1.title) == ["第一页", "第二页", "第三页"]
      
      # 验证空表单返回空列表
      empty_form = form_fixture(%{user_id: form.user_id, title: "空表单"})
      assert Forms.list_form_pages(empty_form.id) == []
    end

    test "update_form_page/2 更新页面", %{form: form} do
      # 创建测试页面
      {:ok, page} = Forms.create_form_page(form, %{
        title: "原始标题",
        description: "原始描述",
        order: 1
      })
      
      # 更新页面
      update_attrs = %{
        title: "更新后的标题",
        description: "更新后的描述"
      }
      
      assert {:ok, %FormPage{} = updated_page} = Forms.update_form_page(page, update_attrs)
      assert updated_page.title == "更新后的标题"
      assert updated_page.description == "更新后的描述"
      # 未更新的字段保持不变
      assert updated_page.order == 1
    end

    test "delete_form_page/1 删除页面", %{form: form} do
      # 创建测试页面
      {:ok, page} = Forms.create_form_page(form, %{
        title: "待删除页面",
        order: 1
      })
      
      # 删除页面
      assert {:ok, %FormPage{}} = Forms.delete_form_page(page)
      
      # 验证页面已删除
      assert is_nil(Forms.get_form_page(page.id))
    end

    test "reorder_form_pages/2 重新排序页面", %{form: form} do
      # 创建三个页面
      {:ok, page1} = Forms.create_form_page(form, %{title: "页面1", order: 1})
      {:ok, page2} = Forms.create_form_page(form, %{title: "页面2", order: 2})
      {:ok, page3} = Forms.create_form_page(form, %{title: "页面3", order: 3})
      
      # 重新排序
      page_ids = [page3.id, page1.id, page2.id]
      assert {:ok, reordered_pages} = Forms.reorder_form_pages(form.id, page_ids)
      
      # 验证新顺序
      assert length(reordered_pages) == 3
      [p1, p2, p3] = reordered_pages
      
      assert p1.id == page3.id
      assert p1.order == 1
      
      assert p2.id == page1.id
      assert p2.order == 2
      
      assert p3.id == page2.id
      assert p3.order == 3
    end

    test "assign_default_page/1 为表单创建默认页面", %{form: form} do
      # 为表单创建默认页面
      assert {:ok, %FormPage{} = page} = Forms.assign_default_page(form)
      
      # 验证默认页面属性
      assert page.title == "默认页面"
      assert page.order == 1
      assert page.form_id == form.id
      
      # 验证重复调用会返回已存在的页面
      assert {:ok, existing_page} = Forms.assign_default_page(form)
      assert existing_page.id == page.id
    end

    test "migrate_items_to_default_page/1 将现有表单项迁移到默认页面", %{form: form} do
      # 创建几个不属于任何页面的表单项
      item1 = form_item_fixture(form, %{label: "项目1", type: :text_input})
      item2 = form_item_fixture(form, %{label: "项目2", type: :radio})
      
      # 创建默认页面
      {:ok, page} = Forms.assign_default_page(form)
      
      # 迁移表单项到默认页面
      assert {:ok, migrated_items} = Forms.migrate_items_to_default_page(form)
      
      # 验证所有表单项已迁移
      assert length(migrated_items) == 2
      assert Enum.all?(migrated_items, fn item -> item.page_id == page.id end)
      
      # 获取更新后的表单项验证page_id
      updated_item1 = Forms.get_form_item(item1.id)
      updated_item2 = Forms.get_form_item(item2.id)
      assert updated_item1.page_id == page.id
      assert updated_item2.page_id == page.id
    end
  end

  describe "form_items_with_pages" do
    setup do
      user = user_fixture()
      form = form_fixture(%{user_id: user.id})
      
      # 创建两个页面
      {:ok, page1} = Forms.create_form_page(form, %{title: "第一页", order: 1})
      {:ok, page2} = Forms.create_form_page(form, %{title: "第二页", order: 2})
      
      %{user: user, form: form, page1: page1, page2: page2}
    end

    test "add_form_item/2 支持指定页面", %{form: form, page1: page} do
      # 添加指定页面的表单项
      attrs = %{
        label: "带页面的表单项",
        type: :text_input,
        required: true,
        page_id: page.id
      }
      
      assert {:ok, %FormItem{} = item} = Forms.add_form_item(form, attrs)
      assert item.page_id == page.id
      
      # 不指定页面时应该为nil
      attrs_no_page = %{
        label: "无页面的表单项",
        type: :text_input
      }
      
      # 现在应该自动分配到默认页面，而不是为nil
      assert {:ok, %FormItem{} = item_no_page} = Forms.add_form_item(form, attrs_no_page)
      assert item_no_page.page_id != nil
    end

    test "move_item_to_page/2 将表单项移动到其他页面", %{form: form, page1: page1, page2: page2} do
      # 创建一个表单项，指定在page1
      {:ok, item} = Forms.add_form_item(form, %{
        label: "测试项",
        type: :text_input,
        page_id: page1.id
      })
      
      # 移动到page2
      assert {:ok, %FormItem{} = moved_item} = Forms.move_item_to_page(item.id, page2.id)
      assert moved_item.page_id == page2.id
      
      # 验证移动成功
      updated_item = Forms.get_form_item(item.id)
      assert updated_item.page_id == page2.id
    end

    test "list_page_items/1 获取页面中的所有表单项", %{form: form, page1: page} do
      # 创建几个属于该页面的表单项
      {:ok, item1} = Forms.add_form_item(form, %{label: "页面项目1", type: :text_input, page_id: page.id})
      {:ok, item2} = Forms.add_form_item(form, %{label: "页面项目2", type: :radio, page_id: page.id})
      
      # 创建一个不属于该页面的表单项
      {:ok, _} = Forms.add_form_item(form, %{label: "其他页面项目", type: :text_input})
      
      # 获取页面表单项
      items = Forms.list_page_items(page.id)
      
      # 验证结果
      assert length(items) == 2
      assert Enum.map(items, & &1.id) |> Enum.sort() == [item1.id, item2.id] |> Enum.sort()
    end

    test "get_form/1 预加载页面及其表单项", %{form: form, page1: page1, page2: page2} do
      # 为两个页面添加表单项
      {:ok, _} = Forms.add_form_item(form, %{label: "页面1项目1", type: :text_input, page_id: page1.id})
      {:ok, _} = Forms.add_form_item(form, %{label: "页面1项目2", type: :radio, page_id: page1.id})
      {:ok, _} = Forms.add_form_item(form, %{label: "页面2项目1", type: :text_input, page_id: page2.id})
      
      # 获取完整表单
      loaded_form = Forms.get_form(form.id)
      
      # 验证页面已预加载
      assert Enum.count(loaded_form.pages) == 2
      
      # 验证每个页面的表单项已预加载
      page1_loaded = Enum.find(loaded_form.pages, & &1.id == page1.id)
      page2_loaded = Enum.find(loaded_form.pages, & &1.id == page2.id)
      
      assert length(page1_loaded.items) == 2
      assert length(page2_loaded.items) == 1
    end
  end
end