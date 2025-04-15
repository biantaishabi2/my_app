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
        
      is_map(answer) ->
        case Map.get(answer, "value") do
          nil -> "空 Map"
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
        format_list_value(answer)
        
      is_binary(answer) ->
        # 检查是否为JSON列表并尝试解析
        if String.starts_with?(answer, "[") do
          case Jason.decode(answer) do
            {:ok, list} when is_list(list) -> format_list_value(list)
            _ -> answer
          end
        else
          answer
        end
        
      true ->
        "未知格式: #{inspect(answer)}"
    end
  end
  
  # 辅助函数：格式化列表值为可读字符串
  defp format_list_value(list) do
    list
    |> Enum.map(&to_string/1)
    |> Enum.join(", ")
  end
end
