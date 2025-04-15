defmodule MyAppWeb.Scoring.Helpers do
  @moduledoc """
  评分系统前端辅助函数模块。
  提供各评分相关LiveView共享的辅助函数。
  """

  @doc """
  格式化日期时间。
  """
  def format_datetime(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
  end

  @doc """
  获取填表人姓名。
  """
  def get_respondent_name(response) do
    cond do
      Map.get(response, :respondent_name) && Map.get(response, :respondent_name) != "" ->
        Map.get(response, :respondent_name)
      Map.get(response, :user_id) ->
        "用户 #{Map.get(response, :user_id)}"
      Map.get(response.respondent_info || %{}, "user_id") ->
        "用户 #{Map.get(response.respondent_info, "user_id")}"
      true ->
        "匿名"
    end
  end

  @doc """
  格式化评分方法。
  """
  def format_scoring_method(method) do
    case method do
      "exact_match" -> "完全匹配"
      "contains" -> "包含关键字"
      "regex" -> "正则表达式"
      _ -> method
    end
  end

  @doc """
  格式化用户答案。
  """
  def format_answer(answer) do
    cond do
      is_nil(answer) ->
        "未作答"
        
      answer == "" ->
        # 明确处理空字符串
        ""
        
      is_map(answer) && map_size(answer) == 0 ->
        # 明确处理空Map
        "空数据"
        
      is_map(answer) ->
        case Map.get(answer, "value") do
          nil -> 
            # 如果没有value键但有其他内容，直接显示整个Map内容
            if map_size(answer) > 0 do
              format_raw_answer(answer)
            else
              "空 Map"
            end
          [] -> "空列表"
          value when is_list(value) -> format_list_value(value)
          value when is_binary(value) ->
            # 检查是否为JSON列表并尝试解析
            if String.starts_with?(value, "[") do
              case Jason.decode(value) do
                {:ok, list} when is_list(list) -> format_list_value(list)
                _ -> to_string(value)
              end
            else
              to_string(value)
            end
          value -> to_string(value)
        end
        
      is_list(answer) ->
        if answer == [] do
          ""  # 空列表显示为空白，区别于"未作答"
        else
          format_list_value(answer)
        end
        
      is_binary(answer) ->
        if answer == "" do
          ""  # 明确处理空字符串
        else
          # 检查是否为JSON列表并尝试解析
          if String.starts_with?(answer, "[") do
            case Jason.decode(answer) do
              {:ok, list} when is_list(list) -> format_list_value(list)
              _ -> answer
            end
          else
            answer
          end
        end
        
      true ->
        "未知格式: #{inspect(answer)}"
    end
  end
  
  # 辅助函数：格式化原始答案（非标准结构）
  defp format_raw_answer(answer) when is_map(answer) do
    # 尝试从非标准格式中提取有意义的值
    cond do
      # 如果Map有text字段
      Map.has_key?(answer, "text") || Map.has_key?(answer, :text) ->
        text = Map.get(answer, "text", Map.get(answer, :text, ""))
        to_string(text)
        
      # 如果是填空题答案格式（可能直接保存在顶层）
      is_binary(Map.get(answer, "0")) || is_binary(Map.get(answer, "1")) ->
        # 提取数字键对应的值并组合
        answer
        |> Enum.filter(fn {k, _} -> match?({n, _} when is_integer(n), Integer.parse(k)) end)
        |> Enum.sort_by(fn {k, _} -> elem(Integer.parse(k), 0) end)
        |> Enum.map(fn {_, v} -> v end)
        |> Enum.join(", ")
      
      # 其他情况，返回整个Map的字符串表示
      true ->
        inspect(answer)
    end
  end
  
  # 辅助函数：格式化列表值为可读字符串
  defp format_list_value(list) do
    list
    |> Enum.map(&to_string/1)
    |> Enum.join(", ")
  end
end
