# 表单评分系统设计方案

## 实施状态更新

**更新日期**: 2025-04-15

**实施状态**: ✅ 核心功能已实现并完成优化

评分系统的所有关键功能已经实现并通过测试，系统当前能够：

1. **创建和管理评分规则**：支持创建、读取、更新和删除表单评分规则
2. **配置表单评分设置**：可以定义总分、通过分数、评分可见性和自动评分开关
3. **自动评分计算**：根据预定义规则对表单响应进行自动评分
4. **错误处理**：适当处理所有边缘情况和异常情况
5. **批量导出功能**：支持导出回答和评分数据
6. **智能评分界面**：根据控件类型提供专门的正确答案输入界面
7. **高级评分功能**：支持填空题分空评分、多选题部分得分等复杂场景

**最新完成功能**：
- 评分规则编辑器已重新设计，可根据所选题目类型动态显示不同的答案输入界面
- 填空题支持显示完整题目文本，并为每个空位单独设置分值
- 实现控件类型感知的评分算法，提高评分精度和灵活性

### 实现摘要

已实现的主要组件包括：

| 组件 | 文件 | 说明 |
|------|------|------|
| **上下文模块** | `lib/my_app/scoring.ex` | 提供所有评分业务逻辑和API |
| **评分规则模型** | `lib/my_app/scoring/score_rule.ex` | 定义评分规则数据结构和验证 |
| **表单评分配置模型** | `lib/my_app/scoring/form_score.ex` | 定义表单级别的评分配置 |
| **响应评分模型** | `lib/my_app/scoring/response_score.ex` | 存储每个响应的评分结果 |
| **前端界面** | `lib/my_app_web/live/scoring/` | LiveView界面和组件 |
| **数据导出** | `lib/my_app/responses.ex` | 响应和评分数据导出功能 |

基础功能的测试用例已通过，确保系统的稳定性。最近的改进包括：

1. **自动评分功能**：表单提交后自动触发评分，提高用户体验
2. **批量导出功能**：实现导出带评分数据的回答记录
3. **代码优化**：修复编译警告，提高代码质量

## 1. 概述

评分系统是对表单系统的功能扩展，允许为提交的表单响应自动或手动评分，特别适用于测验、考试、问卷评估等场景。该系统作为独立的上下文(Context)模块，与现有的表单和响应系统无缝集成。

## 2. 模块结构

### 2.1 核心模块

```elixir
defmodule MyApp.Scoring do
  @moduledoc """
  评分系统上下文模块。
  
  提供对表单响应进行评分的功能，包括评分规则设置、批量评分和评分统计等。
  """
  
  import Ecto.Query, warn: false
  alias MyApp.Repo
  alias MyApp.Scoring.ScoreRule
  alias MyApp.Scoring.FormScore
  alias MyApp.Scoring.ResponseScore
  alias MyApp.Forms
  alias MyApp.Responses
  
  # API 函数...
end
```

### 2.2 数据模型

#### 评分规则(ScoreRule)

```elixir
defmodule MyApp.Scoring.ScoreRule do
  @moduledoc """
  表单评分规则模型。
  
  定义了如何对表单响应进行评分的规则。
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "scoring_rules" do
    field :name, :string
    field :description, :string
    field :rules, :map  # 存储JSON格式的评分规则
    field :max_score, :integer
    field :is_active, :boolean, default: true
    
    belongs_to :form, MyApp.Forms.Form
    belongs_to :user, MyApp.Accounts.User
    
    timestamps()
  end
  
  @doc false
  def changeset(score_rule, attrs) do
    score_rule
    |> cast(attrs, [:name, :description, :rules, :max_score, :is_active, :form_id, :user_id])
    |> validate_required([:name, :rules, :form_id])
    |> validate_number(:max_score, greater_than: 0)
    |> validate_rules_structure()
    |> foreign_key_constraint(:form_id)
    |> foreign_key_constraint(:user_id)
  end
  
  defp validate_rules_structure(changeset) do
    case get_change(changeset, :rules) do
      nil -> changeset
      rules when is_map(rules) ->
        if validate_rules_format(rules) do
          changeset
        else
          add_error(changeset, :rules, "评分规则格式无效")
        end
      _ -> add_error(changeset, :rules, "评分规则必须是JSON对象")
    end
  end
  
  defp validate_rules_format(rules) do
    # 检查规则是否符合预期结构
    # 实际实现时需要更详细的验证
    is_map(rules) && Map.has_key?(rules, "items")
  end
end
```

