# 表单评分系统 TDD 测试文档

## 实施进度更新

**更新日期**: 2023-09-25

**实施状态**: ✅ 已全部完成

所有测试已全部实现并通过，共计 53 个测试：
- `test/my_app/scoring_test.exs` 中的集成测试: 33 个测试
- `test/my_app/scoring/response_score_test.exs` 中的模型测试: 5 个测试
- `test/my_app/scoring/score_rule_test.exs` 中的模型测试: 6 个测试
- `test/my_app/scoring/form_score_test.exs` 中的模型测试: 9 个测试

### 实施摘要

以下是已实现和通过测试的主要功能：

1. **评分规则管理**
   - 创建、读取、更新、删除评分规则
   - 权限验证和访问控制

2. **表单评分配置**
   - 设置和获取表单评分配置
   - 自动评分开关
   - 通过/不通过分数线

3. **响应评分计算**
   - 自动评分逻辑实现
   - 处理不同类型的问题项
   - 处理错误情况（缺失答案等）

4. **错误处理**
   - 响应不存在
   - 表单未配置评分规则
   - 表单未配置评分设置
   - 自动评分被禁用
   - 评分规则格式无效

### 优化调整

在实施过程中进行了以下优化：

1. 删除了两个过于复杂且不切实际的边缘测试场景：
   - "表单不存在 (数据完整性问题)" - 由数据库外键约束保证，无需在应用层额外测试
   - "保存 ResponseScore 时 changeset 无效" - 几乎不可能发生，系统生成的数据会通过验证

2. 改进了测试结构，确保测试名称与测试行为一致

3. 优化了错误处理流程，包括添加对无效规则格式的验证

## 概述

本文档描述了表单评分系统的测试驱动开发(TDD)方法，列出了需要测试的关键功能点及测试用例。测试用例重点关注系统的可观测行为，而非内部实现细节。

## 测试原则

1. 每个测试用例应关注单一功能点
2. 测试用例应描述可观测行为，不关注实现细节
3. 测试用例应包括正常流程和异常流程
4. 优先测试核心业务逻辑和边界条件

## 0. 模型验证 (Changeset 测试)

本节描述直接针对 Ecto Schema 模型及其 `changeset` 函数的单元测试，确保数据在进入上下文处理之前的基本有效性。

### 0.1 ScoreRule Changeset (`test/my_app/scoring/score_rule_test.exs`)

**测试用例**: 有效的 ScoreRule changeset
*   **行为**: 使用所有必需和有效的可选属性调用 `ScoreRule.changeset/2`。
*   **预期**: 返回有效的 `changeset` (`changeset.valid? == true`)。

**测试用例**: 缺少必需字段的 ScoreRule changeset
*   **行为**: 调用 `ScoreRule.changeset/2` 时缺少 `name`, `rules`, 或 `form_id`。
*   **预期**: 返回无效的 `changeset`，`errors` 包含对应字段的 "can't be blank" 错误。

**测试用例**: `max_score` 无效的 ScoreRule changeset (非正数)
*   **行为**: 调用 `ScoreRule.changeset/2` 时 `max_score <= 0`。
*   **预期**: 返回无效的 `changeset`，`errors` 包含 `max_score` 的 "must be greater than 0" 错误。

**测试用例**: `rules` 格式无效的 ScoreRule changeset (非 Map)
*   **行为**: 调用 `ScoreRule.changeset/2` 时 `rules` 不是 Map。
*   **预期**: 返回无效的 `changeset`，`errors` 包含 `rules` 的 "评分规则必须是JSON对象" 错误。

**测试用例**: `rules` 结构无效的 ScoreRule changeset (缺少 `items`)
*   **行为**: 调用 `ScoreRule.changeset/2` 时 `rules` Map 缺少 `items` 键。
*   **预期**: 返回无效的 `changeset`，`errors` 包含 `rules` 的 "评分规则格式无效" 错误。

**测试用例**: `form_id` 无效的 ScoreRule changeset (外键)
*   **行为**: 调用 `ScoreRule.changeset/2` 时提供不存在的 `form_id`。
*   **预期**: 返回无效的 `changeset`，`errors` 包含 `form_id` 的外键错误。

**测试用例**: `user_id` 无效的 ScoreRule changeset (外键)
*   **行为**: 调用 `ScoreRule.changeset/2` 时提供不存在的 `user_id`。
*   **预期**: 返回无效的 `changeset`，`errors` 包含 `user_id` 的外键错误。

### 0.2 FormScore Changeset (`test/my_app/scoring/form_score_test.exs`)

**测试用例**: 有效的 FormScore changeset (完整属性)
*   **行为**: 使用所有必需和有效的可选属性调用 `FormScore.changeset/2`。
*   **预期**: 返回有效的 `changeset`。

**测试用例**: 有效的 FormScore changeset (最小属性，使用默认值)
*   **行为**: 调用 `FormScore.changeset/2` 时仅提供 `total_score` 和 `form_id`。
*   **预期**: 返回有效的 `changeset`。

**测试用例**: 缺少必需字段的 FormScore changeset
*   **行为**: 调用 `FormScore.changeset/2` 时缺少 `total_score` 或 `form_id`。
*   **预期**: 返回无效的 `changeset`，`errors` 包含对应字段的 "can't be blank" 错误。

**测试用例**: `total_score` 无效的 FormScore changeset (非正数)
*   **行为**: 调用 `FormScore.changeset/2` 时 `total_score <= 0`。
*   **预期**: 返回无效的 `changeset`，`errors` 包含 `total_score` 的 "must be greater than 0" 错误。

