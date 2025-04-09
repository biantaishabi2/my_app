defmodule MyAppWeb.FormHelpers do
  @moduledoc """
  Helper functions for form item data processing and rendering.
  """
  use Phoenix.Component

  alias MyApp.Forms.ItemOption
  alias Ecto.UUID
  require Logger

  @doc """
  Process form item parameters before saving to the database.
  - Converts type strings to atoms
  - Normalizes the required field
  - Ensures all keys are strings
  """
  def process_item_params(params) do
    # 确保所有键都是字符串
    params = normalize_params(params)
    # 类型转换
    params = convert_type_to_atom(params)
    # 必填项处理
    normalize_required_field(params)
  end

  @doc """
  Ensures all map keys are strings.
  """
  def normalize_params(params) when is_map(params) do
    Enum.reduce(params, %{}, fn {k, v}, acc ->
      key = if is_atom(k), do: Atom.to_string(k), else: k
      value = if is_map(v), do: normalize_params(v), else: v
      Map.put(acc, key, value)
    end)
  end
  def normalize_params(params), do: params

  @doc """
  Converts the 'type' field from string to atom if present.
  """
  def convert_type_to_atom(%{"type" => type_str} = params) when is_binary(type_str) do
    Map.put(params, "type", safe_to_atom(type_str))
  end
  def convert_type_to_atom(params), do: params

  @doc """
  Normalizes the 'required' field to boolean.
  """
  def normalize_required_field(%{"required" => "true"} = params) do
    Map.put(params, "required", true)
  end
  def normalize_required_field(%{"required" => "false"} = params) do
    Map.put(params, "required", false)
  end
  def normalize_required_field(%{"required" => required} = params) when is_boolean(required) do
    params
  end
  def normalize_required_field(params) do
    Map.put(params, "required", false)  # Default to false
  end

  @doc """
  Checks if a form item type requires options.
  """
  def requires_options?(item_type) when is_atom(item_type) do
    item_type in [:radio, :checkbox, :dropdown]
  end
  def requires_options?(item_type) when is_binary(item_type) do
    item_type in ["radio", "checkbox", "dropdown"]
  end
  def requires_options?(_), do: false

  @doc """
  Safely converts a string to an existing atom.

  Returns `:text_input` if the string cannot be converted or is not binary.
  """
  def safe_to_atom(type_str) when is_binary(type_str) do
    try do
      String.to_existing_atom(type_str)
    rescue
      ArgumentError ->
        Logger.warning("Failed to convert string \"#{type_str}\" to atom, defaulting to :text_input")
        :text_input
    end
  end
  def safe_to_atom(val) do
    Logger.warning("safe_to_atom called with non-binary value: #{inspect(val)}, defaulting to :text_input")
    :text_input
  end

  @doc """
  Ensures the matrix type is either `:single` or `:multiple`. Defaults to `:single`.
  """
  def safe_matrix_type("multiple"), do: :multiple
  def safe_matrix_type(:multiple), do: :multiple
  def safe_matrix_type(_), do: :single

  @doc """
  Ensures the selection type is either `:single` or `:multiple`. Defaults to `:single`.
  """
  def safe_selection_type("multiple"), do: :multiple
  def safe_selection_type(:multiple), do: :multiple
  def safe_selection_type(_), do: :single

  @doc """
  Ensures the image caption position is `:top`, `:bottom`, or `:none`. Defaults to `:bottom`.
  """
  def safe_caption_position("top"), do: :top
  def safe_caption_position(:top), do: :top
  def safe_caption_position("none"), do: :none
  def safe_caption_position(:none), do: :none
  def safe_caption_position(_), do: :bottom

  @doc """
  Formats options from template structure (fallback case) into a list of ItemOption structs
  for use with ItemRendererComponent.
  """
  # 这个函数现在只用于回退情况，确保返回 ItemOption 结构体列表以兼容 ItemRendererComponent
  def format_options_for_component(options) when is_list(options) do
    # Logger.debug("Formatting options (fallback): #{inspect(options)}") # Debug logging if needed

    result = Enum.map(options, fn option ->
      formatted = cond do
        # 处理Map类型的选项 (来自template structure)
        is_map(option) ->
          id = Map.get(option, "id") || Map.get(option, :id) || UUID.generate()
          value = Map.get(option, "value") || Map.get(option, :value) || ""
          label = Map.get(option, "label") || Map.get(option, :label) || value || ""
          image_filename = Map.get(option, "image_filename") || Map.get(option, :image_filename)

          %ItemOption{ # 返回 ItemOption 结构体
            id: id,
            value: value,
            label: label,
            image_filename: image_filename,
             # 确保其他必须字段有默认值
            order: Map.get(option, "order", 0),
            form_item_id: nil, # 回退时无法确定
            image_id: Map.get(option, "image_id")
          }

        # 处理字符串类型的选项 (来自template structure)
        is_binary(option) ->
           %ItemOption{
             id: UUID.generate(),
             value: option,
             label: option,
             order: 0,
             form_item_id: nil,
             image_filename: nil,
             image_id: nil
           }

        # 其他无法处理的类型
        true ->
          Logger.warning("Unsupported option format encountered in format_options_for_component: #{inspect(option)}")
          nil
      end
      formatted
    end)
    |> Enum.filter(&(&1 != nil)) # 过滤掉处理失败的选项

    # Logger.debug("Formatted result: #{inspect(result)}") # Debug logging if needed
    result
  end
  def format_options_for_component(nil), do: [] # 确保 nil 返回空列表
  def format_options_for_component(_), do: [] # 确保其他类型返回空列表


  @doc """
  Displays the user-friendly name for a selected form item type.
  """
  def display_selected_type(nil), do: "未选择"
  def display_selected_type("text_input"), do: "文本输入"
  def display_selected_type("textarea"), do: "文本区域"
  def display_selected_type("radio"), do: "单选按钮"
  def display_selected_type("dropdown"), do: "下拉菜单"
  def display_selected_type("checkbox"), do: "复选框"
  def display_selected_type("rating"), do: "评分"
  def display_selected_type("number"), do: "数字输入"
  def display_selected_type("email"), do: "邮箱输入"
  def display_selected_type("phone"), do: "电话号码"
  def display_selected_type("date"), do: "日期选择"
  def display_selected_type("time"), do: "时间选择"
  def display_selected_type("region"), do: "地区选择"
  def display_selected_type("matrix"), do: "矩阵题"
  def display_selected_type("image_choice"), do: "图片选择"
  def display_selected_type("file_upload"), do: "文件上传"
  def display_selected_type(atom) when is_atom(atom), do: display_selected_type(Atom.to_string(atom))
  def display_selected_type(_), do: "未知类型"

  @doc """
  Renders the appropriate input field for a logic condition's value based on the item type.
  Handles both FormItem structs and maps (e.g., from template structure).
  """
  attr :item, :any, required: true, doc: "The form item map or struct for the condition source."
  attr :condition, :map, default: %{}, doc: "The current logic condition map."
  def render_condition_value_input(assigns) do
    ~H"""
    <%
      # Safely extract item details inside the template
      item = @item # Can be struct or map
      condition = @condition
      current_value = get_in(condition || %{}, ["value"]) # Can be nil

      # Determine item_type (ensure it's an atom)
      item_type = case item do
        %MyApp.Forms.FormItem{type: type} -> type
        %{type: type} -> safe_to_atom(type) # Handle map with atom key
        %{"type" => type} -> safe_to_atom(type) # Corrected
        _ ->
          Logger.error("render_condition_value_input: Invalid item structure: #{inspect(item)}")
          :text_input # Fallback
      end

      # Prepare options (ensure list of maps with :label, :value)
      options = case item do
        %MyApp.Forms.FormItem{options: opts} -> format_options_for_component(opts)
        %{options: opts} -> format_options_for_component(opts)
        %{"options" => opts} -> format_options_for_component(opts) # Corrected
        _ -> []
      end

      # Prepare max_rating
      max_rating = case item do
        %MyApp.Forms.FormItem{max_rating: rating} -> rating || 5
        %{max_rating: rating} -> rating || 5
        %{"max_rating" => rating} when is_integer(rating) -> rating # Corrected
        %{"max_rating" => rating} when is_binary(rating) -> # Corrected
          case Integer.parse(rating) do
            {val, ""} -> val
            _ -> 5 # Default if parsing fails
          end
        _ -> 5 # Default
      end
    %>
    <div class="flex-1">
      <%= case item_type do %>
        <% item_type when item_type in [:radio, :dropdown] -> %>
          <select name="logic[condition_value]" class="block w-full px-3 py-2 bg-white border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm">
            <option value="">-- 请选择答案 --</option>
            <%= for option <- options do %>
              <%# Ensure value comparison is correct (both might be strings) %>
              <option value={option.value} selected={current_value == option.value}><%= option.label %></option>
            <% end %>
          </select>
        <% :rating -> %>
          <select name="logic[condition_value]" class="block w-full px-3 py-2 bg-white border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm">
            <option value="">-- 请选择分数 --</option>
            <%= for i <- 1..max_rating do %>
              <%# Ensure value comparison is correct (both strings) %>
              <option value={Integer.to_string(i)} selected={current_value == Integer.to_string(i)}><%= i %></option>
            <% end %>
          </select>
        <% :checkbox -> %>
          <%# Checkbox logic might need refinement - 'contains' operator is complex %>
          <select name="logic[condition_value]" class="block w-full px-3 py-2 bg-white border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm">
            <option value="">-- 请选择选项 --</option>
            <%= for option <- options do %>
              <%# Ensure value comparison is correct %>
              <option value={option.value} selected={current_value == option.value}><%= option.label %></option>
            <% end %>
          </select>
        <% _ -> %>
          <%# Default to text input for text_input, textarea, email, phone, date, time, number, region, etc. %>
          <input
            type="text"
            name="logic[condition_value]"
            value={current_value}
            placeholder="输入条件值..."
            class="block w-full px-3 py-2 bg-white border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm"
          />
      <% end %>
    </div>
    """
  end
end