#### 表单评分配置(FormScore)

```elixir
defmodule MyApp.Scoring.FormScore do
  @moduledoc """
  表单评分配置模型。
  
  存储表单整体的评分设置，如总分、评分模式等。
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "form_scores" do
    field :total_score, :integer, default: 100
    field :passing_score, :integer
    field :score_visibility, Ecto.Enum, values: [:private, :public], default: :private
    field :auto_score, :boolean, default: true
    
    belongs_to :form, MyApp.Forms.Form
    
    timestamps()
  end
  
  @doc false
  def changeset(form_score, attrs) do
    form_score
    |> cast(attrs, [:total_score, :passing_score, :score_visibility, :auto_score, :form_id])
    |> validate_required([:total_score, :form_id])
    |> validate_number(:total_score, greater_than: 0)
    |> validate_number(:passing_score, greater_than: 0, less_than_or_equal_to: :total_score)
    |> foreign_key_constraint(:form_id)
  end
end
```

#### 响应评分(ResponseScore)

```elixir
defmodule MyApp.Scoring.ResponseScore do
  @moduledoc """
  响应评分模型。
  
  存储每个表单响应的评分结果。
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "response_scores" do
    field :total_score, :integer
    field :passed, :boolean
    field :score_breakdown, :map  # 存储JSON格式的分项评分
    field :feedback, :string
    
    belongs_to :response, MyApp.Responses.Response
    belongs_to :score_rule, MyApp.Scoring.ScoreRule
    belongs_to :grader, MyApp.Accounts.User
    
    timestamps()
  end
  
  @doc false
  def changeset(response_score, attrs) do
    response_score
    |> cast(attrs, [:total_score, :passed, :score_breakdown, :feedback, :response_id, :score_rule_id, :grader_id])
    |> validate_required([:total_score, :response_id])
    |> foreign_key_constraint(:response_id)
    |> foreign_key_constraint(:score_rule_id)
    |> foreign_key_constraint(:grader_id)
  end
end
```

## 3. 核心功能API

### 3.1 评分规则管理

```elixir
@doc """
创建评分规则。

## 参数
  - attrs: 评分规则属性

## 示例

    iex> create_score_rule(%{name: "问卷评分规则", form_id: form_id, rules: [...]})
    {:ok, %ScoreRule{}}
"""
def create_score_rule(attrs) do
  %ScoreRule{}
  |> ScoreRule.changeset(attrs)
  |> Repo.insert()
end

@doc """
获取表单的评分规则。

## 参数
  - form_id: 表单ID

## 示例

    iex> get_score_rules_for_form(form_id)
    [%ScoreRule{}, ...]
"""
def get_score_rules_for_form(form_id) do
  ScoreRule
  |> where([r], r.form_id == ^form_id)
  |> Repo.all()
end

@doc """
获取评分规则详情。

## 参数
  - id: 评分规则ID

## 示例

    iex> get_score_rule(rule_id)
    {:ok, %ScoreRule{}}
"""
def get_score_rule(id) do
  case Repo.get(ScoreRule, id) do
    nil -> {:error, :not_found}
    rule -> {:ok, rule}
  end
end

@doc """
更新评分规则。

## 参数
  - score_rule: 评分规则结构
  - attrs: 更新属性

## 示例

    iex> update_score_rule(score_rule, %{name: "新规则名称"})
    {:ok, %ScoreRule{}}
"""
def update_score_rule(%ScoreRule{} = score_rule, attrs) do
  score_rule
  |> ScoreRule.changeset(attrs)
  |> Repo.update()
end

@doc """
删除评分规则。

## 参数
  - score_rule: 评分规则结构

## 示例

    iex> delete_score_rule(score_rule)
    {:ok, %ScoreRule{}}
"""
def delete_score_rule(%ScoreRule{} = score_rule) do
  Repo.delete(score_rule)
end
```

### 3.2 表单评分配置

