defmodule MyAppWeb.Scoring.Components.RuleListItemComponent do
  use MyAppWeb, :live_component


  @doc """
  渲染单个评分规则项。
  
  ## 参数
  
  * `:score_rule` - 评分规则记录
  * `:on_edit` - 可选，编辑事件处理函数
  * `:on_delete` - 可选，删除事件处理函数
  """
  
  def render(assigns) do
    ~H"""
    <div id={"rule-#{@score_rule.id}"} class="mb-4 p-4 border rounded-lg bg-white shadow-sm hover:shadow-md transition-shadow">
      <div class="flex justify-between items-center mb-2">
        <h3 class="text-lg font-semibold text-gray-800">
          <%= @score_rule.name %>
          <%= if @score_rule.is_active do %>
            <span class="ml-2 px-2 py-1 text-xs font-medium rounded-full bg-green-100 text-green-800">激活</span>
          <% else %>
            <span class="ml-2 px-2 py-1 text-xs font-medium rounded-full bg-gray-100 text-gray-800">未激活</span>
          <% end %>
        </h3>
        <div class="flex space-x-2">
          <button
            phx-click={JS.push("edit_rule", value: %{id: @score_rule.id})}
            class="inline-flex items-center px-3 py-1 border border-transparent text-sm font-medium rounded shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
          >
            编辑
          </button>
          <button
            phx-click={JS.push("delete_rule", value: %{id: @score_rule.id}) |> JS.push("confirm", value: %{title: "确认删除", message: "确定要删除规则 \"#{@score_rule.name}\" 吗？该操作不可恢复。", confirm_text: "删除", confirm_value: %{id: @score_rule.id}, cancel_text: "取消"})}
            class="inline-flex items-center px-3 py-1 border border-transparent text-sm font-medium rounded shadow-sm text-white bg-red-600 hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500"
          >
            删除
          </button>
        </div>
      </div>
      <p class="text-sm text-gray-600 mb-2"><%= @score_rule.description %></p>
      <div class="flex justify-between text-xs text-gray-500">
        <span>最高分: <%= @score_rule.max_score %></span>
        <span>规则项: <%= get_rule_items_count(@score_rule.rules) %></span>
      </div>
    </div>
    """
  end

  defp get_rule_items_count(rules) do
    case rules do
      %{"items" => items} when is_list(items) -> length(items)
      _ -> 0
    end
  end
end