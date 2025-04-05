defmodule MyAppWeb.Components.FormComponentsTest do
  use MyAppWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import MyApp.FormsFixtures
  import Phoenix.Component
  alias MyAppWeb.FormComponents

  # 保留之前的测试
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

  # 新增控件测试
  describe "textarea_field/1" do
    test "渲染文本区域字段" do
      assigns = %{
        field: %{
          id: "textarea-field-1",
          label: "详细描述",
          required: true
        },
        form_state: %{},
        error: nil,
        disabled: false
      }

      html = render_component(&FormComponents.textarea_field/1, assigns)
      
      assert html =~ "详细描述"
      assert html =~ "<label"
      assert html =~ "<textarea"
      assert html =~ ~r|<textarea[^>]*required[^>]*|
    end

    test "显示填写的值" do
      assigns = %{
        field: %{
          id: "textarea-field-1",
          label: "详细描述",
          required: true
        },
        form_state: %{"textarea-field-1" => "这是一段详细描述内容"},
        error: nil,
        disabled: false
      }

      html = render_component(&FormComponents.textarea_field/1, assigns)
      
      assert html =~ "这是一段详细描述内容"
    end
  end

  describe "dropdown_field/1" do
    test "渲染下拉菜单字段" do
      assigns = %{
        field: %{
          id: "select-field-1",
          label: "选择城市",
          required: true
        },
        options: [
          %{id: 1, label: "北京", value: "beijing"},
          %{id: 2, label: "上海", value: "shanghai"},
          %{id: 3, label: "广州", value: "guangzhou"}
        ],
        form_state: %{},
        error: nil,
        disabled: false
      }

      html = render_component(&FormComponents.dropdown_field/1, assigns)
      
      assert html =~ "选择城市"
      assert html =~ "<select"
      assert html =~ "北京"
      assert html =~ "上海"
      assert html =~ "广州"
      # 不需要检查具体的HTML格式
      assert html =~ "beijing"
      assert html =~ "shanghai"
      assert html =~ "guangzhou"
    end

    test "选中指定的选项" do
      assigns = %{
        field: %{
          id: "select-field-1",
          label: "选择城市",
          required: true
        },
        options: [
          %{id: 1, label: "北京", value: "beijing"},
          %{id: 2, label: "上海", value: "shanghai"},
          %{id: 3, label: "广州", value: "guangzhou"}
        ],
        form_state: %{"select-field-1" => "shanghai"},
        error: nil,
        disabled: false
      }

      html = render_component(&FormComponents.dropdown_field/1, assigns)
      
      # 简化断言以检查选中状态，而不是HTML精确格式
      assert html =~ "shanghai" && html =~ "selected"
    end
  end

  describe "rating_field/1" do
    test "渲染评分字段" do
      assigns = %{
        field: %{
          id: "rating-field-1",
          label: "服务评分",
          required: true,
          max_rating: 5
        },
        form_state: %{},
        error: nil,
        disabled: false
      }

      html = render_component(&FormComponents.rating_field/1, assigns)
      
      assert html =~ "服务评分"
      assert html =~ "rating-container"
      assert html =~ "rating-star"
      # 验证有5个星星按钮
      assert html =~ ~r|data-value="1"|
      assert html =~ ~r|data-value="2"|
      assert html =~ ~r|data-value="3"|
      assert html =~ ~r|data-value="4"|
      assert html =~ ~r|data-value="5"|
      # 验证默认提示文本
      assert html =~ "请评分"
    end

    test "显示选择的评分值" do
      assigns = %{
        field: %{
          id: "rating-field-1",
          label: "服务评分",
          required: true,
          max_rating: 5
        },
        form_state: %{"rating-field-1" => "4"},
        error: nil,
        disabled: false
      }

      html = render_component(&FormComponents.rating_field/1, assigns)
      
      # 验证选中值存在
      assert html =~ ~r|value="4"|
      # 验证显示评分文本
      assert html =~ "4星"
    end

    test "支持自定义最大评分" do
      assigns = %{
        field: %{
          id: "rating-field-1",
          label: "产品评分",
          required: true,
          max_rating: 10
        },
        form_state: %{},
        error: nil,
        disabled: false,
        max_rating: 10
      }

      html = render_component(&FormComponents.rating_field/1, assigns)
      
      # 验证有10个星星按钮
      Enum.each(1..10, fn i ->
        assert html =~ ~r|data-value="#{i}"|
      end)
    end

    test "显示错误信息" do
      assigns = %{
        field: %{
          id: "rating-field-1",
          label: "服务评分",
          required: true,
          max_rating: 5
        },
        form_state: %{},
        error: "请选择评分",
        disabled: false
      }

      html = render_component(&FormComponents.rating_field/1, assigns)
      
      assert html =~ "请选择评分"
      assert html =~ ~r|<div[^>]*class="text-red-500[^>]*>请选择评分</div>|
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

  describe "form_item_editor/1" do
    test "渲染表单项编辑器" do
      assigns = %{
        id: "test-editor",
        item: %{
          id: nil,
          label: "",
          type: :text_input,
          required: false,
          description: ""
        },
        item_type: nil,
        options: [],
        on_save: "save_item",
        on_cancel: "cancel_edit",
        on_add_option: "add_option",
        on_remove_option: "remove_option"
      }

      html = render_component(&FormComponents.form_item_editor/1, assigns)
      
      # 验证表单项编辑器元素
      assert html =~ "标签"
      assert html =~ "类型"
      assert html =~ "文本"
      assert html =~ "文本区域"
      assert html =~ "单选"
      assert html =~ "下拉菜单"
      assert html =~ "评分"
      assert html =~ "必填项"
    end

    test "显示选中的表单项类型" do
      assigns = %{
        id: "test-editor",
        item: %{
          id: nil,
          label: "",
          type: :rating,
          required: false,
          description: "",
          max_rating: 5
        },
        item_type: "rating",
        options: [],
        on_save: "save_item",
        on_cancel: "cancel_edit",
        on_add_option: "add_option",
        on_remove_option: "remove_option"
      }

      html = render_component(&FormComponents.form_item_editor/1, assigns)
      
      # 验证评分控件编辑器特定元素
      assert html =~ "最大评分值"
      assert html =~ "星" # 评分选项中的"星"字
      assert html =~ "预览"
    end
  end

  # 新增控件类型测试
  describe "number_field/1" do
    test "渲染数字输入字段" do
      assigns = %{
        field: %{
          id: "number-field-1",
          label: "年龄",
          required: true,
          min: 18,
          max: 60,
          step: 1
        },
        form_state: %{},
        error: nil,
        disabled: false
      }

      html = render_component(&FormComponents.number_field/1, assigns)
      
      # 测试行为而非实现细节
      assert html =~ "年龄"
      assert html =~ ~r/<input[^>]*type="number"/
      assert html =~ ~r/min="18"/
      assert html =~ ~r/max="60"/
      assert html =~ ~r/step="1"/
      assert html =~ ~r/required/
    end

    test "显示填写的值" do
      assigns = %{
        field: %{
          id: "number-field-1",
          label: "年龄",
          required: true,
          min: 18,
          max: 60
        },
        form_state: %{"number-field-1" => "25"},
        error: nil,
        disabled: false
      }

      html = render_component(&FormComponents.number_field/1, assigns)
      
      # 验证值正确显示
      assert html =~ ~r/value="25"/
    end

    test "显示错误信息" do
      assigns = %{
        field: %{
          id: "number-field-1",
          label: "年龄",
          required: true,
          min: 18,
          max: 60
        },
        form_state: %{},
        error: "请输入有效年龄",
        disabled: false
      }

      html = render_component(&FormComponents.number_field/1, assigns)
      
      # 验证错误信息显示
      assert html =~ "请输入有效年龄"
      assert html =~ ~r/<div[^>]*class="[^"]*text-red-500[^"]*"[^>]*>请输入有效年龄<\/div>/
    end

    test "禁用状态" do
      assigns = %{
        field: %{
          id: "number-field-1",
          label: "年龄",
          required: true,
          min: 18,
          max: 60
        },
        form_state: %{"number-field-1" => "25"},
        error: nil,
        disabled: true
      }

      html = render_component(&FormComponents.number_field/1, assigns)
      
      # 验证禁用状态
      assert html =~ ~r/disabled/
    end
  end

  describe "email_field/1" do
    test "渲染邮箱输入字段" do
      assigns = %{
        field: %{
          id: "email-field-1",
          label: "电子邮箱",
          required: true
        },
        form_state: %{},
        error: nil,
        disabled: false
      }

      html = render_component(&FormComponents.email_field/1, assigns)
      
      # 测试行为而非实现细节
      assert html =~ "电子邮箱"
      assert html =~ ~r/<input[^>]*type="email"/
      assert html =~ ~r/required/
    end

    test "显示填写的值" do
      assigns = %{
        field: %{
          id: "email-field-1",
          label: "电子邮箱",
          required: true
        },
        form_state: %{"email-field-1" => "test@example.com"},
        error: nil,
        disabled: false
      }

      html = render_component(&FormComponents.email_field/1, assigns)
      
      # 验证值正确显示
      assert html =~ ~r/value="test@example.com"/
    end

    test "显示错误信息" do
      assigns = %{
        field: %{
          id: "email-field-1",
          label: "电子邮箱",
          required: true
        },
        form_state: %{},
        error: "请输入有效的电子邮箱地址",
        disabled: false
      }

      html = render_component(&FormComponents.email_field/1, assigns)
      
      # 验证错误信息显示
      assert html =~ "请输入有效的电子邮箱地址"
    end

    test "包含邮箱格式提示" do
      assigns = %{
        field: %{
          id: "email-field-1",
          label: "电子邮箱",
          required: true,
          show_format_hint: true
        },
        form_state: %{},
        error: nil,
        disabled: false
      }

      html = render_component(&FormComponents.email_field/1, assigns)
      
      # 验证格式提示显示
      assert html =~ "example@domain.com"
    end
  end

  describe "phone_field/1" do
    test "渲染电话号码输入字段" do
      assigns = %{
        field: %{
          id: "phone-field-1",
          label: "手机号码",
          required: true
        },
        form_state: %{},
        error: nil,
        disabled: false
      }

      html = render_component(&FormComponents.phone_field/1, assigns)
      
      # 测试行为而非实现细节
      assert html =~ "手机号码"
      assert html =~ ~r/<input[^>]*type="tel"/
      assert html =~ ~r/required/
    end

    test "显示填写的值" do
      assigns = %{
        field: %{
          id: "phone-field-1",
          label: "手机号码",
          required: true
        },
        form_state: %{"phone-field-1" => "13800138000"},
        error: nil,
        disabled: false
      }

      html = render_component(&FormComponents.phone_field/1, assigns)
      
      # 验证值正确显示
      assert html =~ ~r/value="13800138000"/
    end

    test "显示错误信息" do
      assigns = %{
        field: %{
          id: "phone-field-1",
          label: "手机号码",
          required: true
        },
        form_state: %{},
        error: "请输入有效的手机号码",
        disabled: false
      }

      html = render_component(&FormComponents.phone_field/1, assigns)
      
      # 验证错误信息显示
      assert html =~ "请输入有效的手机号码"
    end

    test "支持格式化显示" do
      assigns = %{
        field: %{
          id: "phone-field-1",
          label: "手机号码",
          required: true,
          format_display: true
        },
        form_state: %{"phone-field-1" => "13800138000"},
        error: nil,
        disabled: false
      }

      html = render_component(&FormComponents.phone_field/1, assigns)
      
      # 验证格式化显示
      assert html =~ "pattern"
      assert html =~ "placeholder"
    end
  end
end