```elixir
@doc """
为表单设置评分配置。

## 参数
  - form_id: 表单ID
  - attrs: 评分配置属性

## 示例

    iex> setup_form_scoring(form_id, %{total_score: 100, passing_score: 60})
    {:ok, %FormScore{}}
"""
def setup_form_scoring(form_id, attrs) do
  # 检查是否已存在配置
  case get_form_score_config(form_id) do
    nil -> 
      # 创建新配置
      %FormScore{}
      |> FormScore.changeset(Map.put(attrs, :form_id, form_id))
      |> Repo.insert()
      
    config -> 
      # 更新现有配置
      config
      |> FormScore.changeset(attrs)
      |> Repo.update()
  end
end

@doc """
获取表单的评分配置。

## 参数
  - form_id: 表单ID

## 示例

    iex> get_form_score_config(form_id)
    %FormScore{}
"""
def get_form_score_config(form_id) do
  Repo.get_by(FormScore, form_id: form_id)
end
```

### 3.3 响应评分功能

```elixir
@doc """
评分单个响应。

## 参数
  - response_id: 响应ID
  - rule_id: 评分规则ID
  - grader_id: 评分人ID (可选)

## 示例

    iex> score_response(response_id, rule_id)
    {:ok, %ResponseScore{}}
"""
def score_response(response_id, rule_id, grader_id \\ nil) do
  with {:ok, response} <- get_response_with_answers(response_id),
       {:ok, rule} <- get_score_rule(rule_id),
       {:ok, form} <- get_form(response.form_id) do
    
    # 权限检查：检查 grader_id (如果提供) 或当前用户是否有权限评分
    # ... (省略权限检查逻辑)
    
    # 应用评分规则
    score_result = apply_scoring_rules(response, rule, form)
    
    # 创建或更新评分记录
    changeset_attrs = %{
      response_id: response_id,
      score_rule_id: rule_id,
      grader_id: grader_id,
      total_score: score_result.total_score,
      passed: score_result.passed,
      score_breakdown: score_result.breakdown
    }
    
    case get_response_score(response_id) do
      nil ->
        # 创建新评分
        %ResponseScore{}
        |> ResponseScore.changeset(changeset_attrs)
        |> Repo.insert()
        
      existing_score ->
        # 更新现有评分
        existing_score
        |> ResponseScore.changeset(changeset_attrs)
        |> Repo.update()
    end
  else
    error -> error
  end
end

@doc """
创建手动评分记录。此函数用于记录不需要自动计算的评分结果。

## 参数
  - attrs: 评分属性，包含 `response_id`, `grader_id`, `total_score`, `feedback` 等。

## 示例
    iex> create_manual_score(%{response_id: resp_id, grader_id: user_id, total_score: 80, feedback: "Good"})
    {:ok, %ResponseScore{}}
"""
def create_manual_score(attrs) do
  %ResponseScore{}
  |> ResponseScore.changeset(attrs)
  # 手动评分需要手动设置 passed 状态，或根据 form_score 配置计算
  # |> maybe_calculate_passed_status(attrs[:response_id])
  |> Repo.insert()
end

@doc """
批量评分表单响应。

## 参数
  - form_id: 表单ID
  - rule_id: 评分规则ID
  - options: 可选的评分选项，例如：
    - `start_date`: `Date.t()` - 只评分此日期之后的响应
    - `end_date`: `Date.t()` - 只评分此日期之前的响应
    - `overwrite`: `boolean()` - 是否覆盖已有的评分 (默认 false)

## 示例

    iex> batch_score_responses(form_id, rule_id)
    {:ok, %{scored: 10, skipped: 2}}
"""
def batch_score_responses(form_id, rule_id, options \\ %{}) do
  # 获取评分规则
  with {:ok, rule} <- get_score_rule(rule_id),
       {:ok, form} <- get_form(form_id) do
    
    # 获取筛选的响应
    responses = Responses.list_responses_for_form(form_id)
    
    # 应用筛选条件 (包括 options 中的其他条件如 overwrite)
    responses = filter_responses(responses, options)
    
    # 评分每个响应
    results =
      Enum.map(responses, fn response ->
        case score_response(response.id, rule_id) do
          {:ok, score} -> {:scored, score}
          _ -> :skipped
        end
      end)
    
    # 统计结果
    scored_count = Enum.count(results, fn r -> match?({:scored, _}, r) end)
    skipped_count = Enum.count(results, fn r -> r == :skipped end)
    
    {:ok, %{scored: scored_count, skipped: skipped_count}}
  else
    error -> error
  end
end

@doc """
获取响应的评分。

## 参数
  - response_id: 响应ID

## 示例

    iex> get_response_score(response_id)
    %ResponseScore{}
"""
def get_response_score(response_id) do
  ResponseScore
  |> where([s], s.response_id == ^response_id)
  |> order_by([s], desc: s.inserted_at)
  |> limit(1)
  |> Repo.one()
end
```

