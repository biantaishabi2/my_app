defmodule MyAppWeb.Scoring.Components.ScoreRuleEditorComponent do
  use MyAppWeb, :live_component

  @doc """
  提供交互式界面编辑评分规则的 rules JSON 结构。
  
  ## 参数
  
  * `:rules` - 当前规则JSON数据
  * `:form_id` - 表单ID，用于加载表单项
  * `:id` - 组件ID
  * `:on_change` - 规则变更时调用的函数
  """
  
  def mount(socket) do
    {:ok, assign(socket, :rule_items, [])}
  end
  
  def update(assigns, socket) do
    socket = assign(socket, assigns)
    
    rule_items = case socket.assigns.rules do
      %{"items" => items} when is_list(items) -> items
      _ -> []
    end
    
    {:ok, assign(socket, :rule_items, rule_items)}
  end
  
  def render(assigns) do
    ~H"""
    <div id={@id} class="border rounded-lg p-4 bg-gray-50">
      <h3 class="text-lg font-medium mb-4">评分规则项</h3>
      
      <div class="mb-4">
        <button
          type="button"
          phx-click="add_rule_item"
          phx-target={@myself}
          class="inline-flex items-center px-3 py-1 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
        >
          <.icon name="hero-plus-circle" class="w-4 h-4 mr-1" />
          添加规则项
        </button>
      </div>
      
      <%= if Enum.empty?(@rule_items) do %>
        <div class="text-sm text-gray-500 text-center py-4">
          暂无规则项，请点击"添加规则项"按钮添加
        </div>
      <% else %>
        <div class="space-y-4">
          <%= for {item, index} <- Enum.with_index(@rule_items) do %>
            <div class="bg-white p-3 rounded border">
              <div class="flex justify-between items-center mb-2">
                <span class="font-medium">规则项 #<%= index + 1 %></span>
                <button
                  type="button"
                  phx-click="remove_rule_item"
                  phx-value-index={index}
                  phx-target={@myself}
                  class="text-red-600 hover:text-red-800"
                >
                  <.icon name="hero-trash" class="w-4 h-4" />
                </button>
              </div>
              
              <div class="grid grid-cols-2 gap-3">
                <div>
                  <label class="block text-xs font-medium text-gray-700">问题</label>
                  <select
                    phx-change="update_rule_item"
                    phx-value-index={index}
                    phx-value-field="item_id"
                    phx-target={@myself}
                    class="mt-1 block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md"
                  >
                    <option value="">选择问题</option>
                    <%= for form_item <- get_form_items(@form_id) do %>
                      <option value={form_item.id} selected={item["item_id"] == form_item.id}>
                        <%= form_item.title %>
                      </option>
                    <% end %>
                  </select>
                </div>
                
                <div>
                  <label class="block text-xs font-medium text-gray-700">评分方法</label>
                  <select
                    phx-change="update_rule_item"
                    phx-value-index={index}
                    phx-value-field="scoring_method"
                    phx-target={@myself}
                    class="mt-1 block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md"
                  >
                    <option value="exact_match" selected={item["scoring_method"] == "exact_match"}>完全匹配</option>
                    <option value="contains" selected={item["scoring_method"] == "contains"}>包含关键词</option>
                    <option value="regex" selected={item["scoring_method"] == "regex"}>正则表达式</option>
                  </select>
                </div>
                
                <div>
                  <label class="block text-xs font-medium text-gray-700">正确答案</label>
                  <input
                    type="text"
                    value={item["correct_answer"]}
                    phx-blur="update_rule_item"
                    phx-value-index={index}
                    phx-value-field="correct_answer"
                    phx-target={@myself}
                    class="mt-1 block w-full border-gray-300 focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md"
                  />
                </div>
                
                <div>
                  <label class="block text-xs font-medium text-gray-700">分值</label>
                  <input
                    type="number"
                    min="0"
                    value={item["score"]}
                    phx-blur="update_rule_item"
                    phx-value-index={index}
                    phx-value-field="score"
                    phx-target={@myself}
                    class="mt-1 block w-full border-gray-300 focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md"
                  />
                </div>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
  
  def handle_event("add_rule_item", _, socket) do
    new_item = %{
      "item_id" => nil,
      "scoring_method" => "exact_match",
      "correct_answer" => "",
      "score" => 1
    }
    
    rule_items = socket.assigns.rule_items ++ [new_item]
    rules = %{"items" => rule_items}
    
    if socket.assigns[:on_change] do
      send(self(), {socket.assigns.on_change, rules})
    end
    
    {:noreply, assign(socket, rule_items: rule_items)}
  end
  
  def handle_event("remove_rule_item", %{"index" => index}, socket) do
    index = String.to_integer(index)
    rule_items = List.delete_at(socket.assigns.rule_items, index)
    rules = %{"items" => rule_items}
    
    if socket.assigns[:on_change] do
      send(self(), {socket.assigns.on_change, rules})
    end
    
    {:noreply, assign(socket, rule_items: rule_items)}
  end
  
  def handle_event("update_rule_item", %{"index" => index, "field" => field, "value" => value}, socket) do
    index = String.to_integer(index)
    
    rule_items = List.update_at(socket.assigns.rule_items, index, fn item ->
      Map.put(item, field, value)
    end)
    
    rules = %{"items" => rule_items}
    
    if socket.assigns[:on_change] do
      send(self(), {socket.assigns.on_change, rules})
    end
    
    {:noreply, assign(socket, rule_items: rule_items)}
  end
  
  defp get_form_items(form_id) do
    # 获取表单所有题目项，可能需要在上下文中添加函数
    MyApp.Forms.list_form_items_for_form(form_id) || []
  end
end