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

  # --- 新增测试 ---
  describe "render/2 - Dynamic Numbering Tests" do
    test "adds dynamic numbers only to actual input fields, respecting visibility and order" do
      # 假设的模板结构，包含不同类型的元素和条件
      template = %FormTemplate{
        structure: [
          # 不应编号
          %{id: "id_intro", type: "introduction", content: "Intro"},
          # 应编号 1
          %{id: "id1", type: "text", name: "field1", label: "Field 1"},
          # 不应编号
          %{id: "id_section", type: "section", title: "Section 1"},
          %{
            id: "id2",
            type: "number",
            name: "field2",
            label: "Field 2",
            # 条件渲染
            condition: %{
              operator: "==",
              left: %{type: "field", name: "field1"},
              right: %{type: "value", value: "show"}
            }
          },

          # 如果可见，应编号 2
          # 如果 field2 可见，应编号 3；否则编号 2
          %{id: "id3", type: "select", name: "field3", label: "Field 3"},
          # 不应编号
          %{id: "id_deco", type: "decoration", image_url: "img.png"}
        ]
      }

      # 情况 1: field2 可见
      form_data_show = %{"field1" => "show"}
      # 假设 render 函数存在且返回 HTML 字符串
      rendered_show = FormTemplate.render(template, form_data_show)

      # 断言：检查序号 span 的总数是否正确
      assert Regex.scan(~r/<span class="dynamic-item-number">\d+\.<\/span>/, rendered_show)
             |> length() == 3

      # 仍然可以检查关键字段的序号是否正确
      assert rendered_show =~ ~r/<span class="dynamic-item-number">1\.<\/span>.*Field 1/s
      # field2 可见，编号 2
      assert rendered_show =~ ~r/<span class="dynamic-item-number">2\.<\/span>.*Field 2/s
      # field3 编号 3
      assert rendered_show =~ ~r/<span class="dynamic-item-number">3\.<\/span>.*Field 3/s
      # 移除之前导致误报的 refute 断言
      # refute rendered_show =~ ~r/<span class="dynamic-item-number">\d+\.<\/span>.*Intro/s
      # refute rendered_show =~ ~r/<span class="dynamic-item-number">\d+\.<\/span>.*Section 1/s
      # refute rendered_show =~ ~r/<span class="dynamic-item-number">\d+\.<\/span>.*decoration/s

      # 情况 2: field2 不可见
      # field2 的条件不满足
      form_data_hide = %{"field1" => "hide"}
      rendered_hide = FormTemplate.render(template, form_data_hide)

      # --- 修改断言 ---
      # 检查序号 span 的总数是否正确
      assert Regex.scan(~r/<span class="dynamic-item-number">\d+\.<\/span>/, rendered_hide)
             |> length() == 2

      # 检查关键字段的序号
      assert rendered_hide =~ ~r/<span class="dynamic-item-number">1\.<\/span>.*Field 1/s
      # field2 不渲染
      refute rendered_hide =~ ~r/name="field2"/
      # field3 现在编号 2
      assert rendered_hide =~ ~r/<span class="dynamic-item-number">2\.<\/span>.*Field 3/s
      # 移除之前导致误报的 refute 断言
      # refute rendered_hide =~ ~r/<span class="dynamic-item-number">\d+\.<\/span>.*Intro/s
      # refute rendered_hide =~ ~r/<span class="dynamic-item-number">\d+\.<\/span>.*Section 1/s
      # refute rendered_hide =~ ~r/<span class="dynamic-item-number">\d+\.<\/span>.*decoration/s
    end
  end
end