### 3.4 评分统计功能

```elixir
@doc """
获取表单的评分统计数据。

## 参数
  - form_id: 表单ID
  - options: 可选的筛选选项，例如：
    - `start_date`: `Date.t()` - 只统计此日期之后的评分
    - `end_date`: `Date.t()` - 只统计此日期之前的评分

## 示例

    iex> get_form_score_statistics(form_id)
    {:ok, %{avg_score: 85.5, passing_rate: 0.9, ...}}
"""
def get_form_score_statistics(form_id, options \\ %{}) do
  # 获取表单的所有评分
  query =
    from s in ResponseScore,
      join: r in assoc(s, :response),
      where: r.form_id == ^form_id
  
  # 应用日期筛选
  query =
    if options[:start_date] do
      start_date = date_to_datetime(options[:start_date], :start_of_day)
      from [s, r] in query, where: r.submitted_at >= ^start_date
    else
      query
    end
  
  query =
    if options[:end_date] do
      end_date = date_to_datetime(options[:end_date], :end_of_day)
      from [s, r] in query, where: r.submitted_at <= ^end_date
    else
      query
    end
  
  # 执行查询
  scores = Repo.all(query)
  
  # 计算统计数据
  total = length(scores)
  
  if total > 0 do
    # 计算平均分
    total_points = Enum.reduce(scores, 0, fn score, acc -> acc + score.total_score end)
    avg_score = total_points / total
    
    # 计算及格率
    passing = Enum.count(scores, & &1.passed)
    passing_rate = passing / total
    
    # 计算分数分布
    distribution = calculate_score_distribution(scores)
    
    {:ok, %{
      total_responses: total,
      avg_score: avg_score,
      passing_count: passing,
      passing_rate: passing_rate,
      highest_score: Enum.max_by(scores, & &1.total_score).total_score,
      lowest_score: Enum.min_by(scores, & &1.total_score).total_score,
      distribution: distribution
    }}
  else
    {:ok, %{
      total_responses: 0,
      avg_score: 0,
      passing_count: 0,
      passing_rate: 0,
      highest_score: 0,
      lowest_score: 0,
      distribution: []
    }}
  end
end

@doc """
获取单个题目的评分统计数据。

## 参数
  - form_id: 表单ID
  - item_id: 表单项ID
  - options: 可选的筛选选项 (同上)

## 返回
  {:ok, %{total_answers: integer(), avg_score: float(), max_possible_score: integer(), avg_percentage: float(), distribution: map()}}

## 示例
    iex> get_item_score_statistics(form_id, item_id)
    {:ok, %{avg_score: 7.5, total_answers: 50, ...}}
"""
def get_item_score_statistics(form_id, item_id, options \\ %{}) do
  # 获取表单项信息以确定最大可能分数
  form_item = Forms.get_form_item(item_id)
  max_possible_score = get_item_max_score(form_item) # 需要辅助函数
  
  # 构建查询，从 score_breakdown 中提取特定项的分数
  query = 
    from s in ResponseScore,
      join: r in assoc(s, :response),
      where: r.form_id == ^form_id and not is_nil(s.score_breakdown)
      # ... (添加日期筛选等 options)
  
  scores_data = Repo.all(query)
  
  item_scores = 
    Enum.map(scores_data, fn score_record ->
      Map.get(score_record.score_breakdown || %{}, Atom.to_string(item_id), 0)
    end)
    |> Enum.filter(&(&1 != 0)) # 或者处理 nil/0 的情况

  total_answers = length(item_scores)
  
  if total_answers > 0 do
    avg_score = Enum.sum(item_scores) / total_answers
    avg_percentage = if max_possible_score > 0, do: avg_score / max_possible_score, else: 0
    # distribution = calculate_item_score_distribution(item_scores) # 需要辅助函数
    
    {:ok, %{
      total_answers: total_answers,
      avg_score: avg_score,
      max_possible_score: max_possible_score,
      avg_percentage: avg_percentage
      # distribution: distribution
    }}
  else
     {:ok, %{
      total_answers: 0,
      avg_score: 0,
      max_possible_score: max_possible_score,
      avg_percentage: 0
      # distribution: []
    }}
  end
end
```

