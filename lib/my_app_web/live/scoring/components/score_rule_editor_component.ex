defmodule MyAppWeb.Scoring.Components.ScoreRuleEditorComponent do
  use MyAppWeb, :live_component
  alias MyApp.Scoring
  require Logger

  @doc """
  提供交互式界面编辑评分规则的 rules JSON 结构。

  ## 参数

  * `:rules` - 当前规则JSON数据
  * `:form_id` - 表单ID，用于加载表单项
  * `:id` - 组件ID
  * `:score_rule_id` - 评分规则ID，用于直接保存规则
  * `:current_user` - 当前用户，用于权限检查
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

    {:ok, assign(socket, rule_items: rule_items, rules: socket.assigns.rules)}
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
                  <form phx-change="update_rule_item" phx-target={@myself}>
                    <input type="hidden" name="index" value={index} />
                    <input type="hidden" name="field" value="item_id" />
                    <select
                      name="item_value"
                      class="mt-1 block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md"
                    >
                      <option value="">选择问题</option>
                      <%= for form_item <- get_form_items(@form_id) do %>
                        <option value={form_item.id} selected={item["item_id"] == form_item.id}>
                          <%= form_item.label %>
                        </option>
                      <% end %>
                    </select>
                  </form>
                </div>

                <div>
                  <label class="block text-xs font-medium text-gray-700">评分方法</label>
                  <form phx-change="update_rule_item" phx-target={@myself}>
                    <input type="hidden" name="index" value={index} />
                    <input type="hidden" name="field" value="scoring_method" />
                    <select
                      name="method_value"
                      class="mt-1 block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md"
                    >
                      <option value="exact_match" selected={item["scoring_method"] == "exact_match"}>完全匹配</option>
                    </select>
                  </form>
                </div>

                <div>
                  <label class="block text-xs font-medium text-gray-700">正确答案</label>
                  <% 
                    form_items = get_form_items(@form_id)
                    form_item = Enum.find(form_items, fn i -> i.id == item["item_id"] end)
                    item_type = form_item && form_item.type 
                  %>
                  
                  <%= case item_type do %>
                    <% :radio -> %>
                      <form phx-change="update_rule_item" phx-target={@myself}>
                        <input type="hidden" name="index" value={index} />
                        <input type="hidden" name="field" value="correct_answer" />
                        <select
                          name="value"
                          class="mt-1 block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md"
                        >
                          <option value="">选择正确答案</option>
                          <%= for option <- form_item.options || [] do %>
                            <option value={option.value} selected={item["correct_answer"] == option.value}>
                              <%= option.label || option.value %>
                            </option>
                          <% end %>
                        </select>
                      </form>
                      
                    <% :dropdown -> %>
                      <form phx-change="update_rule_item" phx-target={@myself}>
                        <input type="hidden" name="index" value={index} />
                        <input type="hidden" name="field" value="correct_answer" />
                        <select
                          name="value"
                          class="mt-1 block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md"
                        >
                          <option value="">选择正确答案</option>
                          <%= for option <- form_item.options || [] do %>
                            <option value={option.value} selected={item["correct_answer"] == option.value}>
                              <%= option.label || option.value %>
                            </option>
                          <% end %>
                        </select>
                      </form>
                      
                    <% :checkbox -> %>
                      <form phx-change="update_checkbox_answers" phx-target={@myself}>
                        <input type="hidden" name="index" value={index} />
                        <div class="mt-1 space-y-2 border p-2 rounded-md max-h-48 overflow-y-auto">
                          <%= for option <- form_item.options || [] do %>
                            <div class="flex items-center">
                              <input
                                type="checkbox"
                                id={"rule_#{index}_option_#{option.id || option.value}"}
                                name="checkbox_values[]"
                                value={option.value}
                                checked={is_checkbox_selected(item["correct_answer"], option.value)}
                                class="h-4 w-4 text-indigo-600 border-gray-300 focus:ring-indigo-500 rounded"
                              />
                              <label for={"rule_#{index}_option_#{option.id || option.value}"} class="ml-2 text-sm text-gray-700">
                                <%= option.label || option.value %>
                              </label>
                            </div>
                          <% end %>
                          <%= if Enum.empty?(form_item.options || []) do %>
                            <p class="text-xs text-gray-500 italic">此选项无可用选项</p>
                          <% end %>
                        </div>
                      </form>
                      
                    <% :rating -> %>
                      <form phx-change="update_rule_item" phx-target={@myself}>
                        <input type="hidden" name="index" value={index} />
                        <input type="hidden" name="field" value="correct_answer" />
                        <% max_rating = form_item && form_item.max_rating || 5 %>
                        <div class="flex flex-wrap gap-2 mt-1">
                          <%= for i <- 1..max_rating do %>
                            <button
                              type="button" 
                              phx-click="set_rating_value"
                              phx-value-index={index}
                              phx-value-rating={i}
                              phx-target={@myself}
                              class={"px-3 py-1 text-sm font-medium rounded-md focus:outline-none #{if to_string(item["correct_answer"]) == to_string(i), do: "bg-yellow-400 text-gray-900", else: "bg-gray-200 text-gray-700 hover:bg-gray-300"}"}
                            >
                              <%= i %>星
                            </button>
                          <% end %>
                        </div>
                      </form>
                      
                    <% :date -> %>
                      <form phx-change="update_rule_item" phx-target={@myself}>
                        <input type="hidden" name="index" value={index} />
                        <input type="hidden" name="field" value="correct_answer" />
                        <input
                          type="date"
                          name="value"
                          value={item["correct_answer"]}
                          class="mt-1 block w-full border-gray-300 focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md"
                        />
                      </form>
                      
                    <% :fill_in_blank -> %>
                      <% blank_count = form_item && form_item.blank_count || 1 %>
                      <div class="mt-1 space-y-4 border p-2 rounded-md">
                        <p class="text-xs text-gray-500">填空题答案设置（共<%= blank_count %>个空位）：</p>
                        
                        <%= if form_item && form_item.blank_text do %>
                          <!-- 显示填空题原文，带有空位标记 -->
                          <div class="bg-gray-50 p-3 rounded border text-sm mb-3">
                            <% 
                              # 提取填空位置和文本
                              parts = String.split(form_item.blank_text, ~r/\{\{(\d+)\}\}/, include_captures: true)
                              
                              # 解析每个部分
                              processed_parts =
                                Enum.map(parts, fn part ->
                                  case Regex.run(~r/\{\{(\d+)\}\}/, part) do
                                    [_, index] ->
                                      %{type: :blank, index: String.to_integer(index)}
                                    nil ->
                                      %{type: :text, content: part}
                                  end
                                end) 
                            %>
                            
                            <%= for part <- processed_parts do %>
                              <%= case part.type do %>
                                <% :text -> %>
                                  <span><%= part.content %></span>
                                <% :blank -> %>
                                  <span class="inline-block px-2 py-1 mx-1 border-b-2 border-indigo-300 bg-indigo-50 rounded text-center">
                                    [空位<%= part.index %>]
                                  </span>
                              <% end %>
                            <% end %>
                          </div>
                        <% end %>
                        
                        <div class="space-y-4 max-h-60 overflow-y-auto divide-y divide-gray-200">
                          <%= for i <- 1..blank_count do %>
                            <div class="flex flex-col pt-3">
                              <div class="flex justify-between items-center mb-1">
                                <span class="text-sm font-medium text-gray-700">空位<%= i %>:</span>
                                <div class="flex items-center">
                                  <span class="text-xs text-gray-500 mr-2">分值:</span>
                                  <input
                                    type="number"
                                    min="0"
                                    id={"blank_score_#{index}_#{i-1}"}
                                    value={get_blank_score(item["blank_scores"], i-1) || (
                                      if is_binary(item["score"]), 
                                      do: div(String.to_integer(item["score"] || "0"), blank_count),
                                      else: 0
                                    )}
                                    phx-blur="update_blank_score"
                                    phx-target={@myself}
                                    phx-value-index={index}
                                    phx-value-blank={i-1}
                                    class="w-16 px-2 py-1 border-gray-300 focus:ring-indigo-500 focus:border-indigo-500 text-sm rounded-md"
                                  />
                                </div>
                              </div>
                              <div class="flex items-center gap-2">
                                <span class="text-xs text-gray-500 min-w-[60px]">正确答案:</span>
                                <input
                                  type="text"
                                  id={"blank_#{index}_#{i-1}"}
                                  value={get_blank_answer(item["correct_answer"], i-1)}
                                  phx-blur="update_blank_answer"
                                  phx-target={@myself}
                                  phx-value-index={index}
                                  phx-value-blank={i-1}
                                  class="flex-1 px-3 py-1 border-gray-300 focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md"
                                />
                              </div>
                            </div>
                          <% end %>
                        </div>
                      </div>
                      
                    <% _ -> %>
                      <form phx-change="update_rule_item" phx-target={@myself}>
                        <input type="hidden" name="index" value={index} />
                        <input type="hidden" name="field" value="correct_answer" />
                        <input
                          type="text"
                          name="value"
                          value={item["correct_answer"]}
                          class="mt-1 block w-full border-gray-300 focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md"
                        />
                      </form>
                  <% end %>
                </div>

                <div>
                  <label class="block text-xs font-medium text-gray-700">分值</label>
                  <form phx-change="update_rule_item" phx-target={@myself}>
                    <input type="hidden" name="index" value={index} />
                    <input type="hidden" name="field" value="score" />
                    <input
                      type="number"
                      name="value"
                      min="0"
                      value={item["score"]}
                      class="mt-1 block w-full border-gray-300 focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md"
                    />
                  </form>
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

    # 直接保存规则到数据库
    save_rules_to_database(socket, rules)

    {:noreply, assign(socket, rule_items: rule_items, rules: rules)}
  end

  def handle_event("remove_rule_item", %{"index" => index}, socket) do
    index = String.to_integer(index)
    rule_items = List.delete_at(socket.assigns.rule_items, index)
    rules = %{"items" => rule_items}

    # 直接保存规则到数据库
    save_rules_to_database(socket, rules)

    {:noreply, assign(socket, rule_items: rule_items, rules: rules)}
  end

  # 处理下拉菜单选择事件，使用phx-change
  def handle_event("update_rule_item", %{"index" => index, "field" => field, "value" => value}, socket) do
    index = String.to_integer(index)

    rule_items = List.update_at(socket.assigns.rule_items, index, fn item ->
      Map.put(item, field, value)
    end)

    rules = %{"items" => rule_items}

    # 直接保存规则到数据库
    save_rules_to_database(socket, rules)

    {:noreply, assign(socket, rule_items: rule_items, rules: rules)}
  end

  # 处理表单控件事件的一般情况，包括select下拉菜单
  def handle_event("update_rule_item", params, socket) do
    # 从params中提取索引和字段信息
    index = params["index"]
    field = params["field"]

    # 提取表单值
    value = cond do
      # 检查问题选择
      params["item_value"] -> params["item_value"]
      # 检查评分方法选择
      params["method_value"] -> params["method_value"]
      # 使用直接的value值（对于文本和数字输入）
      params["value"] -> params["value"]
      # 其他情况
      true -> nil
    end

    if is_nil(index) or is_nil(field) or is_nil(value) do
      # 记录错误但不中断会话
      IO.puts("无效的更新参数 - index: #{index}, field: #{field}, value: #{inspect(value)}, params: #{inspect(params)}")
      {:noreply, socket}
    else
      # 转换索引为整数
      index = String.to_integer(index)

      # 更新rule_items
      rule_items = List.update_at(socket.assigns.rule_items, index, fn item ->
        Map.put(item, field, value)
      end)

      # 创建规则数据并更新socket
      rules = %{"items" => rule_items}

      # 直接保存规则到数据库
      save_rules_to_database(socket, rules)

      {:noreply, assign(socket, rule_items: rule_items, rules: rules)}
    end
  end
  
  # 处理复选框答案更新
  def handle_event("update_checkbox_answers", %{"index" => index, "checkbox_values" => values}, socket) do
    index = String.to_integer(index)
    
    # 更新为JSON格式
    new_answer = Jason.encode!(values)
    
    # 更新规则项
    rule_items = List.update_at(socket.assigns.rule_items, index, fn item ->
      Map.put(item, "correct_answer", new_answer)
    end)
    
    rules = %{"items" => rule_items}
    
    # 保存规则
    save_rules_to_database(socket, rules)
    
    {:noreply, assign(socket, rule_items: rule_items, rules: rules)}
  end
  
  # 处理没有选中复选框的情况
  def handle_event("update_checkbox_answers", %{"index" => index}, socket) do
    index = String.to_integer(index)
    
    # 空数组
    new_answer = "[]"
    
    # 更新规则项
    rule_items = List.update_at(socket.assigns.rule_items, index, fn item ->
      Map.put(item, "correct_answer", new_answer)
    end)
    
    rules = %{"items" => rule_items}
    
    # 保存规则
    save_rules_to_database(socket, rules)
    
    {:noreply, assign(socket, rule_items: rule_items, rules: rules)}
  end
  
  # 处理评分控件值选择
  def handle_event("set_rating_value", %{"index" => index, "rating" => rating}, socket) do
    index = String.to_integer(index)
    
    # 更新规则项
    rule_items = List.update_at(socket.assigns.rule_items, index, fn item ->
      Map.put(item, "correct_answer", rating)
    end)
    
    rules = %{"items" => rule_items}
    
    # 保存规则
    save_rules_to_database(socket, rules)
    
    {:noreply, assign(socket, rule_items: rule_items, rules: rules)}
  end
  
  # 处理填空题答案更新
  def handle_event("update_blank_answer", %{"index" => index, "blank" => blank_index, "value" => value}, socket) do
    index = String.to_integer(index)
    blank_index = String.to_integer(blank_index)
    
    # 获取当前规则项
    rule_item = Enum.at(socket.assigns.rule_items, index)
    current_answer = rule_item["correct_answer"] || "[]"
    
    # 解析当前答案
    current_values = 
      case Jason.decode(current_answer) do
        {:ok, values} when is_list(values) -> values
        _ -> if String.starts_with?(current_answer, "["), do: [], else: [current_answer]
      end
    
    # 确保数组足够长
    padded_values = 
      if length(current_values) <= blank_index do
        current_values ++ List.duplicate("", blank_index - length(current_values) + 1)
      else
        current_values
      end
    
    # 更新指定空位答案
    new_values = List.replace_at(padded_values, blank_index, value)
    
    # 更新为JSON格式
    new_answer = Jason.encode!(new_values)
    
    # 更新规则项
    rule_items = List.update_at(socket.assigns.rule_items, index, fn item ->
      Map.put(item, "correct_answer", new_answer)
    end)
    
    rules = %{"items" => rule_items}
    
    # 保存规则
    save_rules_to_database(socket, rules)
    
    {:noreply, assign(socket, rule_items: rule_items, rules: rules)}
  end
  
  # 处理填空题分值更新
  def handle_event("update_blank_score", %{"index" => index, "blank" => blank_index, "value" => value}, socket) do
    index = String.to_integer(index)
    blank_index = String.to_integer(blank_index)
    
    # 解析为整数分值
    score_value = 
      case Integer.parse(value) do
        {num, _} -> num
        :error -> 0
      end
    
    # 获取当前规则项
    rule_item = Enum.at(socket.assigns.rule_items, index)
    current_scores = rule_item["blank_scores"] || "[]"
    
    # 解析当前分值
    current_values = 
      case Jason.decode(current_scores) do
        {:ok, values} when is_list(values) -> values
        _ -> []
      end
    
    # 确保数组足够长
    padded_values = 
      if length(current_values) <= blank_index do
        current_values ++ List.duplicate(0, blank_index - length(current_values) + 1)
      else
        current_values
      end
    
    # 更新指定空位分值
    new_values = List.replace_at(padded_values, blank_index, score_value)
    
    # 更新为JSON格式
    new_scores = Jason.encode!(new_values)
    
    # 计算总分
    total_score = Enum.sum(new_values)
    
    # 更新规则项
    rule_items = List.update_at(socket.assigns.rule_items, index, fn item ->
      item 
      |> Map.put("blank_scores", new_scores)
      |> Map.put("score", to_string(total_score))
    end)
    
    rules = %{"items" => rule_items}
    
    # 保存规则
    save_rules_to_database(socket, rules)
    
    {:noreply, assign(socket, rule_items: rule_items, rules: rules)}
  end

  # 直接保存规则到数据库
  defp save_rules_to_database(socket, rules) do
    if Map.has_key?(socket.assigns, :score_rule_id) &&
       Map.has_key?(socket.assigns, :current_user) &&
       !is_nil(socket.assigns.score_rule_id) do

      # 获取评分规则
      case Scoring.get_score_rule(socket.assigns.score_rule_id) do
        {:ok, score_rule} ->
          # 更新规则
          Scoring.update_score_rule(
            score_rule,
            %{"rules" => rules},
            socket.assigns.current_user
          )
          |> case do
            {:ok, _updated_rule} ->
              IO.puts("规则已成功直接保存到数据库 - 规则项数量: #{length(rules["items"] || [])}")
            {:error, reason} ->
              IO.puts("保存规则失败: #{inspect(reason)}")
          end
        {:error, reason} ->
          IO.puts("获取评分规则失败: #{inspect(reason)}")
      end
    else
      # 没有score_rule_id或current_user，不能保存
      IO.puts("无法直接保存规则：未提供score_rule_id或current_user")
    end
  end

  defp get_form_items(form_id) do
    # 获取表单所有题目项
    form = MyApp.Forms.get_form(form_id)
    form.items || []
  end
  
  # 检查复选框选项是否被选中
  defp is_checkbox_selected(correct_answer, option_value) do
    cond do
      # JSON数组格式
      is_binary(correct_answer) && String.starts_with?(correct_answer, "[") ->
        case Jason.decode(correct_answer) do
          {:ok, values} when is_list(values) -> 
            # 确保比较时都是字符串
            Enum.any?(values, fn val -> to_string(val) == to_string(option_value) end)
          _ -> false
        end
        
      # 逗号分隔的值
      is_binary(correct_answer) && String.contains?(correct_answer, ",") ->
        values = String.split(correct_answer, ",") |> Enum.map(&String.trim/1)
        Enum.any?(values, fn val -> to_string(val) == to_string(option_value) end)
        
      # 单个值比较
      is_binary(correct_answer) -> 
        to_string(correct_answer) == to_string(option_value)
        
      # 默认情况
      true -> false
    end
  end
  
  # 获取填空题特定空位的答案
  defp get_blank_answer(correct_answer, blank_index) do
    cond do
      # JSON数组格式
      is_binary(correct_answer) && String.starts_with?(correct_answer, "[") ->
        case Jason.decode(correct_answer) do
          {:ok, values} when is_list(values) -> 
            Enum.at(values, blank_index, "")
          _ -> 
            if blank_index == 0, do: correct_answer, else: ""
        end
        
      # 单个值（用于第一个空位）
      is_binary(correct_answer) && blank_index == 0 -> 
        correct_answer
        
      # 其他情况
      true -> ""
    end
  end
  
  # 获取填空题特定空位的分值
  defp get_blank_score(blank_scores, blank_index) do
    cond do
      # 空值或非字符串
      is_nil(blank_scores) || !is_binary(blank_scores) -> 
        nil
        
      # JSON数组格式
      String.starts_with?(blank_scores, "[") ->
        case Jason.decode(blank_scores) do
          {:ok, values} when is_list(values) -> 
            Enum.at(values, blank_index)
          _ -> nil
        end
        
      # 其他情况
      true -> nil
    end
  end
end