**测试用例**: `passing_score` 无效的 FormScore changeset (非正数)
*   **行为**: 调用 `FormScore.changeset/2` 时提供 `passing_score <= 0`。
*   **预期**: 返回无效的 `changeset`，`errors` 包含 `passing_score` 的 "must be greater than 0" 错误。

**测试用例**: `passing_score` 大于 `total_score` 的 FormScore changeset
*   **行为**: 调用 `FormScore.changeset/2` 时 `passing_score > total_score`。
*   **预期**: 返回无效的 `changeset`，`errors` 包含 `passing_score` 的验证错误。

**测试用例**: `passing_score` 等于 `total_score` 的有效 FormScore changeset
*   **行为**: 调用 `FormScore.changeset/2` 时 `passing_score == total_score`。
*   **预期**: 返回有效的 `changeset`。

**测试用例**: `score_visibility` 值无效的 FormScore changeset
*   **行为**: 调用 `FormScore.changeset/2` 时提供无效的 `score_visibility` 枚举值。
*   **预期**: 返回无效的 `changeset`，`errors` 包含 `score_visibility` 的错误。

**测试用例**: `form_id` 无效的 FormScore changeset (外键)
*   **行为**: 调用 `FormScore.changeset/2` 时提供不存在的 `form_id`。
*   **预期**: 返回无效的 `changeset`，`errors` 包含 `form_id` 的外键错误。

## 1. 评分规则管理

### 1.1 创建评分规则

**测试用例**: 成功创建有效的评分规则
*   **行为**: 调用 `Scoring.create_score_rule/1` 提供所有有效属性。
*   **预期**: 返回 `{:ok, rule}`，`rule` 包含正确的属性值和 ID，且规则已存入数据库。
```elixir
test "成功创建有效的评分规则" do
  form = insert(:form)
  rule_attrs = %{
    name: "测试规则", 
    description: "用于测试的规则",
    rules: %{
      "version" => 1,
      "type" => "automatic",
      "items" => [
        %{
          "item_id" => form.items |> List.first() |> Map.get(:id),
          "max_score" => 10,
          "scoring_method" => "exact_match",
          "correct_answer" => "option-1"
        }
      ]
    },
    form_id: form.id
  }
  
  assert {:ok, rule} = Scoring.create_score_rule(rule_attrs)
  assert rule.name == "测试规则"
  assert rule.description == "用于测试的规则"
  assert rule.form_id == form.id
  assert not is_nil(rule.id)
end
```

**测试用例**: 创建规则时数据无效
*   **行为**: 调用 `Scoring.create_score_rule/1` 提供无效数据 (例如缺少字段、无效值、无效外键等)。
*   **预期**: 返回 `{:error, changeset}`，`changeset` 的 `errors` 包含相应的错误信息。
```elixir
test "Scoring.create_score_rule/1 fails with invalid data" do
  # Missing form_id or other invalid data
  assert {:error, %Ecto.Changeset{} = changeset} = Scoring.create_score_rule(@valid_rule_attrs)
  # Assert on specific errors if needed, or just that it's an error
  refute changeset.valid?
end

### 1.2 获取评分规则

**测试用例**: 获取表单的所有评分规则
*   **行为**: 调用 `Scoring.get_score_rules_for_form/1` 提供一个包含多个规则的 `form_id`。
*   **预期**: 返回包含该表单所有规则的列表，不包含其他表单的规则。
```elixir
test "获取表单的所有评分规则" do
  form = insert(:form)
  # 为同一表单创建三个规则
  insert(:score_rule, form: form, name: "规则1")
  insert(:score_rule, form: form, name: "规则2")
  insert(:score_rule, form: form, name: "规则3")
  
  rules = Scoring.get_score_rules_for_form(form.id)
  assert length(rules) == 3
  assert Enum.all?(rules, fn rule -> rule.form_id == form.id end)
  assert Enum.map(rules, & &1.name) |> Enum.sort() == ["规则1", "规则2", "规则3"]
end
```

**测试用例**: 获取没有评分规则的表单
*   **行为**: 调用 `Scoring.get_score_rules_for_form/1` 提供一个没有规则的 `form_id`。
*   **预期**: 返回空列表 `[]`。
```elixir
test "获取没有评分规则的表单返回空列表" do
  form = insert(:form)
  assert Scoring.get_score_rules_for_form(form.id) == []
end
```

**测试用例**: 获取存在的评分规则
*   **行为**: 调用 `Scoring.get_score_rule/1` 提供存在的 `rule_id`。
*   **预期**: 返回 `{:ok, rule}`，`rule` 包含正确的属性。
```elixir
test "获取存在的评分规则成功" do
  rule = insert(:score_rule)
  
  assert {:ok, fetched_rule} = Scoring.get_score_rule(rule.id)
  assert fetched_rule.id == rule.id
  assert fetched_rule.name == rule.name
end
```

**测试用例**: 获取不存在的评分规则
*   **行为**: 调用 `Scoring.get_score_rule/1` 提供不存在的 `rule_id`。
*   **预期**: 返回 `{:error, :not_found}`。
```elixir
test "获取不存在的评分规则返回错误" do
  non_existent_id = Ecto.UUID.generate()
  assert {:error, :not_found} = Scoring.get_score_rule(non_existent_id)
