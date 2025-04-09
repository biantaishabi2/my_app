defmodule MyAppWeb.FormTemplateLive do
  use MyAppWeb, :live_view
  import MyAppWeb.FormLive.ItemRendererComponent

  alias MyApp.Forms
  alias MyApp.FormTemplates.FormTemplate
  
  # 使用MyApp.FormTemplates上下文模块的API
  
  # 模板JSON文件路径
  @template_json_path "/home/wangbo/document/wangbo/my_app/priv/static/templates/form_demo_template.json"

  @impl true
  def mount(_params, _session, socket) do
    # 获取现有表单进行展示
    form_id = "b8fd73c1-c966-43e6-935f-06a893313ebd"
    form = Forms.get_form_with_full_preload(form_id)

    # 从JSON文件加载模板结构
    template_data = load_template_from_json()
    template_structure = template_data["structure"]
    
    # 创建模板结构预览
    template_preview = build_template_preview(template_structure)

    # 获取第一个和第二个控件的ID，用于表单控制
    first_item = Enum.find(form.items, fn item -> item.type == :text_input end)
    first_field_id = if first_item, do: first_item.id, else: nil

    second_item = Enum.find(Enum.drop(form.items, 1), fn item ->
      item.type in [:radio, :dropdown, :checkbox] and length(item.options) > 0
    end)
    second_field_id = if second_item, do: second_item.id, else: nil

    # 为调试目的输出字段IDs
    IO.puts("Mount: 第一个字段ID=#{first_field_id}, 第二个字段ID=#{second_field_id}")

    # 添加正确的字段ID到表单数据
    form_data = %{
      "first_field_id" => first_field_id,
      "second_field_id" => second_field_id
    }

    # 使用表单模板筛选要显示的表单项
    rendered_items = filter_items_by_template(form.items, template_structure, form_data)

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

    # 添加字段ID到表单数据，确保过滤条件能够找到正确的字段
    form_data = form_data
      |> Map.put("first_field_id", first_field_id)
      |> Map.put("second_field_id", second_field_id)

    # 使用模板条件过滤要显示的表单项
    rendered_items = filter_items_by_template(
      socket.assigns.form.items, 
      socket.assigns.template_structure, 
      form_data
    )

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

    # 重新从JSON文件加载模板结构
    template_data = load_template_from_json()
    template_structure = template_data["structure"]
    template_preview = build_template_preview(template_structure)

    # 获取字段ID
    first_field_id = socket.assigns.first_field_id
    second_field_id = socket.assigns.second_field_id

    # 确保表单数据中包含字段ID
    form_data = socket.assigns.form_data
      |> Map.put("first_field_id", first_field_id)
      |> Map.put("second_field_id", second_field_id)

    # 使用现有表单数据重新过滤表单项
    rendered_items = filter_items_by_template(form.items, template_structure, form_data)

    {:noreply,
      socket
      |> assign(:form, form)
      |> assign(:template_structure, template_structure)
      |> assign(:template_preview, template_preview)
      |> assign(:rendered_items, rendered_items)
      |> assign(:form_data, form_data)
      |> put_flash(:info, "模板已从JSON文件重新加载")
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

                        <MyAppWeb.FormLive.ItemRendererComponent.render_item item={item} mode={:edit_preview} />

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

  # 从JSON文件加载模板
  defp load_template_from_json do
    case File.read(@template_json_path) do
      {:ok, content} ->
        # 解析JSON内容
        case Jason.decode(content) do
          {:ok, json_data} ->
            # 成功解析JSON
            IO.puts("成功加载模板JSON: #{json_data["name"]}")
            json_data
          {:error, reason} ->
            # JSON解析错误
            IO.puts("模板JSON解析错误: #{inspect(reason)}")
            %{"structure" => %{"items" => []}}
        end
      {:error, reason} ->
        # 文件读取错误
        IO.puts("模板文件读取错误: #{inspect(reason)}")
        %{"structure" => %{"items" => []}}
    end
  end
  
  # 根据模板筛选要显示的表单项
  defp filter_items_by_template(items, template_structure, form_data) do
    # 获取模板中的项目列表
    template_items = template_structure["items"] || []
    
    # 获取字段ID
    first_field_id = Map.get(form_data, "first_field_id")
    second_field_id = Map.get(form_data, "second_field_id")
    
    # 根据模板条件筛选表单项
    items
    |> Enum.with_index()
    |> Enum.filter(fn {item, index} -> 
      # 找到对应的模板项
      template_item = Enum.at(template_items, index)
      
      if template_item do
        # 获取条件
        condition = template_item["condition"]
        
        # 评估条件
        cond do
          # 没有条件，始终显示
          is_nil(condition) ->
            true
            
          # 有特定的控件类型条件
          template_item["item_type"] == "rating" ->
            # 评分控件：需要同时满足"complex"和"选项B"
            String.contains?(Map.get(form_data, first_field_id, ""), "complex") and 
            Map.get(form_data, second_field_id) == "选项B"
            
          template_item["item_type"] == "region" ->
            # 地区控件：只需要满足"选项B"
            Map.get(form_data, second_field_id) == "选项B"
            
          template_item["item_type"] == "time" or template_item["item_type"] == "date" ->
            # 时间和日期控件：需要满足"complex"
            String.contains?(Map.get(form_data, first_field_id, ""), "complex")
            
          # 包含"index"的条件
          condition["operator"] == "contains" and condition["right"]["value"] == "index" ->
            String.contains?(Map.get(form_data, first_field_id, ""), "index")
            
          # 包含"condition"的条件
          condition["operator"] == "contains" and condition["right"]["value"] == "condition" ->
            String.contains?(Map.get(form_data, first_field_id, ""), "condition")
            
          # 复合条件
          condition["operator"] == "and" ->
            evaluate_compound_condition(condition, form_data)
            
          # 默认情况：不显示
          true ->
            false
        end
      else
        # 如果没有对应的模板项，不显示
        false
      end
    end)
    |> Enum.map(fn {item, _} -> item end)
  end
  
  # 评估复合条件
  defp evaluate_compound_condition(condition, form_data) do
    conditions = condition["conditions"] || []
    
    # 计算所有子条件的结果
    results = Enum.map(conditions, fn subcondition ->
      evaluate_simple_condition(subcondition, form_data)
    end)
    
    # 根据操作符组合结果
    case condition["operator"] do
      "and" -> Enum.all?(results)
      "or" -> Enum.any?(results)
      _ -> false
    end
  end
  
  # 评估简单条件
  defp evaluate_simple_condition(condition, form_data) do
    operator = condition["operator"]
    left = condition["left"]
    right = condition["right"]
    
    # 获取左值
    left_value = case left do
      %{"type" => "field", "name" => field_name} ->
        Map.get(form_data, field_name, "")
      _ -> 
        ""
    end
    
    # 获取右值
    right_value = case right do
      %{"type" => "value", "value" => value} ->
        value
      _ ->
        ""
    end
    
    # 根据操作符评估
    case operator do
      "contains" ->
        String.contains?(left_value, right_value)
      "==" ->
        left_value == right_value
      _ ->
        false
    end
  end

  # 构建模板预览（格式化为易读文本）
  defp build_template_preview(template_structure) do
    # 获取模板项
    items = template_structure["items"] || []
    
    # 构建可读的预览文本
    items
    |> Enum.map(fn item ->
      # 获取标签和类型
      label = item["label"] || "未命名项"
      item_type = item["item_type"] || "text"
      
      # 获取条件描述
      condition_text = if item["condition"] do
        condition_desc = cond do
          item_type == "rating" ->
            "当同时满足'选择选项B'和'输入complex'时显示"
          item_type == "region" ->
            "当选择'选项B'时显示"
          item_type == "time" || item_type == "date" ->
            "当输入'complex'时显示"
          item["condition"]["right"]["value"] == "index" ->
            "当输入'index'时显示"
          item["condition"]["right"]["value"] == "condition" ->
            "当输入'condition'时显示"
          true ->
            "满足特定条件时显示"
        end
        "（#{condition_desc}）"
      else
        ""
      end
      
      # 类型描述
      type_desc = case item_type do
        "text" -> "文本输入"
        "number" -> "数字"
        "select" -> "选择"
        "date" -> "日期"
        "time" -> "时间"
        "rating" -> "评分"
        "region" -> "地区选择"
        "file" -> "文件上传"
        "image" -> "图片选择"
        "matrix" -> "矩阵问题"
        _ -> item_type
      end
      
      # 组合成预览文本
      "#{label} (#{type_desc}) #{condition_text}"
    end)
    |> Enum.join("\n")
  end
end
