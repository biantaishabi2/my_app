defmodule MyAppWeb.FormTemplateEditorLive do
  use MyAppWeb, :live_view
  import MyAppWeb.FormLive.ItemRendererComponent
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
      <div id="structure-list" phx-hook="Sortable" class="space-y-4 border p-4 rounded bg-gray-50 min-h-[100px]">
        <%= if Enum.empty?(@structure) do %>
          <p class="text-gray-500 italic text-center py-4">此模板结构为空。请添加元素。</p>
        <% else %>
          <%= for element <- @structure do %>
            <% 
              elem_id = Map.get(element, "id", "unknown")
              elem_type = Map.get(element, "type", "unknown")
              elem_label = Map.get(element, "label") || Map.get(element, "title", "未命名元素")
              elem_required = Map.get(element, "required", false)
              elem_description = Map.get(element, "description")
              
              # 将模板项转换为FormItem结构，以便重用ItemRendererComponent
              form_item = %{
                id: elem_id,
                type: safe_to_atom(elem_type),
                label: elem_label,
                required: elem_required,
                description: elem_description,
                placeholder: Map.get(element, "placeholder"),
                options: format_options(Map.get(element, "options", [])),
                min: Map.get(element, "min"),
                max: Map.get(element, "max"),
                step: Map.get(element, "step"),
                max_rating: Map.get(element, "max_rating", 5),
                min_date: Map.get(element, "min_date"),
                max_date: Map.get(element, "max_date"),
                min_time: Map.get(element, "min_time"),
                max_time: Map.get(element, "max_time"),
                time_format: Map.get(element, "time_format", "24h"),
                show_format_hint: Map.get(element, "show_format_hint"),
                format_display: Map.get(element, "format_display"),
                matrix_rows: Map.get(element, "matrix_rows"),
                matrix_columns: Map.get(element, "matrix_columns"),
                matrix_type: safe_matrix_type(Map.get(element, "matrix_type")),
                image_caption_position: safe_caption_position(Map.get(element, "image_caption_position")),
                selection_type: safe_selection_type(Map.get(element, "selection_type")),
                multiple_files: Map.get(element, "multiple_files"),
                max_files: Map.get(element, "max_files"),
                max_file_size: Map.get(element, "max_file_size"),
                allowed_extensions: Map.get(element, "allowed_extensions"),
                region_level: Map.get(element, "region_level"),
                default_province: Map.get(element, "default_province")
              }
            %>
            <div 
              id={"item-#{elem_id}"} 
              data-id={elem_id} 
              class="p-3 border rounded bg-white shadow-sm hover:bg-gray-50 transition duration-150 ease-in-out"
            >
              <div class="flex items-center">
                <span class="drag-handle text-gray-400 hover:text-gray-600 mr-3 cursor-move text-xl">⠿</span>
                <div class="flex-grow">
                  <div class="flex items-center">
                    <span class="font-medium text-gray-800 mr-2">
                      [<%= elem_type %>]
                    </span>
                    <span class="text-gray-700 font-medium"><%= elem_label %></span>
                    <%= if elem_required do %>
                      <span class="ml-2 text-red-500">*</span>
                    <% end %>
                  </div>
                  <div class="text-xs text-gray-500 mt-1">
                    ID: <%= elem_id %>
                    <%= if elem_description do %>
                      | <%= elem_description %>
                    <% end %>
                  </div>
                </div>
              </div>
              
              <div class="mt-3 border-t pt-3">
                <MyAppWeb.FormLive.ItemRendererComponent.render_item item={form_item} mode={:edit_preview} />
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
  
  # 安全地将字符串转换为atom，如果转换失败则返回默认值:text_input
  defp safe_to_atom(type_str) when is_binary(type_str) do
    try do
      String.to_existing_atom(type_str)
    rescue
      ArgumentError -> :text_input
    end
  end
  defp safe_to_atom(_), do: :text_input

  # 安全处理matrix_type值
  defp safe_matrix_type("multiple"), do: :multiple
  defp safe_matrix_type(:multiple), do: :multiple
  defp safe_matrix_type(_), do: :single

  # 安全处理selection_type值
  defp safe_selection_type("multiple"), do: :multiple
  defp safe_selection_type(:multiple), do: :multiple
  defp safe_selection_type(_), do: :single

  # 安全处理image_caption_position值
  defp safe_caption_position("top"), do: :top
  defp safe_caption_position(:top), do: :top
  defp safe_caption_position("none"), do: :none
  defp safe_caption_position(:none), do: :none
  defp safe_caption_position(_), do: :bottom

  # 将模板选项格式化为FormItem需要的格式
  defp format_options(options) when is_list(options) do
    Enum.map(options, fn option ->
      %{
        id: Map.get(option, "id") || Map.get(option, :id) || Ecto.UUID.generate(),
        value: Map.get(option, "value") || Map.get(option, :value) || "",
        label: Map.get(option, "label") || Map.get(option, :label) || "",
        image_filename: Map.get(option, "image_filename") || Map.get(option, :image_filename)
      }
    end)
  end
  defp format_options(_), do: []

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
