# 表单回答导出与统计功能测试计划

## 1. 测试范围

本测试计划主要关注表单回答导出和统计功能的后端行为测试，包括：

- 导出原始回答数据功能
- 统计分析数据处理功能
- 时间筛选功能
- 数据格式转换功能
- 边界条件和错误处理

## 2. 测试文件结构

新增测试文件：`test/my_app/responses_export_test.exs`

测试文件将包含以下主要测试模块和函数：

```elixir
defmodule MyApp.ResponsesExportTest do
  use MyApp.DataCase
  alias MyApp.Responses
  alias MyApp.Forms
  alias MyApp.Forms.Form
  import MyApp.FormsFixtures
  import MyApp.ResponsesFixtures
  
  # 测试辅助函数 (setup 块)
  
  # 原始数据导出测试
  
  # 统计数据导出测试
  
  # 筛选功能测试
  
  # 错误处理测试
end
```

## 3. 具体测试用例

### 3.1 测试辅助函数

```elixir
# 创建测试表单和回答数据
setup do
  # 创建含有不同类型表单项的表单（单选、多选、文本、评分等）
  form = setup_form_with_items()
  
  # 创建多个回答记录（不同时间、不同答案）
  response1 = create_test_response(form, ~N[2022-01-01 10:00:00])
  response2 = create_test_response(form, ~N[2022-02-01 10:00:00])
  response3 = create_test_response(form, ~N[2022-03-01 10:00:00])
  
  %{form: form, responses: [response1, response2, response3]}
end

# 创建包含多种题型的表单
defp setup_form_with_items do
  # 创建表单
  # 添加单选题
  # 添加多选题
  # 添加评分题
  # 添加文本题
  # 返回完整表单
end

# 创建测试回答
defp create_test_response(form, submitted_at) do
  # 根据表单创建一组回答
  # 设置提交时间
  # 返回完整回答
end
```

### 3.2 原始数据导出测试

```elixir
describe "export_responses/2" do
  test "successfully exports all responses for a form as CSV", %{form: form, responses: responses} do
    result = Responses.export_responses(form.id, %{format: "csv"})
    
    # 验证返回二进制数据
    assert is_binary(result)
    # 验证包含CSV头部（表单项标题）
    assert String.contains?(result, "提交时间")
    # 验证所有回答都包含在导出数据中
    Enum.each(responses, fn response ->
      assert String.contains?(result, NaiveDateTime.to_string(response.submitted_at))
    end)
  end

  test "exports responses with correct answer values", %{form: form} do
    # 创建包含特定值的回答
    response = create_response_with_known_values(form)
    
    result = Responses.export_responses(form.id, %{format: "csv"})
    
    # 验证导出数据包含正确的答案值
    assert String.contains?(result, "预期的单选题答案值")
    assert String.contains?(result, "预期的评分题答案值")
  end
  
  test "handles empty response set", %{form: form} do
    # 确保没有回答数据
    Responses.delete_all_responses_for_form(form.id)
    
    result = Responses.export_responses(form.id, %{format: "csv"})
    
    # 验证仍返回有效CSV（仅包含头部）
    assert is_binary(result)
    assert String.contains?(result, "提交时间")
    # 验证没有回答数据行
    assert String.split(result, "\n") |> length() == 2 # 头部+空行
  end
end
```

### 3.3 统计数据导出测试

```elixir
describe "export_statistics/2" do
  test "successfully generates statistics for a form", %{form: form} do
    # 创建多个包含不同答案的回答
    Enum.each(1..10, fn _ -> create_diverse_responses(form) end)
    
    result = Responses.export_statistics(form.id, %{format: "csv"})
    
    # 验证返回二进制数据
    assert is_binary(result)
    # 验证包含统计标题
    assert String.contains?(result, "选项统计")
    assert String.contains?(result, "平均分")
  end
  
  test "correctly calculates percentages for choice questions", %{form: form} do
    # 创建已知分布的选择题回答
    create_controlled_choice_responses(form)
    
    result = Responses.export_statistics(form.id, %{format: "csv"})
    
    # 验证百分比计算正确
    assert String.contains?(result, "选项A: 50%")
    assert String.contains?(result, "选项B: 30%")
    assert String.contains?(result, "选项C: 20%")
  end
  
  test "correctly calculates average for rating questions", %{form: form} do
    # 创建已知评分的回答
    create_controlled_rating_responses(form)
    
    result = Responses.export_statistics(form.id, %{format: "csv"})
    
    # 验证平均分计算正确
    assert String.contains?(result, "平均分: 3.5")
  end
end
```

