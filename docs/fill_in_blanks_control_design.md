# 填空题控件设计方案

## 1. 概述

填空题控件是一种常见于问卷调查、教学测验等场景的表单控件，它允许在一段文本中设置多个需要用户填写的空白处。本文档详细描述了填空题控件在我们表单系统中的设计与实现方案。

## 2. 数据模型设计

### 2.1 数据库模型扩展

在 `form_item` 表中添加以下字段：

```elixir
# 在 FormItem 模型中
field :type, Ecto.Enum,
  values: [
    # 现有控件类型...
    :fill_in_blanks,  # 新添加的填空题类型
    # 其他控件类型...
  ]

# 填空题特有字段
field :template_text, :string  # 带填空位置标记的模板文本
field :blank_count, :integer, default: 1  # 填空数量
field :blank_placeholders, {:array, :string}, default: []  # 各填空处的提示文本
field :blank_sizes, {:array, :integer}, default: []  # 各填空处的输入框宽度
field :blank_answers, {:array, :string}, default: []  # 各填空处的参考答案
field :blank_scores, {:array, :integer}, default: []  # 各填空处的分值
field :matching_mode, Ecto.Enum, values: [:exact, :contains, :regex], default: :exact  # 答案匹配模式
```

### 2.2 验证逻辑

```elixir
def changeset(form_item, attrs) do
  form_item
  |> cast(attrs, [:type, :template_text, :blank_count, :blank_placeholders, 
                 :blank_sizes, :blank_answers, :blank_scores, :matching_mode])
  |> validate_required([:type])
  |> validate_fill_in_blanks()
  # 其他验证...
end

defp validate_fill_in_blanks(changeset) do
  if get_field(changeset, :type) == :fill_in_blanks do
    # 验证模板文本存在
    changeset = validate_required(changeset, [:template_text, :blank_count])
    
    # 验证填空标记与数量一致
    template_text = get_field(changeset, :template_text)
    blank_count = get_field(changeset, :blank_count)
    
    if !is_nil(template_text) && !is_nil(blank_count) do
      # 确认模板文本中的占位符数量与设定的blank_count一致
      placeholder_matches = Regex.scan(~r/\{\{(\d+)\}\}/, template_text)
      actual_blank_count = length(placeholder_matches)
      
      if actual_blank_count != blank_count do
        add_error(changeset, :template_text, "填空标记数量(#{actual_blank_count})与设置的填空数量(#{blank_count})不一致")
      else
        changeset
      end
    else
      changeset
    end
  else
    changeset
  end
end
```

### 2.3 答案存储格式

为提高灵活性，填空题的用户回答将以JSON数组形式存储，每个数组元素对应一个填空：

```json
["用户答案1", "用户答案2", "用户答案3"]
```

## 3. 前端界面设计

### 3.1 表单编辑器界面

填空题编辑界面应包含以下元素：

1. **填空题标题**：与其他控件一致的标题输入
2. **模板文本编辑器**：
   - 多行文本输入框，用于输入带填空标记的文本
   - 填空标记格式说明：使用 `{{1}}`, `{{2}}` 等形式标记填空位置
3. **填空设置面板**：
   - 显示已检测到的所有填空位置
   - 每个填空可设置：
     - 提示文本
     - 输入框宽度
     - 参考答案
     - 得分权重
4. **匹配模式选择**：精确匹配、包含匹配、正则表达式匹配

