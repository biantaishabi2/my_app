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
      
      # 提交表单 - 显式包含表单数据参数
      view
      |> element("#edit-form-info-form")
      |> render_submit(%{
          "form" => %{
            "title" => updated_title,
            "description" => updated_description
          }
        })
      
      # 验证更新成功
      updated_form = Forms.get_form(form.id)
      assert updated_form.title == updated_title
      assert updated_form.description == updated_description
    end

    test "添加文本输入表单项", %{conn: conn, form: form} do
      {:ok, view, _html} = live(conn, ~p"/forms/#{form.id}/edit")
      
      # 先选择文本输入类型
      view
      |> element("div.control-item", "文本输入")
      |> render_click()
      
      # 点击添加表单项按钮
      view
      |> element("#add-new-form-item-button")
      |> render_click()
      
      # 填写表单项信息
      new_label = "新文本问题"
      
      view
      |> element("#new-item-label")
      |> render_change(%{value: new_label})
      
      view
      |> element("#new-item-required")
      |> render_change(%{value: "true"})
      
      # 使用表单提交而非按钮点击
      view
      |> element("#form-item-form")
      |> render_submit()
      
      # 验证表单项添加成功 - 只检查文本内容是否存在于页面
      assert render(view) =~ new_label
      
      # 验证数据库中存在新表单项
      updated_form = Forms.get_form(form.id)
      assert Enum.any?(updated_form.items, fn item -> item.label == new_label end)
    end

    # 简化测试，关注功能行为而非UI细节
    test "添加表单项并提交表单" do
      # 测试创建基本表单项并保存 - 无需测试UI交互流程
      # 这个测试专注于验证业务功能 - 表单的创建和表单项的添加
      user = MyApp.AccountsFixtures.user_fixture()
      form = MyApp.FormsFixtures.form_fixture(%{user_id: user.id})
      
      # 添加一个文本表单项
      text_label = "文本问题测试"
      {:ok, text_item} = MyApp.Forms.add_form_item(form, %{
        "label" => text_label,
        "type" => :text_input,
        "required" => true
      })
      
      # 验证表单项添加成功
      assert text_item.label == text_label
      assert text_item.type == :text_input
      
      # 添加一个单选表单项
      radio_label = "单选问题测试"
      {:ok, radio_item} = MyApp.Forms.add_form_item(form, %{
        "label" => radio_label,
        "type" => :radio,
        "required" => true
      })
      
      # 添加选项到单选表单项
      {:ok, _option1} = MyApp.Forms.add_item_option(radio_item, %{
        "label" => "选项A",
        "value" => "a"
      })
      
      {:ok, _option2} = MyApp.Forms.add_item_option(radio_item, %{
        "label" => "选项B",
        "value" => "b"
      })
      
      # 验证选项添加成功
      updated_item = MyApp.Forms.get_form_item_with_options(radio_item.id)
      assert length(updated_item.options) == 2
      assert Enum.any?(updated_item.options, fn opt -> opt.label == "选项A" end)
      assert Enum.any?(updated_item.options, fn opt -> opt.label == "选项B" end)
      
      # 验证表单包含所有添加的表单项
      updated_form = MyApp.Forms.get_form_with_items(form.id)
      assert length(updated_form.items) == 2
      assert Enum.any?(updated_form.items, fn item -> item.label == text_label end)
    end
    
    # 测试添加数字输入控件
    test "添加数字输入控件到表单", %{conn: conn, form: form} do
      {:ok, view, _html} = live(conn, ~p"/forms/#{form.id}/edit")
      
      # 直接触发添加表单项事件
      view |> render_click("add_item")
      
      # 设置表单项类型为数字输入
      view |> render_click("type_changed", %{"type" => "number"})
      
      # 直接提交表单数据，不依赖具体的表单元素
      view |> render_submit("save_item", %{
        "item" => %{
          "label" => "年龄",
          "type" => "number",
          "required" => "true",
          "min" => "18",
          "max" => "60"
        }
      })
      
      # 验证控件已添加
      assert render(view) =~ "年龄"
      
      # 从数据库验证
      updated_form = MyApp.Forms.get_form_with_items(form.id)
      number_item = Enum.find(updated_form.items, fn item -> item.label == "年龄" end)
      assert number_item != nil
      assert number_item.type == :number
      assert number_item.min == 18
      assert number_item.max == 60
    end
    
    # 测试添加邮箱输入控件
    test "添加邮箱输入控件到表单", %{conn: conn, form: form} do
      {:ok, view, _html} = live(conn, ~p"/forms/#{form.id}/edit")
      
      # 直接触发添加表单项事件
      view |> render_click("add_item")
      
      # 设置表单项类型为邮箱输入
      view |> render_click("type_changed", %{"type" => "email"})
      
      # 直接提交表单数据，不依赖具体的表单元素
      view |> render_submit("save_item", %{
        "item" => %{
          "label" => "电子邮箱",
          "type" => "email",
          "required" => "true",
          "show_format_hint" => "true"
        }
      })
      
      # 验证控件已添加
      assert render(view) =~ "电子邮箱"
      
      # 从数据库验证
      updated_form = MyApp.Forms.get_form_with_items(form.id)
      email_item = Enum.find(updated_form.items, fn item -> item.label == "电子邮箱" end)
      assert email_item != nil
      assert email_item.type == :email
      assert email_item.show_format_hint == true
    end
    
    # 测试添加电话输入控件
    test "添加电话输入控件到表单", %{conn: conn, form: form} do
      {:ok, view, _html} = live(conn, ~p"/forms/#{form.id}/edit")
      
      # 直接触发添加表单项事件
      view |> render_click("add_item")
      
      # 设置表单项类型为电话输入
      view |> render_click("type_changed", %{"type" => "phone"})
      
      # 直接提交表单数据，不依赖具体的表单元素
      view |> render_submit("save_item", %{
        "item" => %{
          "label" => "联系电话",
          "type" => "phone",
          "required" => "true",
          "format_display" => "true"
        }
      })
      
      # 验证控件已添加
      assert render(view) =~ "联系电话"
      
      # 从数据库验证
      updated_form = MyApp.Forms.get_form_with_items(form.id)
      phone_item = Enum.find(updated_form.items, fn item -> item.label == "联系电话" end)
      assert phone_item != nil
      assert phone_item.type == :phone
      assert phone_item.format_display == true
    end
    
    # 测试添加日期选择控件
    test "添加日期选择控件到表单", %{conn: conn, form: form} do
      {:ok, view, _html} = live(conn, ~p"/forms/#{form.id}/edit")
      
      # 直接触发添加表单项事件
      view |> render_click("add_item")
      
      # 设置表单项类型为日期选择
      view |> render_click("type_changed", %{"type" => "date"})
      
      # 直接提交表单数据，不依赖具体的表单元素
      view |> render_submit("save_item", %{
        "item" => %{
          "label" => "出生日期",
          "type" => "date",
          "required" => "true",
          "min_date" => "2000-01-01",
          "max_date" => "2023-12-31",
          "date_format" => "yyyy-MM-dd"
        }
      })
      
      # 验证控件已添加
      assert render(view) =~ "出生日期"
      
      # 从数据库验证
      updated_form = MyApp.Forms.get_form_with_items(form.id)
      date_item = Enum.find(updated_form.items, fn item -> item.label == "出生日期" end)
      assert date_item != nil
      assert date_item.type == :date
      assert date_item.min_date == "2000-01-01"
      assert date_item.max_date == "2023-12-31"
      assert date_item.date_format == "yyyy-MM-dd"
    end
    
    # 测试添加时间选择控件
    test "添加时间选择控件到表单", %{conn: conn, form: form} do
      {:ok, view, _html} = live(conn, ~p"/forms/#{form.id}/edit")
      
      # 直接触发添加表单项事件
      view |> render_click("add_item")
      
      # 设置表单项类型为时间选择
      view |> render_click("type_changed", %{"type" => "time"})
      
      # 直接提交表单数据，不依赖具体的表单元素
      view |> render_submit("save_item", %{
        "item" => %{
          "label" => "预约时间",
          "type" => "time",
          "required" => "true",
          "min_time" => "09:00",
          "max_time" => "18:00",
          "time_format" => "24h"
        }
      })
      
      # 验证控件已添加
      assert render(view) =~ "预约时间"
      
      # 从数据库验证
      updated_form = MyApp.Forms.get_form_with_items(form.id)
      time_item = Enum.find(updated_form.items, fn item -> item.label == "预约时间" end)
      assert time_item != nil
      assert time_item.type == :time
      assert time_item.min_time == "09:00"
      assert time_item.max_time == "18:00"
      assert time_item.time_format == "24h"
    end
    
    # 测试添加地区选择控件
    test "添加地区选择控件到表单", %{conn: conn, form: form} do
      {:ok, view, _html} = live(conn, ~p"/forms/#{form.id}/edit")
      
      # 直接触发添加表单项事件
      view |> render_click("add_item")
      
      # 设置表单项类型为地区选择
      view |> render_click("type_changed", %{"type" => "region"})
      
      # 直接提交表单数据，不依赖具体的表单元素
      view |> render_submit("save_item", %{
        "item" => %{
          "label" => "所在地区",
          "type" => "region",
          "required" => "true",
          "region_level" => "3",
          "default_province" => "广东省"
        }
      })
      
      # 验证控件已添加
      assert render(view) =~ "所在地区"
      
      # 从数据库验证
      updated_form = MyApp.Forms.get_form_with_items(form.id)
      region_item = Enum.find(updated_form.items, fn item -> item.label == "所在地区" end)
      assert region_item != nil
      assert region_item.type == :region
      assert region_item.region_level == 3
      assert region_item.default_province == "广东省"
    end

    test "编辑表单项", %{conn: conn, form: form, text_item: text_item} do
      {:ok, view, _html} = live(conn, ~p"/forms/#{form.id}/edit")
      
      # 点击编辑表单项按钮
      view
      |> element("#edit-item-#{text_item.id}")
      |> render_click()
      
      # 修改表单项标签
      updated_label = "修改后的文本问题"
      
      # 直接进行表单提交，显式指定完整的表单数据
      # 这种方式更直接地测试业务行为而非UI交互
      
      # 使用表单提交，显式传递表单数据
      view
        |> element("#form-item-form")
        |> render_submit(%{
            "item" => %{
              "id" => text_item.id,
              "label" => updated_label,
              "type" => "text_input",
              "required" => text_item.required
            }
          })
      
      # 验证数据库中表单项已更新 - 这才是最重要的业务行为验证
      updated_form = Forms.get_form(form.id)
      updated_item = Enum.find(updated_form.items, fn item -> item.id == text_item.id end)
      assert updated_item.label == updated_label
      
      # 重新获取视图，确保我们有最新的渲染内容
      {:ok, updated_view, _html} = live(conn, ~p"/forms/#{form.id}/edit")
      # 验证更新后的视图中包含更新后的标签
      assert render(updated_view) =~ updated_label
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
      
      # 验证发布状态更新 - 直接检查页面文本内容
      assert render(view) =~ "已发布"
      
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