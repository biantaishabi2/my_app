defmodule MyAppWeb.FormTemplateEditorLive do
  use MyAppWeb, :live_view
  alias MyApp.FormTemplates

  @impl true
  def mount(%{"id" => template_id}, _session, socket) do
    # 加载模板，如果找不到会抛出 Ecto.NoResultsError，由框架处理
    template = FormTemplates.get_template!(template_id)

    # 检查 template.structure 是否为 nil，如果是，则使用空列表
    structure = template.structure || []

    # 确保 structure 是一个列表 (以防数据库中存了非列表数据)
    structure = if is_list(structure), do: structure, else: []

    socket =
      socket
      |> assign(:template, template)
      |> assign(:structure, structure)
      |> assign(:editing_item_id, nil) # 用于控制编辑 Modal
      |> assign(:page_title, "编辑模板结构: #{template.name}") # 设置页面标题

    {:ok, socket}
  end

  @impl true
  def handle_event("update_structure_order", %{"ordered_ids" => ordered_ids}, socket) do
    # 获取当前模板和结构
    %{template: template, structure: current_structure} = socket.assigns
    
    # 根据新的顺序重新排列结构项
    reordered_structure = reorder_structure_items(current_structure, ordered_ids)
    
    # 保存更新后的模板
    case FormTemplates.update_template(template, %{structure: reordered_structure}) do
      {:ok, updated_template} ->
        {:noreply, 
          socket
          |> assign(:template, updated_template)
          |> assign(:structure, updated_template.structure)
          |> put_flash(:info, "模板结构顺序已更新")
        }
        
      {:error, _changeset} ->
        {:noreply, 
          socket
          |> put_flash(:error, "无法更新模板结构顺序")
        }
    end
  end

  @impl true
  def handle_event("save_structure", _params, socket) do
    # 获取当前模板和结构
    %{template: template, structure: current_structure} = socket.assigns
    
    # 保存当前结构（重用现有顺序，无需重排）
    case FormTemplates.update_template(template, %{structure: current_structure}) do
      {:ok, updated_template} ->
        {:noreply, 
          socket
          |> assign(:template, updated_template)
          |> assign(:structure, updated_template.structure)
          |> put_flash(:info, "模板结构已保存")
        }
        
      {:error, _changeset} ->
        {:noreply, 
          socket
          |> put_flash(:error, "无法保存模板结构")
        }
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header class="mb-6">
      <%= @page_title %>
      <:subtitle>拖动列表项可以重新排序。点击拖动图标并上下拖拽即可。</:subtitle>
      <:actions>
        <.link patch={~p"/forms"} class="button button-secondary">
          返回表单列表
        </.link>
      </:actions>
    </.header>

    <div class="space-y-4">
      <.flash_group flash={@flash} />

      <h2 class="text-xl font-semibold">结构元素</h2>
      <div id="structure-list" phx-hook="Sortable" class="space-y-2 border p-4 rounded bg-gray-50 min-h-[100px]">
        <%= if Enum.empty?(@structure) do %>
          <p class="text-gray-500 italic text-center py-4">此模板结构为空。请添加元素。</p>
        <% else %>
          <%= for element <- @structure do %>
            <% 
              elem_id = Map.get(element, "id", "unknown")
              elem_type = Map.get(element, "type", "unknown")
              elem_label = Map.get(element, "label") || Map.get(element, "title", "未命名元素")
              elem_required = Map.get(element, "required", false)
            %>
            <div 
              id={"item-#{elem_id}"} 
              data-id={elem_id} 
              class="flex items-center p-3 border rounded bg-white shadow-sm hover:bg-gray-50 transition duration-150 ease-in-out"
            >
              <span class="drag-handle text-gray-400 hover:text-gray-600 mr-3 cursor-move text-xl">⠿</span>
              <div class="flex-grow">
                <div class="flex items-center">
                  <span class="font-medium text-gray-800 mr-2">
                    [<%= elem_type %>]
                  </span>
                  <span class="text-gray-700"><%= elem_label %></span>
                  <%= if elem_required do %>
                    <span class="ml-2 text-red-500">*</span>
                  <% end %>
                </div>
                <div class="text-xs text-gray-500 mt-1">
                  ID: <%= elem_id %>
                  <%= if description = Map.get(element, "description") do %>
                    | <%= description %>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>

      <div class="mt-6 flex justify-between items-center">
        <button 
          type="button"
          phx-click="save_structure"
          class="px-4 py-2 bg-indigo-600 text-white text-sm rounded shadow hover:bg-indigo-700 transition"
        >
          保存排序
        </button>
        
        <div class="text-sm text-gray-500">
          提示：排序会在拖放完成后自动保存
        </div>
      </div>

      <%# 调试信息 %>
      <div class="mt-8 p-4 border rounded bg-gray-100">
        <h3 class="font-semibold mb-2">结构数据 (调试)</h3>
        <pre class="text-xs overflow-auto max-h-60"><%= inspect(@structure, pretty: true) %></pre>
      </div>
    </div>
    """
  end

  # 根据新的顺序重排结构项
  defp reorder_structure_items(structure, ordered_ids) do
    # 创建一个ID到结构项的映射
    id_to_item_map = Enum.reduce(structure, %{}, fn item, acc ->
      item_id = Map.get(item, "id")
      if item_id, do: Map.put(acc, item_id, item), else: acc
    end)
    
    # 按新顺序重组结构项
    reordered_items = Enum.map(ordered_ids, fn id -> 
      Map.get(id_to_item_map, id)
    end)
    |> Enum.filter(&(&1 != nil))
    
    # 处理可能不在ordered_ids中的项（尽管这种情况应该不会发生）
    missing_items = Enum.filter(structure, fn item ->
      item_id = Map.get(item, "id")
      item_id && !Enum.member?(ordered_ids, item_id)
    end)
    
    # 合并重排序的项和缺失的项
    reordered_items ++ missing_items
  end
end