## 4. 评分规则结构

评分规则存储为JSON格式，支持多种评分方法，适应不同题型：

```json
{
  "version": 1,
  "type": "automatic",
  "items": [
    {
      "item_id": "item-uuid-1",
      "max_score": 10,
      "scoring_method": "exact_match",
      "correct_answer": "option-uuid-3",
      "partial_credit": false
    },
    {
      "item_id": "item-uuid-2",
      "max_score": 20,
      "scoring_method": "keyword_match",
      "keywords": ["关键词1", "关键词2"],
      "match_all": false,
      "case_sensitive": false
    },
    {
      "item_id": "item-uuid-3",
      "max_score": 15,
      "scoring_method": "range_match",
      "range": {
        "min": 4, 
        "max": 5
      }
    },
    {
      "item_id": "item-uuid-4",
      "max_score": 5,
      "scoring_method": "multi_choice_match",
      "correct_answers": ["option-uuid-1", "option-uuid-3"],
      "require_all": true,
      "partial_credit": true
    },
    {
      "item_id": "item-uuid-5",
      "max_score": 15,
      "scoring_method": "fill_in_blanks_match",
      "blanks": [
        {
          "blank_index": 1,
          "correct_answer": "北京",
          "score": 5,
          "matching_mode": "exact"
        },
        {
          "blank_index": 2,
          "correct_answer": "上海",
          "score": 10,
          "matching_mode": "contains"
        }
      ]
    }
  ]
}
```

### 4.1 支持的评分方法

1. **exact_match**: 精确匹配，适用于单选题
2. **multi_choice_match**: 多选匹配，适用于多选题
3. **keyword_match**: 关键词匹配，适用于文本输入题
4. **range_match**: 范围匹配，适用于评分题
5. **fill_in_blanks_match**: 填空题匹配，适用于填空题
6. **manual_score**: 手动评分，适用于需要人工判断的题型

## 5. 数据库迁移

```elixir
defmodule MyApp.Repo.Migrations.CreateScoringSystem do
  use Ecto.Migration

  def change do
    # 创建评分规则表
    create table(:scoring_rules, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :rules, :map, null: false
      add :max_score, :integer, null: false
      add :is_active, :boolean, default: true
      
      add :form_id, references(:forms, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id)
      
      timestamps()
    end
    
    create index(:scoring_rules, [:form_id])
    create index(:scoring_rules, [:user_id])
    
    # 创建表单评分配置表
    create table(:form_scores, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :total_score, :integer, default: 100
      add :passing_score, :integer
      add :score_visibility, :string
      add :auto_score, :boolean, default: true
      
      add :form_id, references(:forms, type: :binary_id, on_delete: :delete_all), null: false
      
      timestamps()
    end
    
    create unique_index(:form_scores, [:form_id])
    
    # 创建响应评分表
    create table(:response_scores, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :total_score, :integer, null: false
      add :passed, :boolean
      add :score_breakdown, :map
      add :feedback, :text
      
      add :response_id, references(:responses, type: :binary_id, on_delete: :delete_all), null: false
      add :score_rule_id, references(:scoring_rules, type: :binary_id)
      add :grader_id, references(:users, type: :binary_id)
      
      timestamps()
    end
    
    create index(:response_scores, [:response_id])
    create index(:response_scores, [:score_rule_id])
    create index(:response_scores, [:grader_id])
  end
end
```

## 6. 评分处理实现

评分处理的核心逻辑实现（简化版）：