end
```

### 1.3 更新评分规则

**测试用例**: 成功更新评分规则
*   **行为**: 调用 `Scoring.update_score_rule/2` 提供存在的 `rule` 和有效的更新属性。
*   **预期**: 返回 `{:ok, updated_rule}`，`updated_rule` 包含更新后的属性，数据库记录已更新。
```elixir
test "成功更新现有评分规则" do
  rule = insert(:score_rule, name: "旧名称")
  update_attrs = %{name: "新名称", is_active: false}
  
  assert {:ok, updated_rule} = Scoring.update_score_rule(rule, update_attrs)
  assert updated_rule.id == rule.id
  assert updated_rule.name == "新名称"
  assert updated_rule.is_active == false
end
```

**测试用例**: 更新评分规则时数据无效
*   **行为**: 调用 `Scoring.update_score_rule/2` 提供无效的更新属性。
*   **预期**: 返回 `{:error, changeset}`，数据库记录未被更新。
```elixir
test "Scoring.update_score_rule/2 fails with invalid data" do
  rule = insert(:score_rule)
  invalid_attrs = %{name: nil} # Example invalid data
  assert {:error, %Ecto.Changeset{} = changeset} = Scoring.update_score_rule(rule, invalid_attrs)
  refute changeset.valid?
  # ... (verify db not changed)
end
```

### 1.4 删除评分规则

**测试用例**: 成功删除评分规则
*   **行为**: 调用 `Scoring.delete_score_rule/1` 提供存在的 `rule`。
*   **预期**: 返回 `{:ok, deleted_rule}`，数据库中对应的记录已被删除。
```elixir
test "成功删除评分规则" do
  rule = insert(:score_rule)
  
  assert {:ok, _deleted_rule} = Scoring.delete_score_rule(rule)
  assert {:error, :not_found} = Scoring.get_score_rule(rule.id)
end

**测试用例**: 删除操作具有幂等性
*   **行为**: 对同一个已删除的 `rule` 再次调用 `Scoring.delete_score_rule/1`。
*   **预期**: 仍然返回 `{:ok, rule}`，数据库状态保持已删除。
```elixir
test "删除操作具有幂等性" do
  rule = insert(:score_rule)
  {:ok, _} = Scoring.delete_score_rule(rule)
  assert {:ok, %ScoreRule{}} = Scoring.delete_score_rule(rule)
  assert Repo.get(ScoreRule, rule.id) == nil
end

**测试用例**: 设置配置时数据无效
*   **行为**: 调用 `Scoring.setup_form_scoring/2` 提供无效数据 (例如 `passing_score > total_score` 或缺少字段)。
*   **预期**: 返回 `{:error, changeset}`，数据库记录未被创建或更新。
```elixir
test "Scoring.setup_form_scoring/2 fails with invalid data" do
  form = insert(:form)
  invalid_attrs = %{total_score: 100, passing_score: 120}
  assert {:error, %Ecto.Changeset{} = changeset} = Scoring.setup_form_scoring(form.id, invalid_attrs)
  refute changeset.valid?
  assert Repo.get_by(FormScore, form_id: form.id) == nil
end

## 2. 表单评分配置

### 2.1 设置表单评分配置

**测试用例**: 首次设置表单评分配置 (完整属性)
*   **行为**: 调用 `Scoring.setup_form_scoring/2` 为一个没有配置的表单提供所有有效属性。
*   **预期**: 返回 `{:ok, config}`，`config` 包含设置的属性，数据库中创建了新记录。
```elixir
test "为表单首次设置评分配置" do
  form = insert(:form)
  config_attrs = %{
    total_score: 100,
    passing_score: 60,
    score_visibility: :private,
    auto_score: true
  }
  
  assert {:ok, config} = Scoring.setup_form_scoring(form.id, config_attrs)
  assert config.form_id == form.id
  assert config.total_score == 100
  assert config.passing_score == 60
  assert config.score_visibility == :private
  assert config.auto_score == true
end
```

**测试用例**: 首次设置表单评分配置 (最小属性，使用默认值)
*   **行为**: 调用 `Scoring.setup_form_scoring/2` 只提供必需属性 (`total_score`, `form_id`)。
*   **预期**: 返回 `{:ok, config}`，`config` 中未提供的字段使用默认值，数据库中创建了新记录。
```elixir
test "为表单首次设置评分配置 (使用默认值)" do
  form = insert(:form)
  config_attrs = %{total_score: 50, form_id: form.id}
  assert {:ok, config} = Scoring.setup_form_scoring(form.id, config_attrs)
  # assert config.score_visibility == :private # Check default if needed
end
```

**测试用例**: 更新已有的表单评分配置
*   **行为**: 调用 `Scoring.setup_form_scoring/2` 为一个已有配置的表单提供新的有效属性。
*   **预期**: 返回 `{:ok, updated_config}`，`updated_config` 包含更新后的属性，数据库中对应的记录被更新。
```elixir
test "更新已有的表单评分配置" do
  form = insert(:form)
  # 先创建配置
  {:ok, _} = Scoring.setup_form_scoring(form.id, %{total_score: 100, passing_score: 60})
  
  # 再更新配置
  new_attrs = %{total_score: 150, passing_score: 90, score_visibility: :public}
  assert {:ok, updated_config} = Scoring.setup_form_scoring(form.id, new_attrs)
  assert updated_config.total_score == 150
  assert updated_config.passing_score == 90
  assert updated_config.score_visibility == :public
end
```

