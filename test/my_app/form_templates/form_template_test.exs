defmodule MyApp.FormTemplates.FormTemplateTest do
  use ExUnit.Case
  alias MyApp.FormTemplates.FormTemplate
  alias MyApp.Forms.FormLogic

  # 假设 FormTemplate 模块有一个 render/2 函数，接收一个 FormTemplate 结构体和一个 Form 结构体，返回渲染后的 HTML 字符串。
  # 这里我们主要测试 render/2 函数的逻辑，而不是实际的 HTML 输出。

  describe "render/2 - Template Structure Tests" do
    test "renders elements in the correct order" do
      template = %FormTemplate{
        structure: [
          %{type: "text", name: "field1", label: "Field 1"},
          %{type: "text", name: "field2", label: "Field 2"},
          %{type: "text", name: "field3", label: "Field 3"}
        ]
      }
      form_data = %{}

      rendered_html = FormTemplate.render(template, form_data)

      # 这里我们假设 render/2 函数会在生成的 HTML 中包含元素的 name 属性。
      # 我们检查这些 name 属性是否按照模板中定义的顺序出现。
      assert rendered_html =~ ~r/name="field1".*name="field2".*name="field3"/s
    end

    test "renders elements with the correct type" do
      template = %FormTemplate{
        structure: [
          %{type: "text", name: "field1", label: "Field 1"},
          %{type: "number", name: "field2", label: "Field 2"},
          %{type: "select", name: "field3", label: "Field 3", options: ["Option 1", "Option 2"]}
        ]
      }
      form_data = %{}

      rendered_html = FormTemplate.render(template, form_data)

      # 检查每个元素的 type 属性是否正确。
      assert rendered_html =~ ~r/type="text"/
      assert rendered_html =~ ~r/type="number"/
      assert rendered_html =~ ~r/type="select"/
    end
  end

  describe "render/2 - Conditional Rendering Tests" do
    test "renders elements only when their conditions are met" do
      template = %FormTemplate{
        structure: [
          %{type: "text", name: "field1", label: "Field 1"},
          %{
            type: "text",
            name: "field2",
            label: "Field 2",
            condition: %{
              operator: "==",
              left: %{type: "field", name: "field1"},
              right: %{type: "value", value: "show"}
            }
          },
          %{
            type: "text",
            name: "field3",
            label: "Field 3",
            condition: %{
              operator: "==",
              left: %{type: "field", name: "field1"},
              right: %{type: "value", value: "hide"}
            }
          }
        ]
      }

      # 当 field1 的值为 "show" 时，field2 应该显示，field3 应该隐藏。
      form_data_show = %{"field1" => "show"}
      rendered_html_show = FormTemplate.render(template, form_data_show)
      assert rendered_html_show =~ ~r/name="field2"/
      refute rendered_html_show =~ ~r/name="field3"/

      # 当 field1 的值为 "hide" 时，field2 应该隐藏，field3 应该显示。
      form_data_hide = %{"field1" => "hide"}
      rendered_html_hide = FormTemplate.render(template, form_data_hide)
      refute rendered_html_hide =~ ~r/name="field2"/
      assert rendered_html_hide =~ ~r/name="field3"/
    end

    test "handles nested conditions correctly" do
      template = %FormTemplate{
        structure: [
          %{type: "text", name: "field1", label: "Field 1"},
          %{
            type: "text",
            name: "field2",
            label: "Field 2",
            condition: %{
              operator: "and",
              conditions: [
                %{
                  operator: "==",
                  left: %{type: "field", name: "field1"},
                  right: %{type: "value", value: "show"}
                },
                %{
                  operator: ">",
                  left: %{type: "field", name: "field3"},
                  right: %{type: "value", value: 10}
                }
              ]
            }
          }
        ]
      }

      # 当 field1 的值为 "show" 且 field3 的值大于 10 时，field2 应该显示。
      form_data_show = %{"field1" => "show", "field3" => 15}
      rendered_html_show = FormTemplate.render(template, form_data_show)
      assert rendered_html_show =~ ~r/name="field2"/

      # 当 field1 的值不是 "show" 时，field2 应该隐藏。
      form_data_hide1 = %{"field1" => "hide", "field3" => 15}
      rendered_html_hide1 = FormTemplate.render(template, form_data_hide1)
      refute rendered_html_hide1 =~ ~r/name="field2"/

      # 当 field3 的值不大于 10 时，field2 应该隐藏。
      form_data_hide2 = %{"field1" => "show", "field3" => 5}
      rendered_html_hide2 = FormTemplate.render(template, form_data_hide2)
      refute rendered_html_hide2 =~ ~r/name="field2"/
    end
  end

  describe "render/2 - Data Handling Tests" do
    test "uses data from the form instance" do
      template = %FormTemplate{
        structure: [
          %{type: "text", name: "field1", label: "Field 1"},
          %{type: "text", name: "field2", label: "Field 2"}
        ]
      }
      form_data = %{"field1" => "value1", "field2" => "value2"}

      rendered_html = FormTemplate.render(template, form_data)

      # 检查每个元素的 value 属性是否正确。
      assert rendered_html =~ ~r/value="value1"/
      assert rendered_html =~ ~r/value="value2"/
    end

    test "handles missing data gracefully" do
      template = %FormTemplate{
        structure: [
          %{type: "text", name: "field1", label: "Field 1"},
          %{type: "text", name: "field2", label: "Field 2"}
        ]
      }
      form_data = %{"field1" => "value1"}

      rendered_html = FormTemplate.render(template, form_data)

      # field1 应该有值，field2 应该没有值。
      assert rendered_html =~ ~r/value="value1"/
      refute rendered_html =~ ~r/value="value2"/
    end
  end
end