```elixir
defp apply_scoring_rules(response, rule, form) do
  # 把规则转换为查找表
  rule_map = 
    Enum.reduce(rule.rules["items"] || [], %{}, fn item, acc ->
      Map.put(acc, item["item_id"], item)
    end)
  
  # 计算每个回答的分数
  breakdown = 
    Enum.reduce(response.answers, %{}, fn answer, acc ->
      # 获取该题的评分规则
      item_rule = Map.get(rule_map, answer.form_item_id)
      
      # 如果没有规则，跳过评分
      if is_nil(item_rule) do
        acc
      else
        # 根据题型和规则计算分数
        score = score_answer(answer, item_rule, form)
        Map.put(acc, answer.form_item_id, score)
      end
    end)
  
  # 计算总分
  total_score = Enum.sum(Map.values(breakdown))
  
  # 获取表单评分配置
  form_score = get_form_score_config(form.id) || %{passing_score: 60}
  
  # 判断是否通过
  passed = total_score >= form_score.passing_score
  
  %{
    total_score: total_score,
    passed: passed,
    breakdown: breakdown
  }
end

# 根据不同题型和规则评分
defp score_answer(answer, rule, form) do
  # 获取题目类型
  form_item = Enum.find(form.items, &(&1.id == answer.form_item_id))
  
  case {form_item && form_item.type, rule["scoring_method"]} do
    {_, "manual_score"} ->
      # 手动评分题暂不自动评分
      0
      
    {_, "exact_match"} ->
      # 精确匹配（如单选题）
      score_exact_match(answer.value, rule)
      
    {_, "multi_choice_match"} ->
      # 多选题评分
      score_multi_choice(answer.value, rule)
      
    {_, "keyword_match"} ->
      # 关键词匹配（如文本题）
      score_keyword_match(answer.value, rule)
      
    {_, "range_match"} ->
      # 范围匹配（如评分题）
      score_range_match(answer.value, rule)
      
    {_, "fill_in_blanks_match"} ->
      # 填空题评分
      score_fill_in_blanks(answer.value, rule)
      
    _ ->
      # 未知题型或评分方法
      0
  end
end

# 精确匹配评分
defp score_exact_match(value, rule) do
  user_answer = value["value"]
  correct_answer = rule["correct_answer"]
  
  if user_answer == correct_answer do
    rule["max_score"]
  else
    0
  end
end

# 填空题评分
defp score_fill_in_blanks(value, rule) do
  # 解析用户答案（JSON数组）
  user_answers = 
    case Jason.decode(value["value"]) do
      {:ok, answers} when is_list(answers) -> answers
      _ -> []
    end
  
  # 计算每个填空的得分
  scores = 
    Enum.map(rule["blanks"] || [], fn blank ->
      blank_index = blank["blank_index"]
      correct_answer = blank["correct_answer"]
      score_value = blank["score"] || 1
      
      # 获取用户在该位置的答案
      user_answer = 
        if is_list(user_answers) && length(user_answers) >= blank_index do
          Enum.at(user_answers, blank_index - 1)
        else
          nil
        end
      
      # 如果用户没有回答，得分为0
      if is_nil(user_answer) || user_answer == "" do
        0
      else
        # 根据匹配模式判断答案正确性
        correct = case blank["matching_mode"] do
          "exact" -> String.trim(user_answer) == String.trim(correct_answer)
          "contains" -> String.contains?(String.trim(user_answer), String.trim(correct_answer))
          "regex" -> Regex.match?(~r/#{correct_answer}/i, user_answer)
          _ -> false
        end
        
        if correct, do: score_value, else: 0
      end
    end)
  
  # 返回总分
  Enum.sum(scores)
end

# 其他评分方法实现...
```

## 7. 前端实现

### 7.1 评分设置界面

在表单编辑页面添加评分设置标签页，允许配置以下内容：

1. 启用/禁用评分功能
2. 设置总分和及格分数线
3. 配置评分可见性（仅管理员可见/所有人可见）
4. 设置评分规则
   - 题目分值
   - 正确答案
   - 评分方法

### 7.2 评分统计界面

在表单响应页面添加评分统计标签页，展示：

1. 总体评分分布图表
2. 平均分和通过率
3. 各题得分率分析
4. 响应列表，包含分数信息

### 7.3 前端路由

```elixir
# 在router.ex中添加评分相关路由
scope "/", MyAppWeb do
  pipe_through [:browser, :require_authenticated_user]
  
  # 评分规则管理
  resources "/forms/:form_id/scoring", ScoringController, except: [:index, :show]
  
  # 单个响应评分
  resources "/forms/:form_id/responses/:response_id/score", ResponseScoreController, only: [:show, :create, :update]
  
  # 评分统计
  get "/forms/:form_id/score-statistics", ScoringController, :statistics
  
  # 批量评分
  post "/forms/:form_id/batch-score", ScoringController, :batch_score
end
```

## 8. 与现有系统集成

### 8.1 表单系统集成

1. 在表单模型(Form)中添加关联:
   ```elixir
   # 在 Form 模型中
   has_one :score_config, MyApp.Scoring.FormScore
   has_many :score_rules, MyApp.Scoring.ScoreRule
   ```