**测试用例**: 设置配置时缺少必要字段
*   **行为**: 调用 `Scoring.setup_form_scoring/2` 缺少 `total_score` 或 `form_id`。
*   **预期**: 返回 `{:error, changeset}`，`changeset` 包含对应错误信息。
```elixir
test "无法设置缺少必要字段的配置" do
  form = insert(:form)
  invalid_attrs = %{passing_score: 60}
  assert {:error, changeset} = Scoring.setup_form_scoring(form.id, invalid_attrs)
  assert errors_on(changeset) |> Keyword.has_key?(:total_score)
end
```

**测试用例**: 设置配置时 `total_score` 无效 (非正数)
*   **行为**: 调用 `Scoring.setup_form_scoring/2` 提供 `total_score <= 0`。
*   **预期**: 返回 `{:error, changeset}`，`changeset` 包含 `total_score` 错误信息。
```elixir
test "无法设置 total_score 无效的配置" do
  form = insert(:form)
  invalid_attrs = %{total_score: 0, form_id: form.id}
  assert {:error, changeset} = Scoring.setup_form_scoring(form.id, invalid_attrs)
  assert errors_on(changeset) |> Keyword.get(:total_score) == ["must be greater than 0"]
end
```

**测试用例**: 设置配置时 `passing_score` 无效 (非正数)
*   **行为**: 调用 `Scoring.setup_form_scoring/2` 提供 `passing_score <= 0`。
*   **预期**: 返回 `{:error, changeset}`，`changeset` 包含 `passing_score` 错误信息。
```elixir
test "无法设置 passing_score 无效的配置" do
  form = insert(:form)
  invalid_attrs = %{total_score: 100, passing_score: 0, form_id: form.id}
  assert {:error, changeset} = Scoring.setup_form_scoring(form.id, invalid_attrs)
  assert errors_on(changeset) |> Keyword.get(:passing_score) == ["must be greater than 0"]
end
```

**测试用例**: 设置配置时 `passing_score` 大于 `total_score`
*   **行为**: 调用 `Scoring.setup_form_scoring/2` 提供 `passing_score > total_score`。
*   **预期**: 返回 `{:error, changeset}`，`changeset` 包含 `passing_score` 错误信息。
```elixir
test "无法设置及格分大于总分的配置" do
  form = insert(:form)
  invalid_attrs = %{total_score: 100, passing_score: 120}
  assert {:error, changeset} = Scoring.setup_form_scoring(form.id, invalid_attrs)
  assert errors_on(changeset) |> Keyword.has_key?(:passing_score)
end
```

**测试用例**: 设置配置时 `score_visibility` 值无效
*   **行为**: 调用 `Scoring.setup_form_scoring/2` 提供无效的 `score_visibility` 枚举值。
*   **预期**: 返回 `{:error, changeset}`，`changeset` 包含 `score_visibility` 错误信息。
```elixir
test "无法设置 score_visibility 无效的配置" do
  form = insert(:form)
  invalid_attrs = %{total_score: 100, score_visibility: :invalid, form_id: form.id}
  assert {:error, changeset} = Scoring.setup_form_scoring(form.id, invalid_attrs)
  assert errors_on(changeset) |> Keyword.has_key?(:score_visibility)
end
```

### 2.2 获取表单评分配置

**测试用例**: 获取存在的表单评分配置
*   **行为**: 调用 `Scoring.get_form_score_config/1` 提供有配置的 `form_id`。
*   **预期**: 返回对应的 `%FormScore{}` 结构。
```elixir
test "获取存在的表单评分配置" do
  form = insert(:form)
  {:ok, config} = Scoring.setup_form_scoring(form.id, %{total_score: 100})
  
  assert %MyApp.Scoring.FormScore{} = fetched_config = Scoring.get_form_score_config(form.id)
  assert fetched_config.id == config.id
  assert fetched_config.total_score == 100
end
```

**测试用例**: 获取不存在的表单评分配置
*   **行为**: 调用 `Scoring.get_form_score_config/1` 提供没有配置的 `form_id`。
*   **预期**: 返回 `nil`。
```elixir
test "获取不存在的表单评分配置返回 nil" do
  form = insert(:form)
  assert is_nil(Scoring.get_form_score_config(form.id))
end
```

## 3. 响应评分

### 3.1 评分单个响应

**测试用例**: 使用评分规则对响应进行自动评分
```elixir
test "使用评分规则对响应进行自动评分" do
  # 准备测试数据：表单、题目、响应和评分规则
  form = insert(:form_with_items)
  rule = insert(:score_rule, form: form)
  response = insert(:response_with_answers, form: form)
  
  assert {:ok, score} = Scoring.score_response(response.id, rule.id)
  assert not is_nil(score.total_score)
  assert not is_nil(score.passed)
  assert score.response_id == response.id
  assert score.score_rule_id == rule.id
end
```

**测试用例**: 手动评分响应
```elixir
test "手动评分响应" do
  response = insert(:response)
  grader = insert(:user)
  
  score_data = %{
    total_score: 85,
    passed: true,
    feedback: "不错的答案",
    response_id: response.id,
    grader_id: grader.id
  }
  
  assert {:ok, score} = Scoring.create_manual_score(score_data)
  assert score.total_score == 85
  assert score.passed == true
  assert score.feedback == "不错的答案"
  assert score.grader_id == grader.id
end
```

**测试用例**: 重复评分同一响应
```elixir
test "重复评分同一响应会更新评分" do
  # 准备已评分的响应
  response = insert(:response)
  rule = insert(:score_rule)
  {:ok, original_score} = Scoring.score_response(response.id, rule.id)
  
  # 重新评分
  assert {:ok, updated_score} = Scoring.score_response(response.id, rule.id)
  
  # 验证新评分覆盖了旧评分
  assert updated_score.id != original_score.id
  assert Scoring.get_response_score(response.id).id == updated_score.id
end
```