样式示例：
```html
<div class="fill-in-blanks-editor">
  <div class="mb-4">
    <label class="block text-sm font-medium mb-1">填空题模板文本</label>
    <div class="text-xs text-gray-500 mb-2">
      使用 {{1}}、{{2}} 等标记填空位置，例如："中国的首都是{{1}}，最大的城市是{{2}}。"
    </div>
    <textarea
      name="item[template_text]"
      class="w-full px-3 py-2 border border-gray-300 rounded-md"
      rows="5"
    ><%= @item.template_text %></textarea>
  </div>
  
  <!-- 填空设置面板 -->
  <div class="fill-blanks-settings mt-4">
    <h3 class="text-sm font-medium mb-2">填空设置</h3>
    
    <%= for i <- 1..(@item.blank_count || 1) do %>
      <div class="grid grid-cols-4 gap-2 mb-2 p-2 bg-gray-50 rounded">
        <div class="text-sm font-medium">填空 #<%= i %></div>
        <div>
          <label class="block text-xs text-gray-500">提示文本</label>
          <input
            type="text"
            name="item[blank_placeholders][]"
            value="<%= Enum.at(@item.blank_placeholders || [], i-1) || "" %>"
            class="w-full px-2 py-1 border border-gray-300 rounded-md text-sm"
            placeholder="填写此处"
          />
        </div>
        <div>
          <label class="block text-xs text-gray-500">参考答案</label>
          <input
            type="text"
            name="item[blank_answers][]"
            value="<%= Enum.at(@item.blank_answers || [], i-1) || "" %>"
            class="w-full px-2 py-1 border border-gray-300 rounded-md text-sm"
          />
        </div>
        <div>
          <label class="block text-xs text-gray-500">分值</label>
          <input
            type="number"
            name="item[blank_scores][]"
            value="<%= Enum.at(@item.blank_scores || [], i-1) || 1 %>"
            min="0"
            max="100"
            class="w-full px-2 py-1 border border-gray-300 rounded-md text-sm"
          />
        </div>
      </div>
    <% end %>
  </div>
  
  <div class="matching-mode mt-4">
    <label class="block text-sm font-medium mb-1">答案匹配模式</label>
    <select name="item[matching_mode]" class="w-full px-2 py-1 border border-gray-300 rounded-md">
      <option value="exact" <%= if @item.matching_mode == :exact, do: "selected" %>>精确匹配</option>
      <option value="contains" <%= if @item.matching_mode == :contains, do: "selected" %>>包含匹配</option>
      <option value="regex" <%= if @item.matching_mode == :regex, do: "selected" %>>正则表达式</option>
    </select>
    <div class="text-xs text-gray-500 mt-1">
      精确匹配：答案必须完全一致；包含匹配：答案中包含关键词即可；正则表达式：使用正则表达式匹配
    </div>
  </div>
</div>
```

### 3.2 表单展示界面

填空题在表单展示时应保持文本流畅性，无缝融入输入框：

```elixir
def fill_in_blanks_field(assigns) do
  ~H"""
  <div class="form-field fill-in-blanks mb-4">
    <label for={@field.id} class={"block text-sm font-medium mb-1 #{if @field.required, do: "required"}"}>
      <%= @field.label %>
      <%= if @field.required do %>
        <span class="text-red-500 ml-1">*</span>
      <% end %>
    </label>
    
    <div class="fill-in-blanks-container mt-2">
      <% 
        # 解析模板文本，提取填空标记
        parts = Regex.split(~r/\{\{(\d+)\}\}/, @field.template_text || "", include_captures: true)
        blanks = Regex.scan(~r/\{\{(\d+)\}\}/, @field.template_text || "")
                |> Enum.map(fn [_, num] -> String.to_integer(num) end)
        
        # 获取当前填空值
        current_values = 
          case @form_state[@field.id] do
            nil -> []
            val when is_binary(val) -> 
              case Jason.decode(val) do
                {:ok, list} when is_list(list) -> list
                _ -> []
              end
            _ -> []
          end
      %>
      
      <div class="fill-in-blanks-text">
        <%= for {part, index} <- Enum.with_index(parts) do %>
          <%= if Regex.match?(~r/\{\{(\d+)\}\}/, part) do %>
            <% 
              # 提取填空编号  
              [_, num] = Regex.run(~r/\{\{(\d+)\}\}/, part)
              blank_num = String.to_integer(num)
              
              # 配置和当前值
              placeholder = @field.blank_placeholders[blank_num - 1] || "填写此处"
              width = @field.blank_sizes[blank_num - 1] || 10
              current = Enum.at(current_values, blank_num - 1) || ""
              
              # 错误状态
              has_error = @error && Map.get(@error, "blank_#{blank_num}")
            %>
            <input
              type="text"
              id={"#{@field.id}_blank_#{blank_num}"}
              placeholder={placeholder}
              value={current}
              style={"width: #{width}em; display: inline-block;"}
              class={"px-2 py-1 border rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500 #{if has_error, do: "border-red-500", else: "border-gray-300"}"}
              phx-debounce="blur"
              phx-change="update_blank"
              phx-value-field={@field.id}
              phx-value-blank={blank_num}
            />
          <% else %>
            <span><%= part %></span>
          <% end %>
        <% end %>
      </div>
      
      <!-- 隐藏字段存储所有填空值 -->
      <input
        type="hidden"
        id={@field.id}
        name={"form_data[#{@field.id}]"}
        value={Jason.encode!(current_values)}
      />
    </div>
    
    <%= if @error do %>
      <div class="text-red-500 text-sm mt-1"><%= @error %></div>
    <% end %>
  </div>
  """
end
```

## 4. 数据提交与处理

### 4.1 用户提交数据处理