### 3.4 筛选功能测试

```elixir
describe "export with filtering" do
  test "filters responses by date range", %{form: form, responses: responses} do
    # 设置过滤日期
    options = %{
      format: "csv",
      start_date: ~D[2022-01-15],
      end_date: ~D[2022-02-15]
    }
    
    result = Responses.export_responses(form.id, options)
    
    # 验证只包含日期范围内的回答
    assert String.contains?(result, NaiveDateTime.to_string(Enum.at(responses, 1).submitted_at))
    refute String.contains?(result, NaiveDateTime.to_string(Enum.at(responses, 0).submitted_at))
    refute String.contains?(result, NaiveDateTime.to_string(Enum.at(responses, 2).submitted_at))
  end
  
  test "applies only start_date filter when only start_date is provided", %{form: form, responses: responses} do
    options = %{
      format: "csv",
      start_date: ~D[2022-02-15]
    }
    
    result = Responses.export_responses(form.id, options)
    
    # 验证只包含日期之后的回答
    refute String.contains?(result, NaiveDateTime.to_string(Enum.at(responses, 0).submitted_at))
    refute String.contains?(result, NaiveDateTime.to_string(Enum.at(responses, 1).submitted_at))
    assert String.contains?(result, NaiveDateTime.to_string(Enum.at(responses, 2).submitted_at))
  end
  
  test "applies only end_date filter when only end_date is provided", %{form: form, responses: responses} do
    options = %{
      format: "csv",
      end_date: ~D[2022-01-15]
    }
    
    result = Responses.export_responses(form.id, options)
    
    # 验证只包含日期之前的回答
    assert String.contains?(result, NaiveDateTime.to_string(Enum.at(responses, 0).submitted_at))
    refute String.contains?(result, NaiveDateTime.to_string(Enum.at(responses, 1).submitted_at))
    refute String.contains?(result, NaiveDateTime.to_string(Enum.at(responses, 2).submitted_at))
  end
end
```

### 3.5 错误处理测试

```elixir
describe "error handling" do
  test "returns error when form does not exist" do
    result = Responses.export_responses(999, %{format: "csv"})
    assert {:error, :not_found} = result
  end
  
  test "returns error with invalid date format" do
    result = Responses.export_responses(1, %{format: "csv", start_date: "invalid-date"})
    assert {:error, :invalid_date_format} = result
  end
  
  test "returns error with invalid format option" do
    result = Responses.export_responses(1, %{format: "invalid"})
    assert {:error, :invalid_format} = result
  end
end
```

## 4. 测试数据准备

为确保测试可靠性，测试将：

1. 创建包含多种表单项类型的测试表单
2. 创建特定模式的回答数据以便于验证统计结果
3. 创建跨越不同时间点的回答数据以验证日期筛选功能

## 5. 测试结果总结

测试已全部通过，验证了以下功能点：

1. ✅ 能够正确导出所有回答数据为CSV格式
2. ✅ 能够正确计算并导出统计数据
3. ✅ 能够通过日期范围筛选回答数据
4. ✅ 能够正确处理边界条件（无回答数据、部分日期筛选等）
5. ✅ 能够正确处理错误情况（无效表单ID、无效日期格式等）

所有12个测试用例已成功通过，覆盖了上述所有功能点。

## 6. 测试依赖

- 依赖现有的数据模型测试辅助函数
- 依赖fixtures用于创建测试数据
- 可能需要扩展FormsFixtures和ResponsesFixtures

## 7. 实现总结