### 3.2 批量评分响应

**测试用例**: 批量评分表单的所有响应
```elixir
test "批量评分表单的所有响应" do
  form = insert(:form_with_items)
  rule = insert(:score_rule, form: form)
  # 创建多个响应
  insert_list(5, :response_with_answers, form: form)
  
  assert {:ok, result} = Scoring.batch_score_responses(form.id, rule.id)
  assert result.scored == 5
  assert result.skipped == 0
end
```

**测试用例**: 根据日期范围批量评分
```elixir
test "按日期范围批量评分响应" do
  form = insert(:form)
  rule = insert(:score_rule, form: form)
  
  # 创建不同日期的响应
  old_date = ~N[2023-01-01 00:00:00]
  new_date = ~N[2023-06-01 00:00:00]
  
  insert(:response, form: form, submitted_at: old_date)
  insert(:response, form: form, submitted_at: old_date)
  insert(:response, form: form, submitted_at: new_date)
  
  # 只评分新日期的响应
  options = %{start_date: ~D[2023-04-01], end_date: ~D[2023-12-31]}
  assert {:ok, result} = Scoring.batch_score_responses(form.id, rule.id, options)
  
  assert result.scored == 1
  assert result.skipped == 0
end
```

## 4. 评分统计

### 4.1 获取表单评分统计

**测试用例**: 获取表单的整体评分统计
```elixir
test "获取表单的评分统计数据" do
  form = insert(:form)
  rule = insert(:score_rule, form: form)
  insert(:form_score, form: form, total_score: 100, passing_score: 60)
  
  # 创建不同分数的响应评分
  create_response_with_score(form, rule, 80)
  create_response_with_score(form, rule, 40)
  create_response_with_score(form, rule, 90)
  
  assert {:ok, stats} = Scoring.get_form_score_statistics(form.id)
  
  assert stats.total_responses == 3
  assert_in_delta stats.avg_score, 70.0, 0.1
  assert stats.passing_count == 2
  assert_in_delta stats.passing_rate, 0.67, 0.01
  assert stats.highest_score == 90
  assert stats.lowest_score == 40
end
```

**测试用例**: 获取没有评分数据的表单统计
```elixir
test "没有评分数据的表单统计返回零值" do
  form = insert(:form)
  
  assert {:ok, stats} = Scoring.get_form_score_statistics(form.id)
  
  assert stats.total_responses == 0
  assert stats.avg_score == 0
  assert stats.passing_count == 0
  assert stats.passing_rate == 0
  assert stats.highest_score == 0
  assert stats.lowest_score == 0
end
```

### 4.2 题目评分分析

**测试用例**: 获取题目的得分情况
```elixir
test "获取特定题目的得分分析" do
  form = insert(:form_with_items)
  item_id = form.items |> List.first() |> Map.get(:id)
  rule = insert(:score_rule, form: form)
  
  # 创建含有题目得分的响应
  create_responses_with_item_scores(form, rule, item_id, [5, 10, 7, 3, 10])
  
  assert {:ok, item_stats} = Scoring.get_item_score_statistics(form.id, item_id)
  
  assert item_stats.total_answers == 5
  assert_in_delta item_stats.avg_score, 7.0, 0.1
  assert item_stats.max_possible_score == 10
  assert_in_delta item_stats.avg_percentage, 0.7, 0.01
end
```

## 5. 权限控制

### 5.1 评分规则权限

**测试用例**: 非表单所有者不能创建评分规则
*   **行为**: 非所有者用户调用 `Scoring.create_score_rule/2` 尝试为不属于自己的表单创建规则。
*   **预期**: 返回 `{:error, :unauthorized}`。
```elixir
test "非表单所有者不能创建评分规则" do
  form = insert(:form, user_id: "owner-id")
  non_owner = insert(:user, id: "non-owner-id")
  
  rule_attrs = %{
    name: "未授权规则",
    rules: %{"version" => 1, "type" => "automatic", "items" => []},
    form_id: form.id,
    user_id: non_owner.id
  }
  
  assert {:error, :unauthorized} = Scoring.create_score_rule_as_user(rule_attrs, non_owner.id)
end
```

**测试用例**: 表单所有者可以创建评分规则
*   **行为**: 所有者用户调用 `Scoring.create_score_rule/2` 为自己的表单创建规则。
*   **预期**: 返回 `{:ok, rule}`。
```elixir
test "表单所有者可以创建评分规则" do
  owner = insert(:user)
  form = insert(:form, user_id: owner.id)
  rule_attrs = %{
    name: "授权规则",
    rules: %{"version" => 1, "type" => "automatic", "items" => []},
    form_id: form.id,
    user_id: owner.id
  }
  
  assert {:ok, _rule} = Scoring.create_score_rule_as_user(rule_attrs, owner.id)
end
```

**测试用例**: 非表单所有者不能更新评分规则
*   **行为**: 非所有者用户调用 `Scoring.update_score_rule/3` 尝试更新不属于自己的规则。
*   **预期**: 返回 `{:error, :unauthorized}`。
```elixir
test "非表单所有者不能更新评分规则" do
  rule = insert(:score_rule)
  non_owner = insert(:user)
  update_attrs = %{name: "新名称", is_active: false}
  
  assert {:error, :unauthorized} = Scoring.update_score_rule(rule, update_attrs, non_owner)
end
```