2. 在表单模式中添加评分标志:
   ```elixir
   # 在 Form 模型中
   field :has_scoring, :boolean, default: false
   ```

### 8.2 响应系统集成

1. 在响应模型(Response)中添加关联:
   ```elixir
   # 在 Response 模型中
   has_many :scores, MyApp.Scoring.ResponseScore
   ```

2. 响应提交后自动评分:
   ```elixir
   # 在 Responses 模块中修改 create_response 函数
   def create_response(attrs) do
     # 开启事务
     Repo.transaction(fn ->
       # 创建响应...
       
       # 检查表单是否启用评分
       if response.form.has_scoring && response.form.score_config.auto_score do
         # 获取活跃的评分规则
         with {:ok, rule} <- 
                ScoreRule
                |> where([r], r.form_id == ^response.form_id and r.is_active == true)
                |> order_by([r], desc: r.inserted_at)
                |> limit(1)
                |> Repo.one()
                |> then(fn rule -> if rule, do: {:ok, rule}, else: {:error, :no_rule} end) do
           # 自动评分
           MyApp.Scoring.score_response(response.id, rule.id)
         end
       end
       
       response
     end)
   end
   ```

### 8.3 前端UI集成

1. 响应列表显示评分:
   
   在表单响应列表中添加分数列，显示每份提交的得分。

2. 响应详情页面集成评分视图:
   
   在响应详情页面添加评分部分，显示总分、各题得分和评价。

3. 评分设置UI:
   
   集成到表单编辑器，单独标签页管理评分规则和设置。

## 9. 评分规则编辑器改进计划

### 9.1 问题描述

当前的评分规则编辑器（`ScoreRuleEditorComponent`）存在以下问题：

1. **统一的文本输入限制**：所有类型的表单控件都使用统一的文本输入框来设置"正确答案"，这对于单选、多选、日期等控件类型不够直观且容易出错
2. **有限的评分方法支持**：目前仅支持几种基本的评分方法（完全匹配、包含关键词、正则表达式）
3. **缺乏控件类型感知**：编辑器不根据所选表单项的类型来调整界面和输入方式
4. **无法支持复杂的评分规则**：填空题多个空位评分、多选题部分正确给部分分等高级场景无法支持

### 9.2 改进目标

1. **适应不同控件类型**：根据所选表单项的类型，动态显示与之匹配的答案输入控件
2. **增强评分规则数据结构**：扩展规则数据格式，支持不同控件类型的答案格式和评分逻辑
3. **改进后端评分计算**：实现针对不同控件类型的专门评分算法
4. **提升用户体验**：使规则创建更加直观、更准确

### 9.3 数据结构改进

现有的评分规则数据结构（参见第4节）需要根据不同控件类型进行扩展：

```json
{
  "version": 2,
  "type": "automatic",
  "items": [
    {
      "item_id": "单选题ID",
      "item_type": "radio",
      "max_score": 10,
      "scoring_method": "exact_match",
      "correct_answer": "选项ID",
      "partial_credit": false
    },
    {
      "item_id": "多选题ID",
      "item_type": "checkbox",
      "max_score": 20,
      "scoring_method": "multi_choice_match",
      "correct_answers": ["选项ID1", "选项ID2"],
      "require_all": true,
      "partial_credit": true
    },
    {
      "item_id": "日期题ID",
      "item_type": "date",
      "max_score": 5,
      "scoring_method": "date_match",
      "correct_answer": "2025-04-15",
      "allow_range": false
    },
    {
      "item_id": "评分题ID",
      "item_type": "rating",
      "max_score": 5,
      "scoring_method": "range_match",
      "correct_range": {
        "min": 4,
        "max": 5
      }
    }
  ]
}
```

关键改进：
- 新增 `item_type` 字段记录控件类型
- 扩展 `scoring_method` 支持更多评分方法
- 根据控件类型使用不同格式的正确答案字段（`correct_answer`、`correct_answers`、`correct_range`等）

### 9.4 后端改进

1. **规则验证逻辑**（`score_rule.ex`）
   - 扩展 `validate_rules_structure/1` 函数，支持验证复杂的规则结构
   - 添加针对不同控件类型的专门验证逻辑