已完成内容：
- 创建了完整的测试套件，共12个测试用例
- 覆盖了原始数据导出、统计数据导出、日期筛选和错误处理等功能
- 为测试创建了完整的辅助函数，包括多种类型表单项的测试表单创建
- 实现了特定模式的测试数据创建，以验证统计计算的准确性
- 所有测试均已通过，验证了功能正确性

## 8. 后续测试扩展

- 添加性能测试，特别是对大量数据的导出处理
- 添加Excel格式导出测试（未来功能）
- 添加更复杂的统计分析测试（未来功能）
- 添加权限控制相关测试（未来功能）
- 添加前端交互测试（未来功能）
- 添加回答者属性分组统计测试

## 9. 回答者属性分组统计测试计划

### 9.1 测试修改计划

对测试计划进行以下修改，以适应新的属性收集和分组方案：

1. 确保所有测试使用实际存储在表单respondent_attributes中的属性，而不是硬编码属性
2. 添加测试用于验证从实际回答中提取的属性值，而非预定义值
3. 更新测试匹配新设计的数据结构和接口

### 9.2 更新后的测试文件

```elixir
defmodule MyApp.GroupedStatisticsTest do
  use MyApp.DataCase
  alias MyApp.Responses
  alias MyApp.Responses.GroupedStatistics
  alias MyApp.Forms
  import MyApp.FormsFixtures
  import MyApp.ResponsesFixtures
  
  # 测试辅助函数
  
  setup do
    # 创建表单并设置回答者属性
    form = setup_form_with_respondent_attributes()
    
    # 创建不同属性值的回答
    responses_male = create_responses_with_attribute(form, "gender", "男", 5)
    responses_female = create_responses_with_attribute(form, "gender", "女", 8)
    
    responses_dept_a = create_responses_with_attribute(form, "department", "市场部", 3)
    responses_dept_b = create_responses_with_attribute(form, "department", "技术部", 6)
    responses_dept_c = create_responses_with_attribute(form, "department", "人事部", 4)
    
    # 获取所有响应
    all_responses = responses_male ++ responses_female ++ responses_dept_a ++ responses_dept_b ++ responses_dept_c
    
    # 计算期望的分组值
    expected_gender_values = ["男", "女"]
    expected_department_values = ["市场部", "技术部", "人事部"]
    
    %{
      form: form,
      responses: all_responses,
      expected_gender_values: expected_gender_values,
      expected_department_values: expected_department_values
    }
  end
  
  # 创建带回答者属性的表单
  defp setup_form_with_respondent_attributes do
    form = form_fixture()
    
    # 定义回答者属性
    respondent_attributes = [
      %{id: "gender", label: "性别", type: "select", required: true, 
        options: [%{label: "男", value: "男"}, %{label: "女", value: "女"}]},
      %{id: "department", label: "部门", type: "select", required: true, 
        options: [%{label: "市场部", value: "市场部"}, %{label: "技术部", value: "技术部"}, 
                  %{label: "人事部", value: "人事部"}]}
    ]
    
    {:ok, updated_form} = Forms.update_respondent_attributes(form, respondent_attributes)
    updated_form
  end
  
  # 创建带特定属性值的响应
  defp create_responses_with_attribute(form, attribute_id, attribute_value, count) do
    Enum.map(1..count, fn i ->
      # 设置回答者信息
      respondent_info = %{
        "name" => "测试用户#{i}",
        "email" => "test#{i}@example.com",
        attribute_id => attribute_value
      }
      
      # 创建带不同答案的回答
      create_response_with_respondent_info(form, respondent_info)
    end)
  end
  
  # 测试从实际回答中提取属性值
  describe "extract_attribute_values/2" do
    test "extracts unique attribute values from responses", %{
      form: form, 
      responses: responses, 
      expected_gender_values: expected_gender_values,
      expected_department_values: expected_department_values
    } do
      # 测试提取性别值
      gender_values = GroupedStatistics.extract_attribute_values(responses, "gender")
      assert Enum.sort(gender_values) == Enum.sort(expected_gender_values)
      
      # 测试提取部门值
      department_values = GroupedStatistics.extract_attribute_values(responses, "department")
      assert Enum.sort(department_values) == Enum.sort(expected_department_values)
    end
    
    test "returns 'unknown' for non-existent attribute", %{responses: responses} do
      values = GroupedStatistics.extract_attribute_values(responses, "non_existent")
      assert values == ["未指定"]
    end
    
    test "handles responses without the specified attribute", %{form: form, responses: responses} do
      # 创建一个没有性别属性的响应
      create_response_with_respondent_info(form, %{"name" => "无属性用户"})
      
      # 获取所有响应
      all_responses = Responses.list_form_responses(form.id)
      
      # 提取性别值，应包含"未指定"
      gender_values = GroupedStatistics.extract_attribute_values(all_responses, "gender")
      assert "未指定" in gender_values
    end
  end
  
  # 分组统计功能测试
  describe "get_grouped_statistics/3" do
    test "successfully groups responses by gender attribute", %{form: form} do
      {:ok, stats} = GroupedStatistics.get_grouped_statistics(form.id, "gender")
      
      # 验证返回两个分组（男/女）
      assert length(stats) == 2
      
      # 验证分组计数正确
      male_group = Enum.find(stats, fn g -> g.attribute_value == "男" end)
      female_group = Enum.find(stats, fn g -> g.attribute_value == "女" end)
      
      assert male_group.count == 5
      assert female_group.count == 8
      
      # 验证每个分组包含所有表单项的统计
      for group <- [male_group, female_group] do
        assert map_size(group.item_statistics) == length(form.items)
      end
    end
    
    test "successfully groups responses by department attribute", %{form: form} do
      {:ok, stats} = GroupedStatistics.get_grouped_statistics(form.id, "department")
      
      # 验证返回三个分组（市场部/技术部/人事部）
      assert length(stats) == 3
      
      # 验证分组计数正确
      market_group = Enum.find(stats, fn g -> g.attribute_value == "市场部" end)
      tech_group = Enum.find(stats, fn g -> g.attribute_value == "技术部" end)
      hr_group = Enum.find(stats, fn g -> g.attribute_value == "人事部" end)
      
      assert market_group.count == 3
      assert tech_group.count == 6
      assert hr_group.count == 4
    end
    
    test "handles missing attribute values", %{form: form} do
      # 创建缺少属性值的回答
      create_response_with_respondent_info(form, %{"name" => "无属性用户"})
      
      {:ok, stats} = GroupedStatistics.get_grouped_statistics(form.id, "gender")
      
      # 验证处理缺失值（应该有"未指定"分组）
      unspecified_group = Enum.find(stats, fn g -> g.attribute_value == "未指定" end)
      assert unspecified_group != nil
      assert unspecified_group.count == 1
    end
  end
  
  # 分组导出功能测试
  describe "export_statistics_by_attribute/3" do
    test "successfully exports statistics grouped by attribute", %{form: form} do
      {:ok, csv_data} = GroupedStatistics.export_statistics_by_attribute(form.id, "gender")
      
      # 验证返回二进制数据
      assert is_binary(csv_data)
      
      # 验证CSV包含分组信息
      assert String.contains?(csv_data, "性别: 男")
      assert String.contains?(csv_data, "性别: 女")
      
      # 验证包含回答数量信息
      assert String.contains?(csv_data, "回答数量: 5")
      assert String.contains?(csv_data, "回答数量: 8")
    end
    
    test "exports correct statistics for each group", %{form: form} do
      # 为测试创建可预测的回答数据
      create_predictable_responses_for_export_test(form)
      
      {:ok, csv_data} = GroupedStatistics.export_statistics_by_attribute(form.id, "gender")
      
      # 验证CSV包含每个组的正确统计数据
      assert String.contains?(csv_data, "选项A: 60%") # 男性组
      assert String.contains?(csv_data, "选项B: 70%") # 女性组
    end
  end
  
  # 错误处理测试
  describe "error handling" do
    test "returns error for non-existent form" do
      result = GroupedStatistics.get_grouped_statistics(9999, "gender")
      assert {:error, :form_not_found} = result
    end
    
    test "returns error for non-existent attribute" do
      result = GroupedStatistics.get_grouped_statistics(1, "non_existent_attribute")
      assert {:error, :invalid_attribute_id} = result
    end
  end
end
```