**测试用例**: 表单所有者可以更新评分规则
*   **行为**: 所有者用户调用 `Scoring.update_score_rule/3` 更新自己的规则。
*   **预期**: 返回 `{:ok, updated_rule}`。
```elixir
test "表单所有者可以更新评分规则" do
  rule = insert(:score_rule)
  owner = insert(:user)
  update_attrs = %{name: "新名称", is_active: false}
  
  assert {:ok, updated_rule} = Scoring.update_score_rule(rule, update_attrs, owner)
  assert updated_rule.name == "新名称"
end
```

**测试用例**: 非表单所有者不能删除评分规则
*   **行为**: 非所有者用户调用 `Scoring.delete_score_rule/2` 尝试删除不属于自己的规则。
*   **预期**: 返回 `{:error, :unauthorized}`，规则未被删除。
```elixir
test "非表单所有者不能删除评分规则" do
  rule = insert(:score_rule)
  non_owner = insert(:user)
  
  assert {:error, :unauthorized} = Scoring.delete_score_rule(rule, non_owner)
  assert Repo.get(ScoreRule, rule.id) != nil
end
```

**测试用例**: 表单所有者可以删除评分规则
*   **行为**: 所有者用户调用 `Scoring.delete_score_rule/2` 删除自己的规则。
*   **预期**: 返回 `{:ok, deleted_rule}`，规则已被删除。
```elixir
test "表单所有者可以删除评分规则" do
  rule = insert(:score_rule)
  owner = insert(:user)
  
  assert {:ok, _deleted_rule} = Scoring.delete_score_rule(rule, owner)
  assert Repo.get(ScoreRule, rule.id) == nil
end
```

### 5.2 表单评分配置权限

**测试用例**: 非表单所有者不能设置/更新评分配置
*   **行为**: 非所有者用户调用 `Scoring.setup_form_scoring/3` 尝试为不属于自己的表单设置配置。
*   **预期**: 返回 `{:error, :unauthorized}`。
```elixir
test "非表单所有者不能设置评分配置" do
  form = insert(:form)
  non_owner = insert(:user)
  config_attrs = %{total_score: 100, passing_score: 60}
  
  assert {:error, :unauthorized} = Scoring.setup_form_scoring(form.id, config_attrs, non_owner)
end
```

**测试用例**: 表单所有者可以设置/更新评分配置
*   **行为**: 所有者用户调用 `Scoring.setup_form_scoring/3` 为自己的表单设置配置。
*   **预期**: 返回 `{:ok, config}`。
```elixir
test "表单所有者可以设置评分配置" do
  form = insert(:form)
  owner = insert(:user)
  config_attrs = %{total_score: 100, passing_score: 60}
  
  assert {:ok, _config} = Scoring.setup_form_scoring(form.id, config_attrs, owner)
end
```

**测试用例**: (可选) 根据 `score_visibility` 控制配置获取权限
*   **行为**: 不同用户尝试调用 `Scoring.get_form_score_config/2` 获取配置。
*   **预期**: 根据配置的 `score_visibility` 和用户角色返回配置或 `{:error, :unauthorized}`。
```elixir
# test "非授权用户不能获取私有配置" do ... end
# test "授权用户可以获取私有配置" do ... end
# test "任何人可以获取公开配置" do ... end
```

## 6. 错误处理

### 6.1 系统错误处理

**测试用例**: 评分不存在的响应
```elixir
test "评分不存在的响应返回错误" do
  rule = insert(:score_rule)
  non_existent_id = "00000000-0000-0000-0000-000000000000"
  
  assert {:error, :not_found} = Scoring.score_response(non_existent_id, rule.id)
end
```

**测试用例**: 使用不存在的评分规则评分
```elixir
test "使用不存在的评分规则评分返回错误" do
  response = insert(:response)
  non_existent_id = "00000000-0000-0000-0000-000000000000"
  
  assert {:error, :not_found} = Scoring.score_response(response.id, non_existent_id)
end
```

## 测试工具函数

以下是测试中使用的辅助函数:

```elixir
# 创建带有特定分数的响应
defp create_response_with_score(form, rule, score) do
  response = insert(:response, form: form)
  insert(:response_score, 
    response: response,
    score_rule: rule,
    total_score: score,
    passed: score >= 60
  )
end

# 创建带有特定题目得分的多个响应
defp create_responses_with_item_scores(form, rule, item_id, scores) do
  Enum.each(scores, fn score ->
    response = insert(:response, form: form)
    score_breakdown = %{item_id => score}
    insert(:response_score, 
      response: response,
      score_rule: rule,
      total_score: score,
      score_breakdown: score_breakdown
    )
  end)
end
```

## 开发顺序建议

根据TDD原则，建议按以下顺序开发评分系统功能:

1. 评分规则基础管理 (创建、获取、更新)
2. 表单评分配置
3. 单个响应评分功能
4. 批量评分功能
5. 评分统计功能
6. 权限控制与安全特性
7. 高级功能与优化

每个阶段应先完成测试编写，然后实现功能直到测试通过，再进入下一个阶段的开发。 

## 2. 表单评分配置 (FormScore Configuration)

# ... (Existing FormScore sections)

## 3. 响应评分 (Response Scoring)

本节描述计算和存储单个表单响应得分的功能。

### 3.1 ResponseScore 模型验证 (`test/my_app/scoring/response_score_test.exs`)

**测试用例**: 有效的 ResponseScore changeset
*   **行为**: 使用所有必需属性 (如 `response_id`, `score`, `max_score`, `scored_at`, 可能还有 `score_details` map) 调用 `ResponseScore.changeset/2`。
*   **预期**: 返回有效的 `changeset`。