```elixir
# 在 FormLive.Submit 模块中添加
def handle_event("update_blank", %{"field" => field_id, "blank" => blank_num, "value" => value}, socket) do
  # 更新特定填空的值
  current_values = get_form_state(socket)[field_id] || "[]"
  current_values = 
    case Jason.decode(current_values) do
      {:ok, list} when is_list(list) -> list
      _ -> []
    end
  
  # 将空字符串填充到所需长度
  blank_num = String.to_integer(blank_num)
  current_values = 
    if length(current_values) < blank_num do
      current_values ++ List.duplicate("", blank_num - length(current_values))
    else
      current_values
    end
  
  # 更新特定位置的值
  updated_values = List.replace_at(current_values, blank_num - 1, value)
  
  # 更新表单状态
  form_state = Map.put(get_form_state(socket), field_id, Jason.encode!(updated_values))
  
  {:noreply, assign(socket, form_state: form_state)}
end

# 验证填空题
defp validate_fill_in_blanks(form_item, values) do
  # 解析填空值
  answers = 
    case Jason.decode(values) do
      {:ok, list} when is_list(list) -> list
      _ -> []
    end
    
  # 确保每个必填的填空都有值
  errors = 
    if form_item.required do
      Enum.with_index(answers)
      |> Enum.map(fn {answer, idx} ->
        if is_nil(answer) || String.trim(answer) == "" do
          {"blank_#{idx + 1}", "此项不能为空"}
        else
          nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.into(%{})
    else
      %{}
    end
    
  # 如果有错误，返回错误信息，否则返回nil
  if map_size(errors) > 0 do
    errors
  else
    nil
  end
end
```

### 4.2 数据存储格式

填空题的回答将存储在 Answer 表的 value 字段中，格式为：

```json
{
  "value": ["答案1", "答案2", "答案3"],
  "scores": [2, 0, 1],
  "total_score": 3,
  "max_score": 6
}
```

## 5. 评分机制

### 5.1 评分逻辑

```elixir
defp score_fill_in_blanks(form_item, user_answers) do
  # 读取JSON格式答案
  answers = 
    case Jason.decode(user_answers) do
      {:ok, list} when is_list(list) -> list
      _ -> []
    end
    
  # 获取标准答案和分值
  reference_answers = form_item.blank_answers || []
  scores_per_blank = form_item.blank_scores || []
  
  # 计算每个填空的得分
  scores = Enum.with_index(answers)
  |> Enum.map(fn {answer, idx} ->
    ref_answer = Enum.at(reference_answers, idx, "")
    score_value = Enum.at(scores_per_blank, idx, 1)
    
    # 根据匹配规则判断正误
    correct = case form_item.matching_mode do
      :exact -> String.trim(answer) == String.trim(ref_answer)
      :contains -> String.contains?(String.trim(answer), String.trim(ref_answer))
      :regex -> Regex.match?(~r/#{ref_answer}/i, answer)
    end
    
    if correct, do: score_value, else: 0
  end)
  
  # 计算总分和最大可能分数
  total_score = Enum.sum(scores)
  max_score = Enum.sum(Enum.map(1..length(reference_answers), fn idx ->
    Enum.at(scores_per_blank, idx - 1, 1)
  end))
  
  # 返回评分结果
  %{
    "value" => answers,
    "scores" => scores,
    "total_score" => total_score,
    "max_score" => max_score
  }
end
```

### 5.2 统计与分析

扩展 `GroupedStatistics` 模块，添加填空题统计功能：

```elixir
defp calculate_fill_in_blanks_statistics(form_item, answers) do
  # 提取所有填空答案
  blank_answers = answers |> Enum.map(&(&1.value["value"]))
  
  # 计算总作答数和作答率
  total_answers = length(blank_answers)
  
  # 计算每个填空的正确率
  blank_count = form_item.blank_count || 0
  per_blank_stats = 
    for blank_idx <- 0..(blank_count - 1) do
      # 提取该填空位置的所有答案
      blank_values = blank_answers
      |> Enum.map(fn answer_list ->
        if is_list(answer_list) && length(answer_list) > blank_idx do
          Enum.at(answer_list, blank_idx)
        else
          nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      
      # 计算该填空的正确数量
      correct_values = answers
      |> Enum.filter(fn answer ->
        scores = answer.value["scores"]
        is_list(scores) && length(scores) > blank_idx && Enum.at(scores, blank_idx) > 0
      end)
      |> length()
      
      # 计算正确率
      correct_rate = 
        if length(blank_values) > 0 do
          correct_values / length(blank_values) * 100
        else
          0
        end
        
      # 返回该填空的统计数据
      %{
        blank_index: blank_idx + 1,
        answer_count: length(blank_values),
        correct_count: correct_values,
        correct_rate: Float.round(correct_rate, 1)
      }
    end
    
  # 总体评分统计
  avg_score = 
    answers
    |> Enum.map(&(&1.value["total_score"] || 0))
    |> Enum.sum()
    |> then(fn sum -> if total_answers > 0, do: sum / total_answers, else: 0 end)
    
  max_possible = form_item.blank_answers |> Enum.with_index() |> Enum.map(fn {_, idx} ->
    Enum.at(form_item.blank_scores || [], idx, 1)
  end) |> Enum.sum()
  
  # 返回完整统计
  %{
    type: :fill_in_blanks,
    item_id: form_item.id,
    item_label: form_item.label,
    total_answers: total_answers,
    per_blank_stats: per_blank_stats,
    avg_score: Float.round(avg_score, 2),
    max_possible: max_possible
  }
end
```

