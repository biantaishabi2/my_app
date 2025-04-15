# 调试填空题评分结构
# 运行方式: mix run scprits/debug_answers_structure.exs

require Logger
import Ecto.Query

# 设置日志级别为debug以查看详细信息
Logger.configure(level: :debug)

# 导入需要的模块
alias MyApp.Repo
alias MyApp.Scoring
alias MyApp.Responses
alias MyApp.Responses.Response
alias MyApp.Responses.Answer
alias MyApp.Forms.FormItem

# 模拟填空题测试数据 - 几种不同格式
test_data = [
  # 标准JSON数组格式
  %{
    "id" => "测试1", 
    "user" => ["北京", "长沙"],
    "correct" => ["北京", "长沙"]
  },
  # 普通字符串格式
  %{
    "id" => "测试2", 
    "user" => "北京, 长沙",
    "correct" => ["北京", "长沙"]
  },
  # 带空格的字符串格式
  %{
    "id" => "测试3", 
    "user" => ["北京 ", " 长沙"],
    "correct" => ["北京", "长沙"]
  },
  # 带额外空格的JSON字符串
  %{
    "id" => "测试4", 
    "user" => ~s(["北京", "长沙 "]),
    "correct" => ["北京", "长沙"]
  }
]

# 测试safe_to_string函数
safe_to_string = fn 
  value, fun -> 
    cond do
      is_nil(value) -> ""
      is_binary(value) -> String.trim(value)
      is_integer(value) || is_float(value) || is_atom(value) -> 
        to_string(value)
      # 处理以 atom 或 string 为键的 Map
      is_map(value) && (Map.has_key?(value, "text") || Map.has_key?(value, :text)) -> 
        text_value = Map.get(value, "text", Map.get(value, :text, ""))
        fun.(text_value, fun)
      is_map(value) && (Map.has_key?(value, "value") || Map.has_key?(value, :value)) -> 
        value_field = Map.get(value, "value", Map.get(value, :value, ""))
        fun.(value_field, fun)
      is_map(value) -> 
        inspect(value)
      is_list(value) -> 
        # 如果是空列表，返回空字符串
        if value == [] do
          ""
        else
          # 为列表元素添加标准化处理
          normalized_values = Enum.map(value, fn v -> 
            cond do
              is_nil(v) -> ""
              is_binary(v) -> String.trim(v)
              true -> fun.(v, fun)
            end
          end)
          Enum.map_join(normalized_values, ",", &fun.(&1, fun))
        end
      true -> 
        inspect(value)
    end
end

# 简化调用
safe_str = fn value -> safe_to_string.(value, safe_to_string) end

# 测试填空题答案处理
parse_fill_in_blank = fn user_answer_value ->
  # 解析用户答案（统一数据格式，支持多种输入格式）
  user_values = 
    cond do
      # 已经是列表，直接使用
      is_list(user_answer_value) -> 
        user_answer_value
      # JSON格式的字符串
      is_binary(user_answer_value) && String.starts_with?(user_answer_value, "[") ->
        case Jason.decode(user_answer_value) do
          {:ok, values} when is_list(values) -> values
          _ -> [user_answer_value]
        end
      # 其他情况，作为单个答案处理
      true -> 
        Logger.debug("填空题数据格式: #{inspect(user_answer_value)}")
        [user_answer_value]
    end
    
  # 对填空题答案进行额外的标准化处理，确保空字符串和nil值的一致性
  user_values = Enum.map(user_values, fn value ->
    cond do
      is_nil(value) -> ""
      is_binary(value) -> String.trim(value)
      true -> value
    end
  end)
  
  user_values
end

# 执行测试
IO.puts("\n=== 填空题评分数据结构检查 ===\n")

for test_case <- test_data do
  user_answer = test_case["user"]
  correct_answer = test_case["correct"]
  test_id = test_case["id"]
  
  # 标准化处理
  user_values = parse_fill_in_blank.(user_answer)
  correct_values = parse_fill_in_blank.(correct_answer)
  
  # 比较每个填空值
  correct_count = 
    Enum.zip(correct_values, user_values)
    |> Enum.count(fn {correct, user} -> 
      correct_str = safe_str.(correct)
      user_str = safe_str.(user)
      IO.puts("  #{test_id} - 比较: 正确答案=\"#{correct_str}\" 用户答案=\"#{user_str}\" 结果=#{correct_str == user_str}")
      correct_str == user_str 
    end)
  
  total_blanks = max(length(correct_values), 1)
  score = round(10 * correct_count / total_blanks)
  
  IO.puts("#{test_id} - 总结: 用户答案=#{inspect(user_answer)}, 标准答案=#{inspect(correct_answer)}")
  IO.puts("#{test_id} - 正确数/总数: #{correct_count}/#{total_blanks}, 得分: #{score}/10\n")
end

# 查找实际评分数据
# 获取最近的一个填空题评分详情
IO.puts("\n=== 数据库填空题答案检查 ===\n")

form_items_query = 
  from(i in FormItem, where: i.type == :fill_in_blank)

fill_in_blank_items = Repo.all(form_items_query)

if Enum.empty?(fill_in_blank_items) do
  IO.puts("没有找到填空题表单项")
else
  Enum.each(fill_in_blank_items, fn item ->
    IO.puts("表单项: #{item.id}, 标签: #{item.label}")
    
    # 查找答案
    answers_query = 
      from(a in Answer, 
        where: a.form_item_id == ^item.id,
        order_by: [desc: :inserted_at],
        limit: 5)
      
    answers = Repo.all(answers_query)
    
    if Enum.empty?(answers) do
      IO.puts("  没有找到答案记录")
    else
      Enum.each(answers, fn answer ->
        IO.puts("  答案ID: #{answer.id}")
        IO.puts("  答案值: #{inspect(answer.value)}")
        
        # 解析填空题值
        user_values = parse_fill_in_blank.(answer.value)
        IO.puts("  解析后: #{inspect(user_values)}")
        
        # 读取评分详情
        response_id = answer.response_id
        IO.puts("  响应ID: #{response_id}")
        
        case Scoring.get_response_score_for_response(response_id) do
          {:ok, response_score} ->
            score_details = response_score.score_details || %{}
            item_score = Map.get(score_details, "#{item.id}", %{})
            IO.puts("  评分详情: #{inspect(item_score)}")
          _ ->
            IO.puts("  没有找到评分记录")
        end
        
        IO.puts("")
      end)
    end
  end)
end