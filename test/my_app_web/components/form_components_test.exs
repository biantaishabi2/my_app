defmodule MyAppWeb.FormComponentsTest do
  use MyAppWeb.ConnCase, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import MyApp.FormsFixtures

  alias MyAppWeb.FormComponents

  describe "form_header/1" do
    test "渲染表单标题和描述" do
      assigns = %{
        title: "测试表单",
        description: "这是一个测试表单的描述"
      }

      html = render_component(&FormComponents.form_header/1, assigns)
      
      assert html =~ "测试表单"
      assert html =~ "这是一个测试表单的描述"
      assert html =~ ~r|<h1[^>]*>测试表单</h1>|
      assert html =~ ~r|<p[^>]*>这是一个测试表单的描述</p>|
    end

    test "如果没有描述，只渲染标题" do
      assigns = %{
        title: "测试表单",
        description: nil
      }

      html = render_component(&FormComponents.form_header/1, assigns)
      
      assert html =~ "测试表单"
      refute html =~ "<p"
    end
  end

  describe "text_input_field/1" do
    test "渲染文本输入字段" do
      assigns = %{
        id: "text-field-1",
        label: "姓名",
        placeholder: "请输入您的姓名",
        required: true,
        value: nil,
        errors: []
      }

      html = render_component(&FormComponents.text_input_field/1, assigns)
      
      assert html =~ "姓名"
      assert html =~ "请输入您的姓名"
      assert html =~ ~r|<label[^>]*>姓名</label>|
      assert html =~ ~r|<input[^>]*type="text"[^>]*|
      assert html =~ ~r|<input[^>]*placeholder="请输入您的姓名"[^>]*|
      assert html =~ ~r|<input[^>]*required[^>]*|
      assert html =~ ~r|<span[^>]*class="required-mark"[^>]*>\*</span>|
    end

    test "显示填写的值" do
      assigns = %{
        id: "text-field-1",
        label: "姓名",
        placeholder: "请输入您的姓名",
        required: true,
        value: "张三",
        errors: []
      }

      html = render_component(&FormComponents.text_input_field/1, assigns)
      
      assert html =~ ~r|<input[^>]*value="张三"[^>]*|
    end

    test "显示错误信息" do
      assigns = %{
        id: "text-field-1",
        label: "姓名",
        placeholder: "请输入您的姓名",
        required: true,
        value: "",
        errors: ["此字段为必填项"]
      }

      html = render_component(&FormComponents.text_input_field/1, assigns)
      
      assert html =~ "此字段为必填项"
      assert html =~ ~r|<div[^>]*class="error-message"[^>]*>此字段为必填项</div>|
      assert html =~ ~r|<div[^>]*class="field-error"[^>]*>|
    end
  end

  describe "radio_field/1" do
    test "渲染单选按钮字段" do
      assigns = %{
        id: "radio-field-1",
        label: "性别",
        required: true,
        options: [
          %{label: "男", value: "male"},
          %{label: "女", value: "female"}
        ],
        value: nil,
        errors: []
      }

      html = render_component(&FormComponents.radio_field/1, assigns)
      
      assert html =~ "性别"
      assert html =~ "男"
      assert html =~ "女"
      assert html =~ ~r|<label[^>]*>性别</label>|
      assert html =~ ~r|<input[^>]*type="radio"[^>]*value="male"[^>]*|
      assert html =~ ~r|<input[^>]*type="radio"[^>]*value="female"[^>]*|
      assert html =~ ~r|<span[^>]*class="required-mark"[^>]*>\*</span>|
    end

    test "选中指定的选项" do
      assigns = %{
        id: "radio-field-1",
        label: "性别",
        required: true,
        options: [
          %{label: "男", value: "male"},
          %{label: "女", value: "female"}
        ],
        value: "female",
        errors: []
      }

      html = render_component(&FormComponents.radio_field/1, assigns)
      
      assert html =~ ~r|<input[^>]*type="radio"[^>]*value="male"[^>]*|
      assert html =~ ~r|<input[^>]*type="radio"[^>]*value="female"[^>]*checked[^>]*|
    end

    test "显示错误信息" do
      assigns = %{
        id: "radio-field-1",
        label: "性别",
        required: true,
        options: [
          %{label: "男", value: "male"},
          %{label: "女", value: "female"}
        ],
        value: nil,
        errors: ["请选择一个选项"]
      }

      html = render_component(&FormComponents.radio_field/1, assigns)
      
      assert html =~ "请选择一个选项"
      assert html =~ ~r|<div[^>]*class="error-message"[^>]*>请选择一个选项</div>|
      assert html =~ ~r|<div[^>]*class="field-error"[^>]*>|
    end
  end

  describe "form_builder/1" do
    test "渲染表单构建器" do
      # 创建测试表单和表单项
      form = form_fixture(%{title: "测试表单", description: "测试描述"})
      text_item = form_item_fixture(form, %{label: "文本问题", type: :text_input, required: true})
      radio_item = form_item_fixture(form, %{label: "单选问题", type: :radio, required: true})
      option1 = item_option_fixture(radio_item, %{label: "选项1", value: "option1"})
      option2 = item_option_fixture(radio_item, %{label: "选项2", value: "option2"})
      
      assigns = %{
        form: form,
        items: [text_item, radio_item],
        editable: true
      }

      html = render_component(&FormComponents.form_builder/1, assigns)
      
      # 验证表单标题和描述
      assert html =~ form.title
      assert html =~ form.description
      
      # 验证表单项渲染
      assert html =~ "文本问题"
      assert html =~ "单选问题"
      
      # 验证编辑按钮存在（因为 editable 为 true）
      assert html =~ "编辑"
      assert html =~ "删除"
    end

    test "非编辑模式不显示编辑按钮" do
      # 创建测试表单和表单项
      form = form_fixture(%{title: "测试表单", description: "测试描述"})
      text_item = form_item_fixture(form, %{label: "文本问题", type: :text_input, required: true})
      
      assigns = %{
        form: form,
        items: [text_item],
        editable: false
      }

      html = render_component(&FormComponents.form_builder/1, assigns)
      
      # 验证表单项渲染
      assert html =~ "文本问题"
      
      # 验证编辑按钮不存在
      refute html =~ "编辑"
      refute html =~ "删除"
    end

    test "没有表单项时显示提示信息" do
      # 创建测试表单，但不添加表单项
      form = form_fixture(%{title: "空表单", description: "没有表单项"})
      
      assigns = %{
        form: form,
        items: [],
        editable: true
      }

      html = render_component(&FormComponents.form_builder/1, assigns)
      
      # 验证显示无表单项提示
      assert html =~ "此表单尚未添加任何问题"
    end
  end
end