## 6. CSS样式

为填空题控件添加专用CSS样式：

```css
/* 填空题容器样式 */
.fill-in-blanks-container {
  line-height: 2;
}

/* 内联输入框样式 */
.fill-in-blanks-container input[type="text"] {
  display: inline-block;
  background-color: rgba(245, 247, 255, 0.5);
  border: none;
  border-bottom: 2px solid #6366f1;
  border-radius: 0;
  padding: 2px 5px;
  margin: 0 2px;
  min-width: 60px;
  text-align: center;
  transition: all 0.2s ease;
}

.fill-in-blanks-container input[type="text"]:focus {
  outline: none;
  background-color: rgba(238, 242, 255, 0.8);
  border-bottom-color: #4f46e5;
  box-shadow: 0 2px 0 0 #4f46e5;
}

/* 错误状态样式 */
.fill-in-blanks-container input[type="text"].border-red-500 {
  border-bottom-color: #ef4444;
}

.fill-in-blanks-container input[type="text"].border-red-500:focus {
  box-shadow: 0 2px 0 0 #ef4444;
}

/* 移动设备响应式设计 */
@media (max-width: 640px) {
  .fill-in-blanks-container {
    display: flex;
    flex-direction: column;
  }
  
  .fill-in-blanks-text {
    margin-bottom: 1rem;
  }
  
  .fill-in-blanks-container input[type="text"] {
    max-width: 120px;
  }
}
```

## 7. 测试策略

### 7.1 单元测试

1. **模型验证测试**：
   - 验证必填项校验
   - 验证填空数量与标记一致性校验
   - 验证评分设置合法性

2. **渲染组件测试**：
   - 测试不同配置下的渲染结果
   - 测试错误状态显示
   - 测试数据绑定

### 7.2 集成测试

1. **表单提交测试**：
   - 测试填空题提交流程
   - 测试数据验证
   - 测试错误处理

2. **评分测试**：
   - 测试不同匹配模式
   - 测试评分计算
   - 测试统计生成

### 7.3 示例测试用例

```elixir
describe "填空题控件" do
  test "渲染带填空的文本" do
    # 准备测试数据...
    
    # 验证填空被正确渲染
    html = render_component(&FormComponents.fill_in_blanks_field/1, assigns)
    assert html =~ "填空题标题"
    assert html =~ "填写此处"
    assert html =~ ~r/<input[^>]*id="fill-blank-1_blank_1"/
  end
  
  test "提交填空题答案" do
    # 准备测试数据...
    
    # 模拟表单提交
    {:ok, view, _} = live(conn, ~p"/forms/#{form.id}/submit")
    # 填写答案并提交...
    
    # 验证数据库中存储的答案
    response = Repo.get_by(Response, form_id: form.id)
    answer = Enum.find(response.answers, &(&1.form_item_id == fill_blank_item.id))
    assert answer.value["value"] == ["北京", "上海"]
  end
  
  test "填空题评分" do
    # 准备带参考答案的题目...
    
    # 模拟不同答案提交...
    
    # 验证评分结果
    answer = Repo.get_by(Answer, form_item_id: fill_blank_item.id)
    assert answer.value["scores"] == [5, 0]
    assert answer.value["total_score"] == 5
  end
end
```

## 8. 注意事项与优化方向

1. **性能考虑**：
   - 使用批量更新减少服务器请求
   - 对大型表单的填空题数量进行合理限制

2. **用户体验优化**：
   - 添加键盘导航支持（Tab键、Enter键）
   - 提供即时反馈（答案正确性、评分情况）
   - 移动端适配（调整输入框大小、支持虚拟键盘）

3. **扩展性考虑**：
   - 支持更多匹配规则（如模糊匹配程度、多答案选项）
   - 支持富文本模板（加粗、斜体等格式）
   - 支持计算型填空题（数学公式、单位换算）

## 9. 结论

填空题控件通过扩展现有表单系统，实现了灵活的文本嵌入式填空功能，满足了问卷调查、教学测验等场景的需求。其关键特性包括：

1. 支持任意文本中嵌入多个填空位置
2. 每个填空可独立配置提示、宽度、答案和分值
3. 灵活的评分机制，支持多种匹配模式
4. 完整的统计分析功能
5. 良好的移动端适配

该控件与现有表单系统无缝集成，复用了当前的表单提交、验证和数据处理流程，同时提供了针对填空题特性的专门优化。