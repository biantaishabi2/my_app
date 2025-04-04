defmodule MyAppWeb.FormView do
  use MyAppWeb, :view
  
  # 这个视图用于渲染表单相关的模板
  # 特别是表单响应的HTML模板
  
  # 辅助函数 - 与ResponsesLive相同的辅助函数
  
  # 获取回复者姓名
  def get_respondent_name(response) do
    case response.respondent_info do
      %{"name" => name} when is_binary(name) and name != "" -> name
      %{"user_id" => _} -> "匿名用户"
      _ -> "未知用户"
    end
  end
  
  # 获取回复者邮箱
  def get_respondent_email(response) do
    case response.respondent_info do
      %{"email" => email} when is_binary(email) and email != "" -> email
      _ -> ""
    end
  end
  
  # 格式化日期时间
  def format_datetime(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
  end
end