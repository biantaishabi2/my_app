defmodule MyAppWeb.FormComponentsTest do
  use MyAppWeb.ConnCase, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  
  alias MyAppWeb.FormComponents
  alias MyApp.Forms.Form

  describe "form_header/1" do
    test "渲染表单标题和描述" do
      # 创建符合组件期望的表单结构
      form = %{
        title: "测试表单",
        description: "这是一个测试表单的描述"
      }
      
      assigns = %{
        form: form
      }

      html = render_component(&FormComponents.form_header/1, assigns)
      
      assert html =~ "测试表单"
      assert html =~ "这是一个测试表单的描述"
      assert html =~ ~r|<h1[^>]*>测试表单</h1>|
    end

    test "如果没有描述，只渲染标题" do
      form = %{
        title: "测试表单",
        description: nil
      }
      
      assigns = %{
        form: form
      }

      html = render_component(&FormComponents.form_header/1, assigns)
      
      assert html =~ "测试表单"
      refute html =~ "这是一个测试表单的描述"
    end
  end

  describe "text_input_field/1" do
    test "渲染文本输入字段" do
      assigns = %{
        field: %{
          id: "text-field-1",
          label: "姓名",
          required: true
        },
        form_state: %{},
        error: nil,
        disabled: false
      }

      html = render_component(&FormComponents.text_input_field/1, assigns)
      
      assert html =~ "姓名"
      assert html =~ "<label"
      assert html =~ ~r|姓名|
      assert html =~ ~r|<input[^>]*type="text"[^>]*|
      assert html =~ ~r|<input[^>]*required[^>]*|
    end

    test "显示填写的值" do
      assigns = %{
        field: %{
          id: "text-field-1",
          label: "姓名",
          required: true
        },
        form_state: %{"text-field-1" => "张三"},
        error: nil,
        disabled: false
      }

      html = render_component(&FormComponents.text_input_field/1, assigns)
      
      assert html =~ "张三"
    end

    test "显示错误信息" do
      assigns = %{
        field: %{
          id: "text-field-1",
          label: "姓名",
          required: true
        },
        form_state: %{},
        error: "此字段为必填项",
        disabled: false
      }

      html = render_component(&FormComponents.text_input_field/1, assigns)
      
      assert html =~ "此字段为必填项"
      assert html =~ ~r|<div[^>]*class="text-red-500[^>]*>此字段为必填项</div>|
    end
  end

  describe "radio_field/1" do
    test "渲染单选按钮字段" do
      assigns = %{
        field: %{
          id: "radio-field-1",
          label: "性别",
          required: true
        },
        options: [
          %{id: 1, label: "男", value: "male"},
          %{id: 2, label: "女", value: "female"}
        ],
        form_state: %{},
        error: nil,
        disabled: false
      }

      html = render_component(&FormComponents.radio_field/1, assigns)
      
      assert html =~ "性别"
      assert html =~ "男"
      assert html =~ "女"
      assert html =~ "<legend"
      assert html =~ ~r|性别|
      assert html =~ ~r|<input[^>]*type="radio"[^>]*value="male"[^>]*|
      assert html =~ ~r|<input[^>]*type="radio"[^>]*value="female"[^>]*|
    end

    test "选中指定的选项" do
      assigns = %{
        field: %{
          id: "radio-field-1",
          label: "性别",
          required: true
        },
        options: [
          %{id: 1, label: "男", value: "male"},
          %{id: 2, label: "女", value: "female"}
        ],
        form_state: %{"radio-field-1" => "female"},
        error: nil,
        disabled: false
      }

      html = render_component(&FormComponents.radio_field/1, assigns)
      
      assert html =~ ~r|<input[^>]*type="radio"[^>]*value="female"[^>]*checked[^>]*|
    end

    test "显示错误信息" do
      assigns = %{
        field: %{
          id: "radio-field-1",
          label: "性别",
          required: true
        },
        options: [
          %{id: 1, label: "男", value: "male"},
          %{id: 2, label: "女", value: "female"}
        ],
        form_state: %{},
        error: "请选择一个选项",
        disabled: false
      }

      html = render_component(&FormComponents.radio_field/1, assigns)
      
      assert html =~ "请选择一个选项"
      assert html =~ ~r|<div[^>]*class="text-red-500[^>]*>请选择一个选项</div>|
    end
  end

  describe "form_builder/1" do
    test "渲染表单构建器" do
      form = %{
        title: "测试表单",
        description: "测试描述"
      }
      
      items = [
        %{id: "item1", label: "文本问题", type: :text_input, required: true},
        %{id: "item2", label: "单选问题", type: :radio, required: true}
      ]
      
      assigns = %{
        form: form,
        items: items,
        on_add_item: nil,
        on_edit_item: fn _id -> nil end,
        on_delete_item: fn _id -> nil end
      }

      html = render_component(&FormComponents.form_builder/1, assigns)
      
      # 验证表单项渲染
      assert html =~ "文本问题"
      assert html =~ "单选问题"
      assert html =~ "添加表单项"
    end

    test "没有表单项时显示提示信息" do
      form = %{
        title: "空表单",
        description: "没有表单项"
      }
      
      assigns = %{
        form: form,
        items: [],
        on_add_item: nil,
        on_edit_item: fn _id -> nil end,
        on_delete_item: fn _id -> nil end
      }

      html = render_component(&FormComponents.form_builder/1, assigns)
      
      # 验证显示无表单项提示
      assert html =~ "还没有添加表单项"
    end
  end
end