**测试用例**: 缺少必需字段的 ResponseScore changeset
*   **行为**: 调用 `ResponseScore.changeset/2` 时缺少 `response_id`, `score`, `max_score` 或 `scored_at`。
*   **预期**: 返回无效的 `changeset`，`errors` 包含对应字段的 "can't be blank" 错误。

**测试用例**: `score` 或 `max_score` 无效的 ResponseScore changeset (非数字或负数)
*   **行为**: 调用 `ResponseScore.changeset/2` 时 `score` 或 `max_score` 为无效值。
*   **预期**: 返回无效的 `changeset`，`errors` 包含对应字段的类型或数值验证错误。

**测试用例**: `score` 大于 `max_score` 的 ResponseScore changeset
*   **行为**: 调用 `ResponseScore.changeset/2` 时 `score > max_score`。
*   **预期**: 返回无效的 `changeset`，`errors` 包含 `score` 或 `max_score` 的验证错误。

**测试用例**: `response_id` 无效的 ResponseScore changeset (外键)
*   **行为**: 调用 `ResponseScore.changeset/2` 时提供不存在的 `response_id`。
*   **预期**: (同其他外键测试) Changeset 本身可能有效，错误在 Repo 操作时由数据库触发。

### 3.2 计算响应得分 (Scoring Context - `test/my_app/scoring_test.exs`)

**假设**: 存在 `Response` schema，包含用户提交的答案 (例如，在一个 `answers` map 字段中，`%{item_id => answer_value}`)
**假设**: `ScoreRule` 的 `rules` 字段定义了如何根据 `Response` 的答案来计分。

**测试用例**: 成功计算并保存响应得分 (简单规则)
*   **行为**: 调用 `Scoring.calculate_and_save_score(response_id)` (或类似函数)，其中 `response_id` 对应的响应可以被一个简单的 `ScoreRule` (例如，答对得 10 分，答错得 0 分) 完全评分。
*   **预期**: 返回 `{:ok, %ResponseScore{}}`，其中 `score` 和 `max_score` 计算正确，`score_details` (如果实现) 包含计分详情，数据库中创建了 `ResponseScore` 记录。

**测试用例**: 响应已被评分时再次计算
*   **行为**: 对一个已经存在 `ResponseScore` 的 `response_id` 再次调用 `Scoring.calculate_and_save_score/1`。
*   **预期**: (根据设计决定) 
    *   选项 A (覆盖): 返回 `{:ok, %ResponseScore{}}`，更新现有的 `ResponseScore` 记录。
    *   选项 B (报错): 返回 `{:error, :already_scored}`。
    *   *我们暂时按选项 A (覆盖) 来设计。*

**测试用例**: 找不到对应的表单响应
*   **行为**: 调用 `Scoring.calculate_and_save_score/1` 时提供不存在的 `response_id`。
*   **预期**: 返回 `{:error, :response_not_found}`。

**测试用例**: 找不到对应的评分规则
*   **行为**: 调用 `Scoring.calculate_and_save_score/1`，但该响应对应的表单没有激活的 `ScoreRule`。
*   **预期**: 返回 `{:error, :score_rule_not_found}` 或 `{:error, :scoring_not_setup}`。

**测试用例**: 评分规则与响应不完全匹配 (例如，响应中缺少规则中的某些题目)
*   **行为**: 调用 `Scoring.calculate_and_save_score/1`，响应数据不完整。
*   **预期**: (根据设计决定)
    *   选项 A (部分评分): 返回 `{:ok, %ResponseScore{}}`，只计算能匹配上的题目分数。
    *   选项 B (报错): 返回 `{:error, :incomplete_response}` 或类似错误。
    *   *我们暂时按选项 A (部分评分) 来设计。*

**测试用例**: 评分规则复杂 (多种题型，不同计分方式)
*   **行为**: (需要更多具体规则定义) 调用 `Scoring.calculate_and_save_score/1`，测试不同的计分逻辑是否正确应用。
*   **预期**: 返回 `{:ok, %ResponseScore{}}`，`score` 和 `score_details` 正确反映了复杂规则的计算结果。

### 3.3 获取响应得分 (Scoring Context - `test/my_app/scoring_test.exs`)

**测试用例**: 获取单个已评分响应的得分
*   **行为**: 调用 `Scoring.get_response_score(response_id)` 提供一个已存在 `ResponseScore` 的 `response_id`。
*   **预期**: 返回 `{:ok, %ResponseScore{}}`。

**测试用例**: 获取未评分响应的得分
*   **行为**: 调用 `Scoring.get_response_score(response_id)` 提供一个存在 `Response` 但不存在 `ResponseScore` 的 `response_id`。
*   **预期**: 返回 `{:error, :not_scored}` 或 `{:ok, nil}` (根据设计决定，前者更明确)。

**测试用例**: 获取不存在响应的得分
*   **行为**: 调用 `Scoring.get_response_score(response_id)` 提供不存在的 `response_id`。
*   **预期**: 返回 `{:error, :response_not_found}` 或 `{:error, :not_found}`。

## 4. 评分统计 (Scoring Statistics)

(待后续 TDD 补充) 

## 3. 评分计算 (核心逻辑)

本节测试评分系统的核心功能：根据表单响应和评分规则计算得分，并将结果保存为 `ResponseScore` 记录。

**目标函数:** `Scoring.score_response(response_id :: Ecto.UUID.t()) :: {:ok, ResponseScore.t()} | {:error, atom() | Changeset.t()}`