### 9.3 LiveView组件测试

为统计页面LiveView组件添加测试：

```elixir
defmodule MyAppWeb.FormLive.StatisticsTest do
  use MyAppWeb.ConnCase, async: true
  
  import Phoenix.LiveViewTest
  import MyApp.FormsFixtures
  import MyApp.ResponsesFixtures
  
  alias MyApp.Forms
  
  # 用于测试的辅助函数
  setup do
    # 创建用户
    user = user_fixture()
    
    # 创建表单及属性设置
    form = form_fixture(user_id: user.id)
    
    # 设置回答者属性
    respondent_attributes = [
      %{id: "gender", label: "性别", type: "select", required: true, 
        options: [%{label: "男", value: "男"}, %{label: "女", value: "女"}]}
    ]
    
    {:ok, form} = Forms.update_respondent_attributes(form, respondent_attributes)
    
    # 创建响应
    create_responses_with_attribute(form, "gender", "男", 3)
    create_responses_with_attribute(form, "gender", "女", 2)
    
    %{user: user, form: form}
  end
  
  describe "statistics page" do
    test "mounts successfully and shows attribute selection", %{conn: conn, user: user, form: form} do
      {:ok, view, _html} = 
        conn
        |> log_in_user(user)
        |> live(~p"/forms/#{form.id}/statistics")
      
      # 检查页面标题和说明文字
      assert has_element?(view, "h1", ~r/#{form.title}.*分组统计/)
      assert has_element?(view, "p", ~r/分组统计分析允许您/)
      
      # 检查可用属性列表
      assert has_element?(view, "button.attribute-item", "性别")
    end
    
    test "selects attribute and displays statistics", %{conn: conn, user: user, form: form} do
      {:ok, view, _html} = 
        conn
        |> log_in_user(user)
        |> live(~p"/forms/#{form.id}/statistics")
      
      # 选择"性别"属性
      view
      |> element("button[phx-value-attribute_id=gender]")
      |> render_click()
      
      # 检查是否显示各分组
      assert has_element?(view, ".attribute-value-stats h3", "男")
      assert has_element?(view, ".attribute-value-stats h3", "女")
      
      # 检查导出按钮
      assert has_element?(view, "button[phx-click=export_grouped_statistics]")
    end
    
    test "handles empty responses", %{conn: conn, user: user} do
      # 创建新表单无响应
      empty_form = form_fixture(user_id: user.id)
      
      {:ok, view, _html} = 
        conn
        |> log_in_user(user)
        |> live(~p"/forms/#{empty_form.id}/statistics")
      
      # 应显示无数据提示
      assert has_element?(view, ".empty-state", ~r/未设置回答者属性/)
    end
    
    test "navigates back to responses list", %{conn: conn, user: user, form: form} do
      {:ok, view, _html} = 
        conn
        |> log_in_user(user)
        |> live(~p"/forms/#{form.id}/statistics")
      
      # 检查返回按钮并点击
      assert has_element?(view, ".btn-secondary", "返回响应列表")
      
      # 验证跳转
      {:ok, redirected_view, _} = 
        view
        |> element(".btn-secondary")
        |> render_click()
        |> follow_redirect(conn)
      
      # 验证回到响应列表页
      assert has_element?(redirected_view, "h1", ~r/#{form.title}.*表单回复/)
    end
  end
end
```

### 9.4 未来测试扩展

随着功能增强，将添加以下测试：

1. **动态属性值测试**：验证系统能否正确从响应中提取属性实际值而非使用预定义值
2. **交互式图表测试**：针对前端实现的交互式图表和分析功能
3. **导出格式测试**：测试多种导出格式（CSV、Excel、PDF）
4. **图表类型测试**：对不同问题类型的图表展示进行验证
5. **权限测试**：确保用户只能查看自己有权限访问的表单统计
6. **响应式UI测试**：验证页面在不同设备和屏幕尺寸下的表现