2. **评分计算逻辑**（`scoring.ex`）
   - 重构 `score_answer/3` 函数，针对不同控件类型实现专门的评分函数
   - 为各种控件类型实现相应的评分算法：
     ```elixir
     defp score_radio_answer(answer, rule, _form), do: # 单选题评分逻辑
     defp score_checkbox_answer(answer, rule, _form), do: # 多选题评分逻辑
     defp score_date_answer(answer, rule, _form), do: # 日期题评分逻辑
     defp score_rating_answer(answer, rule, _form), do: # 评分题评分逻辑
     ```

3. **数据结构迁移**
   - 添加版本管理机制，确保旧版规则数据仍然可用
   - 添加数据迁移函数，将旧版规则格式转换为新版

### 9.5 前端改进

1. **规则编辑器组件**（`score_rule_editor_component.ex`）
   - 添加表单项类型检测逻辑，获取并存储所选题目的类型
   - 为不同控件类型实现专门的答案输入组件
   - 动态渲染针对不同控件类型的输入界面

2. **具体界面改动**
   - 单选题：显示可选项列表，直接选择正确选项
   - 多选题：显示复选框列表，选择多个正确选项
   - 日期题：使用日期选择器输入正确日期
   - 填空题：为每个空位单独设置答案和分值
   - 评分题：使用评分控件设置正确评分范围

### 9.6 实施进度

| 组件 | 改进内容 | 状态 | 完成度 |
|------|---------|------|-------|
| **数据结构** | 前端：添加控件类型信息 | 已完成 | 100% |
| **数据结构** | 前端：扩展规则数据结构 | 已完成 | 100% |
| **数据结构** | 后端：完善规则验证逻辑 | 已完成 | 100% |
| **答案输入界面** | 实现动态控件切换 | 已完成 | 100% |
| **答案输入界面** | 单选题专用输入界面 | 已完成 | 100% |
| **答案输入界面** | 多选题专用输入界面 | 已完成 | 100% |
| **答案输入界面** | 日期/时间题专用输入界面 | 已完成 | 100% |
| **答案输入界面** | 评分题专用输入界面 | 已完成 | 100% |
| **答案输入界面** | 填空题专用输入界面 | 已完成 | 100% |
| **评分逻辑** | 按控件类型优化评分算法 | 已完成 | 100% |
| **评分逻辑** | 支持部分计分功能 | 已完成 | 100% |
| **评分逻辑** | 支持填空题分空评分 | 已完成 | 100% |
| **用户体验** | 添加控件类型图标提示 | 未实施 | 0% |
| **用户体验** | 添加帮助文本说明 | 未实施 | 0% |

### 9.7 测试更新要求

评分系统改进需要以下测试更新：

1. **单元测试**：
   - 更新 `score_rule_test.exs`，添加针对复杂规则结构的验证测试
   - 为各控件类型的评分算法添加单元测试

2. **集成测试**：
   - 测试不同控件类型的评分规则创建和计算
   - 验证旧版规则格式的兼容性

3. **UI测试**：
   - 测试规则编辑器对不同控件类型的动态渲染
   - 验证输入正确答案和保存过程的完整性

关键测试场景包括：
- 单选题答案选择和评分测试
- 多选题部分正确情况的评分测试
- 日期范围匹配测试
- 填空题多空评分测试
- 评分题范围匹配测试

## 10. 注意事项与建议

1. **性能考虑**:
   - 评分计算可能较为复杂，考虑对大型表单使用异步评分
   - 添加适当的缓存机制，避免重复计算统计数据

2. **安全性**:
   - 确保只有表单所有者和管理员能够修改评分规则
   - 根据score_visibility设置控制评分结果的可见性

3. **可扩展性**:
   - 评分规则结构设计为可扩展的JSON格式，便于日后添加新评分方法
   - 使用版本字段标记评分规则格式，支持未来升级

4. **用户体验**:
   - 提供即时评分反馈，帮助用户理解得分情况
   - 考虑提供评分统计的导出功能

## 11. 实现路径

建议按照以下顺序实现评分系统改进:

1. 先完成后端数据结构设计和验证逻辑的更新
2. 实现基础控件类型的动态输入界面（单选、多选、文本）
3. 更新评分计算逻辑以支持新的数据结构
4. 添加验证功能确保旧版数据兼容性
5. 优化用户体验，添加提示和帮助文本
6. 实现高级控件类型支持（填空题、评分题等）
7. 更新所有测试用例

这种渐进式实现方法可以确保核心功能先改进，然后逐步完善系统。