defmodule MyApp.FormLogicTest do
  use MyApp.DataCase, async: false

  alias MyApp.Forms
  alias MyApp.FormLogic
  import MyApp.AccountsFixtures

  @moduletag :capture_log

  # 基础测试数据
  setup do
    # 创建测试用户
    user = user_fixture()

    # 创建表单
    {:ok, form} =
      Forms.create_form(%{
        title: "测试表单标题",
        description: "这是测试表单说明",
        user_id: user.id
      })

    # 创建表单项 - 性别单选框
    {:ok, gender_item} =
      Forms.add_form_item(form, %{
        label: "性别",
        type: :radio,
        required: true,
        order: 1
      })

    # 添加性别选项
    {:ok, _male_option} =
      Forms.add_item_option(gender_item, %{
        label: "男",
        value: "male"
      })

    {:ok, _female_option} =
      Forms.add_item_option(gender_item, %{
        label: "女",
        value: "female"
      })

    # 创建表单项 - 年龄数字框 - 必填项
    {:ok, age_item} =
      Forms.add_form_item(form, %{
        label: "年龄",
        type: :number,
        required: true,
        order: 2,
        min: 1,
        max: 120
      })

    # 创建表单项 - 婚姻状况单选框 - 必填项
    {:ok, marital_item} =
      Forms.add_form_item(form, %{
        label: "婚姻状况",
        type: :radio,
        required: true,
        order: 3
      })

    # 添加婚姻状况选项
    {:ok, _single_option} =
      Forms.add_item_option(marital_item, %{
        label: "未婚",
        value: "single"
      })

    {:ok, _married_option} =
      Forms.add_item_option(marital_item, %{
        label: "已婚",
        value: "married"
      })

    # 创建表单项 - 子女数量框 - 非必填项
    {:ok, children_item} =
      Forms.add_form_item(form, %{
        label: "子女数量",
        type: :number,
        required: false,
        order: 4,
        min: 0,
        max: 10
      })

    # 返回测试数据
    %{
      user: user,
      form: form,
      gender_item: gender_item,
      age_item: age_item,
      marital_item: marital_item,
      children_item: children_item
    }
  end

  describe "条件创建测试" do
    test "简单相等条件", %{gender_item: gender_item} do
      # 创建性别 = 男的条件
      condition = FormLogic.build_condition(gender_item.id, "equals", "male")

      assert condition.source_item_id == gender_item.id
      assert condition.operator == "equals"
      assert condition.value == "male"
      assert condition.type == :simple
    end

    test "数值比较条件", %{age_item: age_item} do
      # 创建年龄 >= 18的条件
      condition = FormLogic.build_condition(age_item.id, "greater_than_or_equal", 18)

      assert condition.source_item_id == age_item.id
      assert condition.operator == "greater_than_or_equal"
      assert condition.value == 18
      assert condition.type == :simple
    end

    test "AND复合条件", %{gender_item: gender_item, age_item: age_item} do
      # 创建性别 = 男 AND 年龄 >= 18
      condition1 = FormLogic.build_condition(gender_item.id, "equals", "male")
      condition2 = FormLogic.build_condition(age_item.id, "greater_than_or_equal", 18)

      and_condition = FormLogic.build_compound_condition("and", [condition1, condition2])

      assert and_condition.operator == "and"
      assert length(and_condition.conditions) == 2
      assert and_condition.type == :compound

      [first, second] = and_condition.conditions
      assert first.source_item_id == gender_item.id
      assert second.source_item_id == age_item.id
    end

    test "OR复合条件", %{gender_item: gender_item, age_item: age_item} do
      # 创建性别 = 女 OR 年龄 < 18
      condition1 = FormLogic.build_condition(gender_item.id, "equals", "female")
      condition2 = FormLogic.build_condition(age_item.id, "less_than", 18)

      or_condition = FormLogic.build_compound_condition("or", [condition1, condition2])

      assert or_condition.operator == "or"
      assert length(or_condition.conditions) == 2
      assert or_condition.type == :compound
    end

    test "嵌套条件", %{gender_item: gender_item, age_item: age_item} do
      # 嵌套条件(性别 = 男 AND 年龄 >= 18) OR (性别 = 女 AND 年龄 >= 21)
      condition1 = FormLogic.build_condition(gender_item.id, "equals", "male")
      condition2 = FormLogic.build_condition(age_item.id, "greater_than_or_equal", 18)
      and_condition1 = FormLogic.build_compound_condition("and", [condition1, condition2])

      condition3 = FormLogic.build_condition(gender_item.id, "equals", "female")
      condition4 = FormLogic.build_condition(age_item.id, "greater_than_or_equal", 21)
      and_condition2 = FormLogic.build_compound_condition("and", [condition3, condition4])

      nested_condition =
        FormLogic.build_compound_condition("or", [and_condition1, and_condition2])

      assert nested_condition.operator == "or"
      assert length(nested_condition.conditions) == 2
      assert nested_condition.type == :compound

      [first, second] = nested_condition.conditions
      assert first.operator == "and"
      assert second.operator == "and"
    end
  end

  describe "条件评估测试" do
    test "相等条件评估", %{gender_item: gender_item} do
      # 创建性别 = 男
      condition = FormLogic.build_condition(gender_item.id, "equals", "male")

      # 表单数据
      form_data = %{
        # 性别 = 男
        "#{gender_item.id}" => "male"
      }

      # 评估条件
      assert FormLogic.evaluate_condition(condition, form_data) == true

      # 更改表单数据
      form_data = %{
        # 性别 = 女
        "#{gender_item.id}" => "female"
      }

      # 评估条件
      assert FormLogic.evaluate_condition(condition, form_data) == false
    end

    test "不等条件评估", %{gender_item: gender_item} do
      # 创建性别 != 男
      condition = FormLogic.build_condition(gender_item.id, "not_equals", "male")

      # 表单数据
      form_data = %{
        # 性别 = 女
        "#{gender_item.id}" => "female"
      }

      # 评估条件
      assert FormLogic.evaluate_condition(condition, form_data) == true

      # 更改表单数据
      form_data = %{
        # 性别 = 男
        "#{gender_item.id}" => "male"
      }

      # 评估条件
      assert FormLogic.evaluate_condition(condition, form_data) == false
    end

    test "大于条件评估", %{age_item: age_item} do
      # 创建年龄 > 18
      condition = FormLogic.build_condition(age_item.id, "greater_than", 18)

      # 表单数据
      form_data = %{
        # 年龄 = 25
        "#{age_item.id}" => "25"
      }

      # 评估条件
      assert FormLogic.evaluate_condition(condition, form_data) == true

      # 更改表单数据
      form_data = %{
        # 年龄 = 16
        "#{age_item.id}" => "16"
      }

      # 评估条件
      assert FormLogic.evaluate_condition(condition, form_data) == false

      # 临界条件
      form_data = %{
        # 年龄 = 18
        "#{age_item.id}" => "18"
      }

      # 评估条件
      assert FormLogic.evaluate_condition(condition, form_data) == false
    end

    test "大于等于条件评估", %{age_item: age_item} do
      # 创建年龄 >= 18
      condition = FormLogic.build_condition(age_item.id, "greater_than_or_equal", 18)

      # 表单数据 - 大于
      form_data = %{
        # 年龄 = 25
        "#{age_item.id}" => "25"
      }

      # 评估条件
      assert FormLogic.evaluate_condition(condition, form_data) == true

      # 表单数据 - 等于
      form_data = %{
        # 年龄 = 18
        "#{age_item.id}" => "18"
      }

      # 评估条件
      assert FormLogic.evaluate_condition(condition, form_data) == true

      # 更改表单数据
      form_data = %{
        # 年龄 = 16
        "#{age_item.id}" => "16"
      }

      # 评估条件
      assert FormLogic.evaluate_condition(condition, form_data) == false
    end

    test "小于条件评估", %{age_item: age_item} do
      # 创建年龄 < 18
      condition = FormLogic.build_condition(age_item.id, "less_than", 18)

      # 表单数据
      form_data = %{
        # 年龄 = 16
        "#{age_item.id}" => "16"
      }

      # 评估条件
      assert FormLogic.evaluate_condition(condition, form_data) == true

      # 更改表单数据
      form_data = %{
        # 年龄 = 25
        "#{age_item.id}" => "25"
      }

      # 评估条件
      assert FormLogic.evaluate_condition(condition, form_data) == false

      # 临界条件
      form_data = %{
        # 年龄 = 18
        "#{age_item.id}" => "18"
      }

      # 评估条件
      assert FormLogic.evaluate_condition(condition, form_data) == false
    end

    test "小于等于条件评估", %{age_item: age_item} do
      # 创建年龄 <= 18
      condition = FormLogic.build_condition(age_item.id, "less_than_or_equal", 18)

      # 表单数据 - 小于
      form_data = %{
        # 年龄 = 16
        "#{age_item.id}" => "16"
      }

      # 评估条件
      assert FormLogic.evaluate_condition(condition, form_data) == true

      # 表单数据 - 等于
      form_data = %{
        # 年龄 = 18
        "#{age_item.id}" => "18"
      }

      # 评估条件
      assert FormLogic.evaluate_condition(condition, form_data) == true

      # 更改表单数据
      form_data = %{
        # 年龄 = 25
        "#{age_item.id}" => "25"
      }

      # 评估条件
      assert FormLogic.evaluate_condition(condition, form_data) == false
    end

    test "包含条件评估", %{gender_item: gender_item} do
      # 创建性别选项中包含"男"字
      condition = FormLogic.build_condition(gender_item.id, "contains", "男")

      # 表单数据
      form_data = %{
        # 包含"男"字
        "#{gender_item.id}" => "男性"
      }

      # 评估条件
      assert FormLogic.evaluate_condition(condition, form_data) == true

      # 更改表单数据
      form_data = %{
        # 不包含"男"字
        "#{gender_item.id}" => "女性"
      }

      # 评估条件
      assert FormLogic.evaluate_condition(condition, form_data) == false
    end

    test "AND条件评估", %{gender_item: gender_item, age_item: age_item} do
      # 创建性别 = 男 AND 年龄 >= 18
      condition1 = FormLogic.build_condition(gender_item.id, "equals", "male")
      condition2 = FormLogic.build_condition(age_item.id, "greater_than_or_equal", 18)
      and_condition = FormLogic.build_compound_condition("and", [condition1, condition2])

      # 满足条件的表单数据
      form_data = %{
        "#{gender_item.id}" => "male",
        "#{age_item.id}" => "25"
      }

      # 评估条件
      assert FormLogic.evaluate_condition(and_condition, form_data) == true

      # 部分满足条件的表单数据 (只满足性别条件)
      form_data = %{
        "#{gender_item.id}" => "male",
        "#{age_item.id}" => "16"
      }

      # 评估条件
      assert FormLogic.evaluate_condition(and_condition, form_data) == false

      # 部分满足条件的表单数据 (只满足年龄条件)
      form_data = %{
        "#{gender_item.id}" => "female",
        "#{age_item.id}" => "25"
      }

      # 评估条件
      assert FormLogic.evaluate_condition(and_condition, form_data) == false

      # 不满足条件的表单数据
      form_data = %{
        "#{gender_item.id}" => "female",
        "#{age_item.id}" => "16"
      }

      # 评估条件
      assert FormLogic.evaluate_condition(and_condition, form_data) == false
    end

    test "OR条件评估", %{gender_item: gender_item, age_item: age_item} do
      # 创建性别 = 男 OR 年龄 >= 18
      condition1 = FormLogic.build_condition(gender_item.id, "equals", "male")
      condition2 = FormLogic.build_condition(age_item.id, "greater_than_or_equal", 18)
      or_condition = FormLogic.build_compound_condition("or", [condition1, condition2])

      # 两个条件都满足的表单数据
      form_data = %{
        "#{gender_item.id}" => "male",
        "#{age_item.id}" => "25"
      }

      # 评估条件
      assert FormLogic.evaluate_condition(or_condition, form_data) == true

      # 满足性别条件的表单数据
      form_data = %{
        "#{gender_item.id}" => "male",
        "#{age_item.id}" => "16"
      }

      # 评估条件
      assert FormLogic.evaluate_condition(or_condition, form_data) == true

      # 满足年龄条件的表单数据
      form_data = %{
        "#{gender_item.id}" => "female",
        "#{age_item.id}" => "25"
      }

      # 评估条件
      assert FormLogic.evaluate_condition(or_condition, form_data) == true

      # 不满足任何条件的表单数据
      form_data = %{
        "#{gender_item.id}" => "female",
        "#{age_item.id}" => "16"
      }

      # 评估条件
      assert FormLogic.evaluate_condition(or_condition, form_data) == false
    end

    test "嵌套条件评估", %{gender_item: gender_item, age_item: age_item} do
      # 嵌套条件(性别 = 男 AND 年龄 >= 18) OR (性别 = 女 AND 年龄 >= 21)
      condition1 = FormLogic.build_condition(gender_item.id, "equals", "male")
      condition2 = FormLogic.build_condition(age_item.id, "greater_than_or_equal", 18)
      and_condition1 = FormLogic.build_compound_condition("and", [condition1, condition2])

      condition3 = FormLogic.build_condition(gender_item.id, "equals", "female")
      condition4 = FormLogic.build_condition(age_item.id, "greater_than_or_equal", 21)
      and_condition2 = FormLogic.build_compound_condition("and", [condition3, condition4])

      nested_condition =
        FormLogic.build_compound_condition("or", [and_condition1, and_condition2])

      # 测试案例1：男25岁 - 满足第一个条件组，结果应该true
      form_data = %{
        "#{gender_item.id}" => "male",
        "#{age_item.id}" => "25"
      }

      assert FormLogic.evaluate_condition(nested_condition, form_data) == true

      # 测试案例2：女25岁 - 满足第二个条件组，结果应该true
      form_data = %{
        "#{gender_item.id}" => "female",
        "#{age_item.id}" => "25"
      }

      assert FormLogic.evaluate_condition(nested_condition, form_data) == true

      # 测试案例3：女18岁 - 不满足条件（因为女性 必须 >=21岁）
      form_data = %{
        "#{gender_item.id}" => "female",
        "#{age_item.id}" => "18"
      }

      assert FormLogic.evaluate_condition(nested_condition, form_data) == false

      # 测试案例4：男16岁 - 不满足条件（因为男性 必须 >=18岁）
      form_data = %{
        "#{gender_item.id}" => "male",
        "#{age_item.id}" => "16"
      }

      assert FormLogic.evaluate_condition(nested_condition, form_data) == false
    end
  end

  describe "条件应用到表单项测试" do
    test "设置可见性条件", %{gender_item: gender_item, age_item: age_item, children_item: children_item} do
      # 创建条件(性别 = 男 AND 年龄 >= 18) OR (性别 = 女 AND 年龄 >= 21)
      condition1 = FormLogic.build_condition(gender_item.id, "equals", "male")
      condition2 = FormLogic.build_condition(age_item.id, "greater_than_or_equal", 18)
      and_condition1 = FormLogic.build_compound_condition("and", [condition1, condition2])

      condition3 = FormLogic.build_condition(gender_item.id, "equals", "female")
      condition4 = FormLogic.build_condition(age_item.id, "greater_than_or_equal", 21)
      and_condition2 = FormLogic.build_compound_condition("and", [condition3, condition4])

      nested_condition =
        FormLogic.build_compound_condition("or", [and_condition1, and_condition2])

      # 设置子女数量表单项的可见性条件
      {:ok, updated_item} =
        Forms.add_condition_to_form_item(children_item, nested_condition, :visibility)

      # 检查条件是否设置成功
      assert updated_item.visibility_condition != nil

      # 解析JSON条件确认结构
      condition_json = Jason.decode!(updated_item.visibility_condition)
      assert condition_json["type"] == "compound"
      assert condition_json["operator"] == "or"
      assert length(condition_json["conditions"]) == 2
    end

    test "表单项可见性条件评估", %{
      form: form,
      gender_item: gender_item,
      age_item: age_item,
      children_item: children_item
    } do
      # 创建婚姻状况 = 已婚条件
      {:ok, marital_item} = Forms.get_form_item_by_label(form.id, "婚姻状况")
      condition = FormLogic.build_condition(marital_item.id, "equals", "married")

      # 设置子女数量表单项的可见性条件
      {:ok, updated_children_item} =
        Forms.add_condition_to_form_item(children_item, condition, :visibility)

      # 重新获取表单和表单项
      _form = Forms.get_form_with_items(form.id)

      # 表单数据 - 满足条件
      form_data = %{
        "#{gender_item.id}" => "male",
        "#{age_item.id}" => "25",
        "#{marital_item.id}" => "married"
      }

      # 检查子女数量字段是否应该显示
      assert FormLogic.should_show_item?(updated_children_item, form_data) == true

      # 表单数据 - 不满足条件
      form_data = %{
        "#{gender_item.id}" => "male",
        "#{age_item.id}" => "25",
        "#{marital_item.id}" => "single"
      }

      # 检查子女数量字段是否应该显示
      assert FormLogic.should_show_item?(updated_children_item, form_data) == false
    end

    test "表单项必填条件评估", %{
      form: form,
      gender_item: gender_item,
      age_item: age_item,
      children_item: children_item
    } do
      # 创建婚姻状况 = 已婚条件
      {:ok, marital_item} = Forms.get_form_item_by_label(form.id, "婚姻状况")
      condition = FormLogic.build_condition(marital_item.id, "equals", "married")

      # 设置子女数量表单项的必填条件
      {:ok, updated_children_item} =
        Forms.add_condition_to_form_item(children_item, condition, :required)

      # 重新获取表单和表单项
      _form = Forms.get_form_with_items(form.id)

      # 表单数据 - 满足条件
      form_data = %{
        "#{gender_item.id}" => "male",
        "#{age_item.id}" => "25",
        "#{marital_item.id}" => "married"
      }

      # 检查子女数量字段是否应该必填
      assert FormLogic.is_item_required?(updated_children_item, form_data) == true

      # 表单数据 - 不满足条件
      form_data = %{
        "#{gender_item.id}" => "male",
        "#{age_item.id}" => "25",
        "#{marital_item.id}" => "single"
      }

      # 检查子女数量字段是否应该必填
      assert FormLogic.is_item_required?(updated_children_item, form_data) == false
    end
  end
end
