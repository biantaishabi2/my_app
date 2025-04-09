defmodule MyAppWeb.FormTemplateLive do
  use MyAppWeb, :live_view

  alias MyApp.Forms
  alias MyApp.FormTemplates.FormTemplate
  
  # 使用MyApp.FormTemplates上下文模块的API

  @impl true
  def mount(_params, _session, socket) do
    # 获取现有表单进行展示
    form_id = "b8fd73c1-c966-43e6-935f-06a893313ebd"
    form = Forms.get_form_with_full_preload(form_id)

    # 初始化模板结构
    template_structure = build_template_structure(form)

    # 创建模板结构预览
    template_preview = build_template_preview(template_structure)

    # 获取第一个和第二个控件的ID，用于表单控制
    first_item = Enum.find(form.items, fn item -> item.type == :text_input end)
    first_field_id = if first_item, do: first_item.id, else: nil

    second_item = Enum.find(Enum.drop(form.items, 1), fn item ->
      item.type in [:radio, :dropdown, :checkbox] and length(item.options) > 0
    end)
    second_field_id = if second_item, do: second_item.id, else: nil

    # 创建模板 (仅作记录，不直接使用)
    _template = %FormTemplate{
      name: "测试模板",
      description: "从表单自动生成的测试模板",
      structure: template_structure,
      is_active: true
    }

    # 为调试目的输出字段IDs
    IO.puts("Mount: 第一个字段ID=#{first_field_id}, 第二个字段ID=#{second_field_id}")

    # 添加正确的字段ID到表单数据
    form_data = %{
      "first_field_id" => first_field_id,
      "second_field_id" => second_field_id
    }

    # 使用表单模板筛选要显示的表单项
    rendered_items = MyApp.FormTemplates.filter_items_by_demo_rules(form.items, form_data, template_structure)

    {:ok,
      socket
      |> assign(:form, form)
      |> assign(:template_structure, template_structure)
      |> assign(:template_preview, template_preview)
      |> assign(:rendered_items, rendered_items)
      |> assign(:form_data, form_data)
      |> assign(:first_field_id, first_field_id)
      |> assign(:second_field_id, second_field_id)
    }
  end

  @impl true
  def handle_event("update_field", %{"_target" => [_field_id | _]} = params, socket) do
    # 从表单参数中提取所有字段值
    form_data = params
      |> Enum.filter(fn {key, _} ->
        not String.starts_with?(key, "_") # 忽略以_开头的特殊字段
      end)
      |> Map.new()

    # 输出完整的params以便调试
    IO.puts("原始参数: #{inspect(params)}")
    IO.puts("处理后表单数据: #{inspect(form_data)}")

    # 获取字段ID
    first_field_id = socket.assigns.first_field_id
    second_field_id = socket.assigns.second_field_id

    # 添加字段ID到表单数据，确保filter_items_by_conditions能够找到正确的字段
    form_data = form_data
      |> Map.put("first_field_id", first_field_id)
      |> Map.put("second_field_id", second_field_id)

    # 使用条件逻辑过滤要显示的表单项
    rendered_items = MyApp.FormTemplates.filter_items_by_demo_rules(socket.assigns.form.items, form_data, socket.assigns.template_structure)

    # 为调试目的打印数据
    first_value = Map.get(form_data, first_field_id, "")
    second_value = Map.get(form_data, second_field_id, "")
    IO.puts("字段ID: first=#{first_field_id}, second=#{second_field_id}")
    IO.puts("值更新: first=#{first_value}, second=#{second_value}")
    IO.puts("显示表单项数量: #{length(rendered_items)}")

    # 存储更新后的表单数据
    {:noreply,
      socket
      |> assign(:form_data, form_data)
      |> assign(:rendered_items, rendered_items)
    }
  end

  @impl true
  def handle_event("refresh_template", _params, socket) do
    # 重新加载表单数据
    form_id = socket.assigns.form.id
    form = Forms.get_form_with_full_preload(form_id)

    # 重建模板结构
    template_structure = build_template_structure(form)
    template_preview = build_template_preview(template_structure)

    # 获取字段ID
    first_field_id = socket.assigns.first_field_id
    second_field_id = socket.assigns.second_field_id

    # 确保表单数据中包含字段ID
    form_data = socket.assigns.form_data
      |> Map.put("first_field_id", first_field_id)
      |> Map.put("second_field_id", second_field_id)

    # 使用现有表单数据重新过滤表单项
    rendered_items = MyApp.FormTemplates.filter_items_by_demo_rules(form.items, form_data, template_structure)

    {:noreply,
      socket
      |> assign(:form, form)
      |> assign(:template_structure, template_structure)
      |> assign(:template_preview, template_preview)
      |> assign(:rendered_items, rendered_items)
      |> assign(:form_data, form_data)
      |> put_flash(:info, "模板已刷新")
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto p-6">
      <div class="bg-white rounded-lg shadow-lg overflow-hidden form-card">
        <div class="px-6 py-4 border-b border-gray-200">
          <div class="flex justify-between items-center">
            <h1 class="text-2xl font-bold text-gray-800">表单模板条件演示系统</h1>
            <div class="flex space-x-2">
              <button
                phx-click="refresh_template"
                class="px-4 py-2 bg-indigo-600 text-white text-sm rounded shadow hover:bg-indigo-700 transition form-button-primary"
              >
                重新加载模板
              </button>
            </div>
          </div>
          <p class="mt-2 text-gray-600 form-description">
            通过表单模板系统，您可以创建带有条件显示逻辑的表单，根据用户的输入动态显示或隐藏表单项。
          </p>
        </div>

        <div class="p-6 grid grid-cols-1 lg:grid-cols-2 gap-8">
          <!-- 左侧：条件控制面板 -->
          <div class="form-card">
            <h2 class="text-xl font-semibold mb-4 form-item-label">模板控制面板</h2>

            <div class="bg-blue-50 border-l-4 border-blue-400 p-4 mb-6">
              <div class="flex">
                <div class="flex-shrink-0">
                  <svg class="h-5 w-5 text-blue-400" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                    <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
                  </svg>
                </div>
                <div class="ml-3">
                  <p class="text-sm text-blue-700">
                    在下面的表单中输入不同的关键字，观察右侧表单项的条件渲染效果。
                  </p>
                </div>
              </div>
            </div>

            <form phx-change="update_field" class="space-y-6">
              <div class="form-field mb-4">
                <label class="block text-sm font-medium mb-1 form-item-label">关键字输入</label>
                <input
                  type="text"
                  name={@first_field_id}
                  id={@first_field_id}
                  value={Map.get(@form_data, @first_field_id, "")}
                  placeholder="试试输入：index, condition, complex"
                  class="w-full px-3 py-2 border rounded-md border-gray-300 focus:outline-none focus:ring-2 focus:ring-indigo-500 form-input"
                />
                <p class="text-xs text-gray-500 mt-1">* 支持的关键字: index, condition, complex</p>
              </div>

              <div class="form-field mb-4">
                <label class="block text-sm font-medium mb-1 form-item-label">选择选项</label>
                <select
                  name={@second_field_id}
                  id={@second_field_id}
                  class="w-full px-3 py-2 border rounded-md border-gray-300 focus:outline-none focus:ring-2 focus:ring-indigo-500 form-input"
                >
                  <option value="选项A" selected={Map.get(@form_data, @second_field_id) == "选项A"}>选项 A</option>
                  <option value="选项B" selected={Map.get(@form_data, @second_field_id) == "选项B"}>选项 B</option>
                  <option value="选项C" selected={Map.get(@form_data, @second_field_id) == "选项C"}>选项 C</option>
                </select>
                <p class="text-xs text-gray-500 mt-1">* 当选择"选项B"时会显示特定表单项</p>
              </div>
            </form>

            <div class="mt-8">
              <h3 class="font-semibold mb-2 text-gray-700">模板结构预览</h3>
              <div class="bg-gray-50 p-4 rounded-md border border-gray-200">
                <pre class="text-xs text-gray-600 overflow-auto max-h-96 whitespace-pre-wrap"><%= @template_preview %></pre>
              </div>
            </div>

            <div class="mt-6">
              <h3 class="font-semibold mb-2 text-gray-700">当前表单数据</h3>
              <div class="bg-gray-50 p-4 rounded-md border border-gray-200">
                <pre class="text-xs text-gray-600 overflow-auto"><%= inspect(@form_data, pretty: true) %></pre>
              </div>
            </div>
          </div>

          <!-- 右侧：渲染的表单 -->
          <div class="form-card">
            <h2 class="text-xl font-semibold mb-4 form-item-label">渲染后的表单</h2>

            <div class="bg-white rounded-lg border border-gray-200 overflow-hidden">
              <div class="px-4 py-5 sm:p-6 space-y-6">
                <%= if Enum.empty?(@rendered_items) do %>
                  <div class="text-center py-12 bg-gray-50 rounded-lg">
                    <svg xmlns="http://www.w3.org/2000/svg" class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
                    </svg>
                    <h3 class="mt-2 text-sm font-medium text-gray-900">无可显示的表单项</h3>
                    <p class="mt-1 text-sm text-gray-500">
                      当前条件下没有符合显示要求的表单项。
                    </p>
                    <p class="text-xs text-gray-500 mt-2">
                      请尝试更改左侧的条件值。
                    </p>
                  </div>
                <% else %>
                  <%= for item <- @rendered_items do %>
                    <div class="form-item-container mb-4" id={"item-container-#{item.id}"}>
                      <div class="form-field form-item">
                        <label class={"block text-sm font-medium mb-1 #{if item.required, do: "required", else: ""}"}>
                          <%= item.label %>
                          <%= if item.required do %>
                            <span class="form-item-required text-red-500 required-mark">*</span>
                          <% end %>
                        </label>

                        <%= case item.type do %>
                          <% :text_input -> %>
                            <input
                              type="text"
                              id={item.id}
                              name={"form[#{item.id}]"}
                              placeholder={item.placeholder || "请输入..."}
                              class="w-full px-3 py-2 border rounded-md border-gray-300 focus:outline-none focus:ring-2 focus:ring-indigo-500 form-input"
                              disabled
                            />

                          <% :number -> %>
                            <input
                              type="number"
                              id={item.id}
                              name={"form[#{item.id}]"}
                              class="w-full px-3 py-2 border rounded-md border-gray-300 focus:outline-none focus:ring-2 focus:ring-indigo-500 form-input"
                              disabled
                            />

                          <% :radio -> %>
                            <div class="space-y-2 radio-field-options">
                              <%= for option <- item.options || [] do %>
                                <div class="flex items-center radio-option">
                                  <input
                                    type="radio"
                                    id={"#{item.id}_#{option.value}"}
                                    name={"form[#{item.id}]"}
                                    value={option.value}
                                    class="h-4 w-4 text-indigo-600 focus:ring-indigo-500"
                                    disabled
                                  />
                                  <label for={"#{item.id}_#{option.value}"} class="ml-2 text-sm text-gray-700 block">
                                    <%= option.label %>
                                  </label>
                                </div>
                              <% end %>
                            </div>

                          <% :dropdown -> %>
                            <select
                              id={item.id}
                              name={"form[#{item.id}]"}
                              class="w-full px-3 py-2 border rounded-md border-gray-300 focus:outline-none focus:ring-2 focus:ring-indigo-500 form-input"
                              disabled
                            >
                              <option value="" disabled selected>请选择...</option>
                              <%= for option <- item.options || [] do %>
                                <option value={option.value}><%= option.label %></option>
                              <% end %>
                            </select>

                          <% :checkbox -> %>
                            <div class="space-y-2">
                              <%= for option <- item.options || [] do %>
                                <div class="flex items-center">
                                  <input
                                    type="checkbox"
                                    id={"#{item.id}_#{option.value}"}
                                    name={"form[#{item.id}][]"}
                                    value={option.value}
                                    class="h-4 w-4 text-indigo-600 focus:ring-indigo-500"
                                    disabled
                                  />
                                  <label for={"#{item.id}_#{option.value}"} class="ml-2 text-sm text-gray-700 block">
                                    <%= option.label %>
                                  </label>
                                </div>
                              <% end %>
                            </div>

                          <% :date -> %>
                            <div class="relative">
                              <input
                                type="date"
                                id={item.id}
                                name={"form[#{item.id}]"}
                                class="w-full px-3 py-2 border rounded-md border-gray-300 focus:outline-none focus:ring-2 focus:ring-indigo-500 form-input"
                                disabled
                              />
                            </div>

                          <% :rating -> %>
                            <div class="flex items-center">
                              <%= for _i <- 1..5 do %>
                                <span class="text-2xl mx-1 cursor-pointer text-gray-300">★</span>
                              <% end %>
                              <span class="ml-2 text-gray-500">请评分</span>
                            </div>

                          <% _ -> %>
                            <div class="text-gray-500 text-sm">
                              <%= item.type %> 类型控件 (预览模式)
                            </div>
                        <% end %>

                        <%= if item.description do %>
                          <div class="text-sm text-gray-500 mt-1"><%= item.description %></div>
                        <% end %>
                      </div>
                    </div>
                  <% end %>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # 从现有表单构建模板结构
  defp build_template_structure(form) do
    # 选择一些表单项类型作为示例
    sample_types = [:text_input, :number, :radio, :dropdown, :checkbox, :date, :rating]

    # 从现有表单中筛选出需要的表单项
    filtered_items = form.items
      |> Enum.filter(fn item -> item.type in sample_types end)
      |> Enum.take(10) # 使用更多表单项来展示不同条件

    # 确保至少有一个文本输入类型
    text_item = Enum.find(filtered_items, fn item -> item.type == :text_input end)
    first_item_id = if text_item, do: text_item.id, else: nil

    # 找到第二个表单项，最好是下拉选择或单选按钮类型
    second_item = Enum.find(Enum.drop(filtered_items, 1), fn item ->
      item.type in [:radio, :dropdown, :checkbox] and length(item.options) > 0
    end)
    second_item_id = if second_item, do: second_item.id, else: nil

    # 构建模板结构，包含不同类型的条件显示
    filtered_items
    |> Enum.with_index()
    |> Enum.map(fn {item, index} ->
      # 转换到模板结构格式
      base_label = get_label_with_prefix(item.label, index)

      # 为特殊控件类型添加更清晰的标签，根据索引位置处理
      enhanced_label = maybe_add_type_specific_prefix(base_label, item.type, index)

      base_structure = %{
        type: convert_type(item.type),
        name: item.id,
        # 添加前缀以便更容易识别条件类型
        label: enhanced_label
      }

      # 添加选项（如果有）
      with_options = if item.type in [:radio, :dropdown, :checkbox] and length(item.options) > 0 do
        options = Enum.map(item.options, fn opt -> opt.label end)
        Map.put(base_structure, :options, options)
      else
        base_structure
      end

      # 基于控件类型和索引添加不同类型的条件
      cond do
        # 前两个表单项无条件显示
        index < 2 ->
          with_options

        # 第3-4个表单项：当第一个表单项的值包含"index"时显示
        index >= 2 and index < 4 and is_binary(first_item_id) ->
          Map.put(with_options, :condition, %{
            operator: "contains",
            left: %{type: "field", name: first_item_id},
            right: %{type: "value", value: "index"}
          })

        # 第5-6个表单项：当第一个表单项的值包含"condition"时显示
        index >= 4 and index < 6 and is_binary(first_item_id) ->
          Map.put(with_options, :condition, %{
            operator: "contains",
            left: %{type: "field", name: first_item_id},
            right: %{type: "value", value: "condition"}
          })

        # 日期控件：在输入"complex"时显示
        item.type == :date and is_binary(first_item_id) ->
          Map.put(with_options, :condition, %{
            operator: "contains",
            left: %{type: "field", name: first_item_id},
            right: %{type: "value", value: "complex"}
          })
          
        # 时间控件：在输入"complex"时显示
        item.type == :time and is_binary(first_item_id) ->
          Map.put(with_options, :condition, %{
            operator: "contains",
            left: %{type: "field", name: first_item_id},
            right: %{type: "value", value: "complex"}
          })
        
        # 地区控件：当选择"选项B"时显示
        item.type == :region and is_binary(second_item_id) ->
          Map.put(with_options, :condition, %{
            operator: "==",
            left: %{type: "field", name: second_item_id},
            right: %{type: "value", value: "选项B"}
          })
          
        # 评分控件：同时满足"选择选项B"和"输入complex"
        item.type == :rating and is_binary(first_item_id) and is_binary(second_item_id) ->
          Map.put(with_options, :condition, %{
            operator: "and",
            conditions: [
              %{
                operator: "contains",
                left: %{type: "field", name: first_item_id},
                right: %{type: "value", value: "complex"}
              },
              %{
                operator: "==",
                left: %{type: "field", name: second_item_id},
                right: %{type: "value", value: "选项B"}
              }
            ]
          })
          
        # 默认情况
        true ->
          with_options
      end
    end)
  end

  # 根据索引为标签添加前缀
  defp get_label_with_prefix(label, index) do
    cond do
      index < 2 ->
        "[始终显示] #{label}"
      index >= 2 and index < 4 ->
        "[输入'index'显示] #{label}"
      index >= 4 and index < 6 ->
        "[输入'condition'显示] #{label}"
      index >= 6 and index < 8 ->
        "[输入'complex'显示] #{label}"
      index == 8 ->
        "[第二题选择'选项B'显示] #{label}"
      true ->
        label
    end
  end

  # 根据控件类型为标签添加特殊描述前缀
  defp maybe_add_type_specific_prefix(label, item_type, _index) do
    cond do
      # 评分控件
      item_type == :rating -> 
        "[评分控件 - 选择'选项B'+输入'complex'] #{label}"
        
      # 地区控件
      item_type == :region -> 
        "[地区控件 - 仅选择'选项B'显示] #{label}"
        
      # 时间控件
      item_type == :time -> 
        "[时间控件 - 输入'complex'显示] #{label}"
        
      # 其他控件使用默认标签
      true ->
        label
    end
  end

  # 构建模板预览（格式化为易读文本）
  defp build_template_preview(template_structure) do
    template_structure
    |> Enum.map(fn item ->
      # 获取原始类型
      original_type = get_original_type(item.type)
      
      # 获取条件文本
      condition_text = if Map.has_key?(item, :condition) do
        # 提取条件详情，使描述更具体
        condition_desc = case item.type do
          "text" -> "输入特定关键字时显示"
          "number" -> "输入特定关键字时显示"
          "select" -> "输入特定关键字时显示"
          _ -> "满足特定条件时显示"
        end
        "（#{condition_desc}）"
      else
        ""
      end
      
      # 获取选项文本
      options_text = if Map.has_key?(item, :options) do
        options_str = Enum.join(item.options, ", ")
        "选项: [#{options_str}]"
      else
        ""
      end
      
      # 构建控件描述，确保显示正确的控件类型
      type_desc = case original_type do
        :text_input -> "文本输入"
        :number -> "数字"
        :radio -> "单选"
        :dropdown -> "下拉选择"
        :checkbox -> "多选"
        :date -> "日期"
        :time -> "时间"
        :rating -> "评分"
        :region -> "地区选择"
        _ -> "#{original_type}"
      end
      
      "#{item.label} (#{type_desc}) #{options_text} #{condition_text}"
    end)
    |> Enum.join("\n")
  end
  
  # 反向推导原始控件类型
  defp get_original_type(template_type) do
    try do
      case template_type do
        "text" -> :text_input
        "number" -> 
          # number可能是:number或:rating，默认为:number
          :number
        "select" -> 
          # select可能是:radio, :dropdown, :checkbox，默认为:dropdown
          :dropdown
        _ when is_binary(template_type) -> String.to_existing_atom(template_type)
        _ -> :unknown
      end
    rescue
      _ -> :unknown
    end
  end

  # 转换表单项类型到模板类型
  defp convert_type(form_type) do
    case form_type do
      :text_input -> "text"
      :number -> "number"
      :radio -> "select"
      :dropdown -> "select"
      :checkbox -> "select"
      :date -> "text"
      :rating -> "number"
      _ -> "text" # 默认为文本类型
    end
  end

  # 删除了过滤函数，现在使用上下文模块提供的API
end
