# lib/my_app_web/live/form_structure_demo_live.ex
defmodule MyAppWeb.FormStructureDemoLive do
  use MyAppWeb, :live_view

  # alias MyApp.FormTemplates # 不再需要 DB 操作
  # alias MyApp.FormTemplates.FormTemplate

  # 定义 JSON 文件路径
  # 使用新的 JSON 文件
  @template_json_path "priv/static/templates/form_structure_demo.json"

  @impl true
  def mount(_params, _session, socket) do
    # --- 修改：从 JSON 文件加载 ---
    case load_template_from_json() do
      {:ok, structure} ->
        socket =
          socket
          # |> assign(:template, template) # 没有 template 了
          |> assign(:structure, structure)

        {:ok, socket}

      {:error, reason} ->
        socket =
          socket
          |> put_flash(:error, "加载 JSON 模板失败: #{reason}")
          # |> assign(:template, nil)
          |> assign(:structure, [])

        {:ok, socket}
    end
  end

  # --- 处理拖放事件 (只更新 LiveView 状态) ---
  @impl true
  def handle_event(
        "move_item",
        %{"old_index" => old_index_str, "new_index" => new_index_str},
        socket
      ) do
    # if socket.assigns.template do # 不再检查 template
    old_index = String.to_integer(old_index_str)
    new_index = String.to_integer(new_index_str)

    current_structure = socket.assigns.structure

    if old_index >= 0 and old_index < length(current_structure) and
         new_index >= 0 and new_index <= length(current_structure) do
      {item_to_move, updated_structure} = List.pop_at(current_structure, old_index)
      final_new_index = if new_index > old_index, do: new_index - 1, else: new_index
      new_structure = List.insert_at(updated_structure, final_new_index, item_to_move)

      # --- 修改：移除持久化逻辑 ---
      # template = socket.assigns.template
      # case FormTemplates.update_template(template, %{structure: new_structure}) do
      #   {:ok, updated_template} ->
      #     {:noreply,
      #       socket
      #       # |> assign(:template, updated_template)
      #       |> assign(:structure, new_structure)
      #       |> put_flash(:info, "元素顺序已更新！")
      #     }
      #   {:error, changeset} ->
      #     IO.inspect(changeset, label: "Error updating template structure")
      #     {:noreply, put_flash(socket, :error, "保存顺序失败！")}
      # end

      # 只更新 assigns 和 flash 消息
      {:noreply,
       socket
       |> assign(:structure, new_structure)
       |> put_flash(:info, "元素顺序已在页面更新（未保存）！")}
    else
      {:noreply, put_flash(socket, :error, "无效的移动索引！")}
    end

    # else
    #   {:noreply, socket}
    # end
  end

  # --- 新增：处理前端拖放 Hook 发送的事件 ---
  @impl true
  def handle_event("update_structure_order", %{"ordered_ids" => ordered_ids}, socket) do
    # 调试输出
    IO.puts("Received new order: #{inspect(ordered_ids)}")

    # 获取当前的结构列表
    current_structure = socket.assigns.structure

    # 创建一个映射，方便通过 ID 查找元素
    structure_map = Enum.into(current_structure, %{}, fn item -> {Map.get(item, "id"), item} end)

    # 根据收到的 ID 顺序重新构建结构列表
    # 注意：过滤掉可能存在的 nil 或无效 ID
    new_structure =
      ordered_ids
      # 过滤掉 nil
      |> Enum.filter(&(&1 != nil))
      # 通过 ID 从映射中查找元素
      |> Enum.map(&Map.get(structure_map, &1))
      # 再次过滤，确保找到的元素存在
      |> Enum.filter(&(&1 != nil))

    # 检查重排后的列表长度是否与原列表一致，以防 ID 丢失
    if length(new_structure) == length(current_structure) do
      {:noreply, assign(socket, :structure, new_structure)}
    else
      IO.puts(
        "Error: Reordered structure length mismatch. Check data-id attributes and received IDs."
      )

      # 可以选择不更新，或者添加错误提示
      {:noreply, put_flash(socket, :error, "更新顺序时出错，部分项目丢失。")}
    end
  end

  @impl true
  def render(assigns) do
    # --- 渲染简单的拖放列表 ---
    ~H"""
    <.flash_group flash={@flash} />
    <div class="container mx-auto p-6">
      
      <h1 class="text-2xl font-bold mb-4">模板结构拖放 Demo (来自 JSON)</h1>

      <div
        id="structure-list"
        phx-hook="Sortable"
        class="space-y-2 border p-4 rounded bg-white shadow"
      >
        <%= if Enum.empty?(@structure) do %>
          <p class="text-gray-500 italic">模板结构为空或加载失败。</p>
        <% else %>
          <%= for element <- @structure do %>
            <% # JSON 解析通常返回字符串键
            elem_id = Map.get(element, "id") || "no-id"
            elem_type = Map.get(element, "type") || "N/A"
            elem_label = Map.get(element, "label") || Map.get(element, "title") || "" %>
            <div
              id={"item-#{elem_id}"}
              data-id={elem_id}
              class="flex items-center p-3 border rounded bg-gray-100 hover:bg-gray-200 transition duration-150 ease-in-out"
              draggable="true"
            >
              <span class="drag-handle text-gray-400 hover:text-gray-600 mr-3 cursor-move text-xl">
                ⠿
              </span>
              <div class="flex-grow">
                <span class="font-medium text-gray-800">[{elem_type}]</span>
                <span class="text-gray-600">{elem_label}</span>
                <span class="text-xs text-gray-400 ml-2">(ID: {elem_id})</span>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>

      <div class="mt-6 bg-gray-50 p-4 rounded border border-gray-200">
        <h3 class="font-semibold mb-2 text-gray-700">当前 Structure 顺序 (Assigns):</h3>
        <pre class="text-xs text-gray-600 overflow-auto max-h-60"><%= inspect(@structure, pretty: true, syntax_colors: [string: :green, atom: :cyan, number: :magenta]) %></pre>
      </div>
      %>
      %>
    </div>
    """
  end

  # --- 新增：从 JSON 文件加载模板的辅助函数 ---
  defp load_template_from_json do
    case File.read(@template_json_path) do
      {:ok, content} ->
        case Jason.decode(content) do
          # {:ok, %{"structure" => structure} = json_data} when is_list(structure) ->
          #   IO.puts("成功加载并解析模板 JSON: #{json_data["name"] || "(无名称)"}")
          #   {:ok, structure}
          # 直接解码为列表
          {:ok, structure_list} when is_list(structure_list) ->
            IO.puts("成功加载并解析模板 JSON 列表 (来自 #{@template_json_path})")
            {:ok, structure_list}

          # {:ok, _other_json} ->
          #   IO.puts("模板 JSON 解析成功，但缺少 'structure' 列表。")
          #   {:error, :invalid_format}
          {:error, reason} ->
            IO.puts("模板 JSON 解析错误: #{inspect(reason)}")
            {:error, :json_parsing_error}
        end

      {:error, reason} ->
        IO.puts("模板文件读取错误 (#{@template_json_path}): #{inspect(reason)}")
        {:error, :file_read_error}
    end
  end
end
