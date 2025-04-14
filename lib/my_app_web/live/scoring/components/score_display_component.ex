defmodule MyAppWeb.Scoring.Components.ScoreDisplayComponent do
  use MyAppWeb, :live_component

  @doc """
  以统一格式显示分数，例如 "85 / 100"。
  可以根据是否通过显示不同样式。
  
  ## 参数
  
  * `:score` - 当前分数
  * `:max_score` - 最高分数
  * `:passing_score` - 可选，及格分数
  * `:size` - 可选，显示大小 ("sm", "md", "lg")，默认 "md"
  """
  
  def render(assigns) do
    assigns = assign_new(assigns, :size, fn -> "md" end)
    ~H"""
    <div id={@id} class={get_container_class(@score, @max_score, @passing_score, @size)}>
      <span class={get_score_class(@size)}><%= @score %></span>
      <span class={get_separator_class(@size)}>/</span>
      <span class={get_max_score_class(@size)}><%= @max_score %></span>
    </div>
    """
  end
  
  # 获取容器类，根据分数是否及格显示不同颜色
  defp get_container_class(_score, _max_score, nil, size) do
    base_class = "inline-flex items-center justify-center rounded-md"
    
    padding = case size do
      "sm" -> "px-2 py-1"
      "md" -> "px-3 py-1.5"
      "lg" -> "px-4 py-2"
    end
    
    "#{base_class} bg-gray-100 text-gray-800 #{padding}"
  end
  
  defp get_container_class(score, _max_score, passing_score, size) do
    base_class = "inline-flex items-center justify-center rounded-md"
    
    padding = case size do
      "sm" -> "px-2 py-1"
      "md" -> "px-3 py-1.5"
      "lg" -> "px-4 py-2"
    end
    
    color_class = if score >= passing_score do
      "bg-green-100 text-green-800"
    else
      "bg-red-100 text-red-800"
    end
    
    "#{base_class} #{color_class} #{padding}"
  end
  
  # 获取分数类
  defp get_score_class(size) do
    font_size = case size do
      "sm" -> "text-sm"
      "md" -> "text-base"
      "lg" -> "text-lg"
    end
    
    "#{font_size} font-semibold"
  end
  
  # 获取分隔符类
  defp get_separator_class(size) do
    font_size = case size do
      "sm" -> "text-sm"
      "md" -> "text-base"
      "lg" -> "text-lg"
    end
    
    "#{font_size} mx-0.5 opacity-70"
  end
  
  # 获取最高分数类
  defp get_max_score_class(size) do
    font_size = case size do
      "sm" -> "text-sm"
      "md" -> "text-base"
      "lg" -> "text-lg"
    end
    
    "#{font_size}"
  end
end