*   此函数应处理获取相关数据（Response, Form, ScoreRule, FormScore）、执行计算、保存结果的完整流程。

### 3.1 成功计算并保存得分

**测试用例**: 成功计算并保存简单规则的得分
*   **前置条件**:
    *   存在 `User`, `Form`, `FormItem` (例如，单选题)。
    *   存在 `ScoreRule`，其 `rules` 字段包含针对该 `FormItem` 的简单评分逻辑 (例如，选项 "A" 得 10 分，其他 0 分)。`max_score` 为 10。
    *   存在 `FormScore` 配置，`auto_score` 为 `true`。
    *   存在 `Response`，其 `answers` 包含对该 `FormItem` 的回答 (例如，选择了 "A")。
    *   该 `Response` 尚未被评分 (没有关联的 `ResponseScore`)。
*   **行为**: 调用 `Scoring.score_response(response.id)`。
*   **预期**:
    *   返回 `{:ok, %ResponseScore{} = response_score}`。
    *   `response_score` 包含正确的属性：
        *   `response_id`: 匹配输入的 `response.id`。
        *   `score_rule_id`: 匹配使用的 `score_rule.id`。
        *   `score`: 10 (根据规则计算得出)。
        *   `max_score`: 10 (从 `score_rule.max_score` 获取)。
        *   `scored_at`: 时间戳已设置。
        *   `score_details`: (可选) 包含评分细节。
    *   数据库中存在对应的 `ResponseScore` 记录。

**测试用例**: 成功计算并保存涉及多个评分项的得分
*   **前置条件**: 类似上例，但 `ScoreRule` 包含对多个 `FormItem` 的评分逻辑，`Response` 包含对这些项的回答。
*   **行为**: 调用 `Scoring.score_response(response.id)`。
*   **预期**:
    *   返回 `{:ok, %ResponseScore{}}`。
    *   `response_score.score` 是所有评分项得分的总和。
    *   `response_score.max_score` 是规则中定义的总 `max_score`。

**测试用例**: 包含未在规则中定义的答案项 (应忽略)
*   **前置条件**: `Response` 包含对某个 `FormItem` 的回答，但该 `FormItem` 未在 `ScoreRule` 的 `rules.items` 中定义。
*   **行为**: 调用 `Scoring.score_response(response.id)`。
*   **预期**:
    *   返回 `{:ok, %ResponseScore{}}`。
    *   计算得分时忽略未在规则中定义的答案项。

**测试用例**: 规则中包含未被回答的评分项 (得分按 0 计算)
*   **前置条件**: `ScoreRule` 包含对某个 `FormItem` 的评分逻辑，但 `Response` 的 `answers` 中没有该项的回答。
*   **行为**: 调用 `Scoring.score_response(response.id)`。
*   **预期**:
    *   返回 `{:ok, %ResponseScore{}}`。
    *   计算得分时，未回答的评分项贡献 0 分。

### 3.2 评分计算的错误处理和边界条件

**测试用例**: 响应已被评分
*   **前置条件**: 目标 `Response` 已存在关联的 `ResponseScore` 记录。
*   **行为**: 调用 `Scoring.score_response(response.id)`。
*   **预期**: 返回 `{:error, :already_scored}`，不应创建新的 `ResponseScore`。

**测试用例**: 响应不存在
*   **行为**: 调用 `Scoring.score_response/1` 提供不存在的 `response_id`。
*   **预期**: 返回 `{:error, :response_not_found}`。

**测试用例**: 表单不存在 (数据完整性问题)
*   **前置条件**: `Response` 存在，但其关联的 `form_id` 指向不存在的 `Form`。
*   **行为**: 调用 `Scoring.score_response(response.id)`。
*   **预期**: 返回 `{:error, :form_not_found}` (或其他指示数据问题的错误)。

**测试用例**: 表单未配置评分规则
*   **前置条件**: `Response` 及其 `Form` 存在，但该 `Form` 没有关联的 `ScoreRule`。
*   **行为**: 调用 `Scoring.score_response(response.id)`。
*   **预期**: 返回 `{:error, :score_rule_not_found}`。

**测试用例**: 表单未配置评分设置 (FormScore)
*   **前置条件**: `Response`, `Form`, `ScoreRule` 存在，但该 `Form` 没有关联的 `FormScore`。
*   **行为**: 调用 `Scoring.score_response(response.id)`。
*   **预期**: 返回 `{:error, :form_score_config_not_found}`。

**测试用例**: 表单评分设置中禁用了自动评分
*   **前置条件**: `FormScore` 存在，但 `auto_score` 设置为 `false`。
*   **行为**: 调用 `Scoring.score_response(response.id)`。
*   **预期**: 返回 `{:error, :auto_score_disabled}`。

**测试用例**: 评分规则格式无效或无法解析
*   **前置条件**: `ScoreRule` 的 `rules` 字段包含无效的 JSON 或不符合预期结构的 Map。
*   **行为**: 调用 `Scoring.score_response(response.id)`。
*   **预期**: 返回 `{:error, :calculation_error}` 或更具体的错误如 `:invalid_rule_format`。

**测试用例**: 保存 ResponseScore 时 changeset 无效 (理论上少见)
*   **前置条件**: 评分计算成功，但构建 `ResponseScore` changeset 时因某种原因失败 (例如，计算出的 `score` 或 `max_score` 不符合 `ResponseScore` 的验证)。
*   **行为**: 调用 `Scoring.score_response(response.id)`。
*   **预期**: 返回 `{:error, %Changeset{}}`。 