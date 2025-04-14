# 表单评分系统 TDD 测试文档

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