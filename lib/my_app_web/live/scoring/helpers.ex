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
        answer.value || "空"
      true ->
        "未知"
    end
  end
end