defmodule MyApp.CheckboxTest do
  use MyApp.DataCase
  
  alias MyApp.Forms
  alias MyApp.Responses
  alias MyApp.Accounts

  # 测试用户设置 - 复用 Accounts 模块创建测试用户
  setup do
    {:ok, user} = Accounts.register_user(%{
      email: "test#{:rand.uniform(1000)}@example.com",
      password: "Hello123Password!",  # 密码长度至少12个字符
      password_confirmation: "Hello123Password!"
    })
    
    %{user: user}
  end
  
  # 创建一个带有复选框表单项的测试表单
  defp create_test_form_with_checkbox(user_id) do
    # 1. 创建表单
    {:ok, form} = Forms.create_form(%{
      "title" => "测试复选框表单",
      "description" => "这是一个测试复选框功能的表单",
      "user_id" => user_id,
      "status" => "draft"
    })
    
    # 2. 添加复选框表单项
    {:ok, item} = Forms.add_form_item(form, %{
      "label" => "选择你喜欢的水果",
      "type" => "checkbox",
      "required" => true
    })
    
    # 3. 添加选项
    {:ok, _option1} = Forms.add_item_option(item, %{
      "label" => "苹果",
      "value" => "apple"
    })
    
    {:ok, _option2} = Forms.add_item_option(item, %{
      "label" => "香蕉",
      "value" => "banana"
    })
    
    {:ok, _option3} = Forms.add_item_option(item, %{
      "label" => "橙子",
      "value" => "orange"
    })
    
    # 4. 发布表单
    {:ok, published_form} = Forms.publish_form(form)
    
    # 5. 重新加载表单以获取所有关联
    Forms.get_form_with_items(published_form.id)
  end
  
  # 测试带有复选框的表单创建
  test "创建带有复选框的表单", %{user: user} do
    form = create_test_form_with_checkbox(user.id)
    
    # 确认表单已创建
    assert form.title == "测试复选框表单"
    assert form.status == :published
    
    # 确认有一个复选框表单项
    assert length(form.items) == 1
    checkbox_item = Enum.at(form.items, 0)
    assert checkbox_item.type == :checkbox
    assert checkbox_item.label == "选择你喜欢的水果"
    
    # 确认复选框有三个选项
    assert length(checkbox_item.options) == 3
    
    # 验证选项内容
    option_values = Enum.map(checkbox_item.options, & &1.value)
    assert "apple" in option_values
    assert "banana" in option_values
    assert "orange" in option_values
    
    IO.puts("✓ 创建带有复选框的表单测试通过")
  end
  
  # 测试复选框表单响应 - 提交单个选项
  test "回答复选框表单 - 单选", %{user: user} do
    form = create_test_form_with_checkbox(user.id)
    checkbox_item = Enum.at(form.items, 0)
    
    # 创建回复 - 提交单个选择
    answers = %{
      checkbox_item.id => ["apple"]  # 注意这里是一个列表
    }
    
    {:ok, response} = Responses.create_response(form.id, answers)
    
    # 确认响应已创建
    assert response.form_id == form.id
    assert response.answers != nil
    assert length(response.answers) == 1
    
    # 验证答案值
    answer = Enum.at(response.answers, 0)
    assert answer.form_item_id == checkbox_item.id
    assert answer.value["value"] == ["apple"]
    
    IO.puts("✓ 回答复选框表单(单选)测试通过")
  end
  
  # 测试复选框表单响应 - 提交多个选项
  test "回答复选框表单 - 多选", %{user: user} do
    form = create_test_form_with_checkbox(user.id)
    checkbox_item = Enum.at(form.items, 0)
    
    # 创建回复 - 提交多个选择
    answers = %{
      checkbox_item.id => ["apple", "banana"]  # 选择多个选项
    }
    
    {:ok, response} = Responses.create_response(form.id, answers)
    
    # 确认响应已创建
    assert response.form_id == form.id
    assert response.answers != nil
    assert length(response.answers) == 1
    
    # 验证答案值
    answer = Enum.at(response.answers, 0)
    assert answer.form_item_id == checkbox_item.id
    assert answer.value["value"] == ["apple", "banana"]
    
    IO.puts("✓ 回答复选框表单(多选)测试通过")
  end
  
  # 测试复选框表单响应验证 - 必填项为空
  test "回答复选框表单 - 验证必填项", %{user: user} do
    form = create_test_form_with_checkbox(user.id)
    
    # 创建回复 - 未提供必填项的答案
    answers = %{}
    
    result = Responses.create_response(form.id, answers)
    
    # 验证应该失败，因为没有提供必填项的答案
    assert result == {:error, :validation_failed}
    
    IO.puts("✓ 回答复选框表单(必填项验证)测试通过")
  end
  
  # 测试复选框表单响应验证 - 无效选项
  test "回答复选框表单 - 验证无效选项", %{user: user} do
    form = create_test_form_with_checkbox(user.id)
    checkbox_item = Enum.at(form.items, 0)
    
    # 创建回复 - 提供了不存在的选项
    answers = %{
      checkbox_item.id => ["invalid_option"]
    }
    
    result = Responses.create_response(form.id, answers)
    
    # 验证应该失败，因为提供了无效选项
    assert result == {:error, :validation_failed}
    
    IO.puts("✓ 回答复选框表单(无效选项验证)测试通过")
  end
  
  # 测试复选框表单响应验证 - 混合有效和无效选项
  test "回答复选框表单 - 混合有效和无效选项", %{user: user} do
    form = create_test_form_with_checkbox(user.id)
    checkbox_item = Enum.at(form.items, 0)
    
    # 创建回复 - 混合有效和无效选项
    answers = %{
      checkbox_item.id => ["apple", "invalid_option"]
    }
    
    result = Responses.create_response(form.id, answers)
    
    # 验证应该失败，因为包含无效选项
    assert result == {:error, :validation_failed}
    
    IO.puts("✓ 回答复选框表单(混合有效和无效选项验证)测试通过")
  end
end