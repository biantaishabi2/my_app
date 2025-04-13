defmodule MyAppWeb.FormLive.ItemRendererComponent do
  use MyAppWeb, :html
  # alias MyApp.Upload
  require Logger # Make sure Logger is available

  @doc """
  Renders a single form item based on its type and the display mode.

  Assigns:
    - item: The FormItem struct to render.
    - mode: The rendering mode (:display for actual form, :edit_preview for editor list).
            Defaults to :display.
    - form_data: The form data map (only required for :display mode).
    - errors: The validation errors map (only required for :display mode).
  """
  def render_item(assigns) do
    # 设置默认值
    assigns = Map.put_new(assigns, :mode, :display)
    assigns = Map.put_new(assigns, :form_data, %{})
    assigns = Map.put_new(assigns, :errors, %{})

    ~H"""
    <% item = @item %>
    <% mode = @mode %>
    <% is_preview = mode == :edit_preview %>
    <% form_data = @form_data %>
    <% errors = @errors %>

    <div id={"item-renderer-#{item.id}"} class={"form-item-display type-#{item.type} #{if is_preview, do: "p-4 bg-gray-50 rounded-lg border border-gray-200", else: ""}"}>

      <div class="flex justify-between mb-3">
        <h3 class="font-medium text-gray-800">
          {item.label}
          <%= if item.required do %>
            <span class="form-item-required text-red-500 ml-1">*</span>
            <%= if is_preview do %>
              (必填)
            <% end %>
          <% end %>
        </h3>
        <%= if is_preview do %>
          <span class="text-xs text-gray-500">
            <%= case item.type do %>
              <% :text_input -> %>
                文本输入
              <% :textarea -> %>
                文本区域
              <% :dropdown -> %>
                下拉菜单
              <% :radio -> %>
                单选
              <% :checkbox -> %>
                复选框
              <% :rating -> %>
                评分
              <% :number -> %>
                数字输入
              <% :email -> %>
                邮箱输入
              <% :phone -> %>
                电话号码
              <% :date -> %>
                日期选择
              <% :time -> %>
                时间选择
              <% :region -> %>
                地区选择
              <% :matrix -> %>
                矩阵题
              <% :image_choice -> %>
                图片选择
              <% :file_upload -> %>
                文件上传
              <% other -> %>
                {other}
            <% end %>
          </span>
        <% end %>
      </div>

      <div class={if is_preview, do: "mt-3", else: ""}>
        <%= case item.type do %>
          <% :text_input -> %>
            <input
              type="text"
              id={if !is_preview, do: item.id, else: nil}
              name={if !is_preview, do: "form_data[#{item.id}]", else: nil}
              value={if !is_preview, do: Map.get(form_data, item.id, ""), else: ""}
              class={"w-full px-3 py-2 border border-gray-300 rounded-md bg-white #{if Map.has_key?(errors, item.id), do: "border-red-500"}"}
              placeholder={item.placeholder || ""}
              disabled={is_preview}
            />
          <% :textarea -> %>
            <textarea
              id={if !is_preview, do: item.id, else: nil}
              name={if !is_preview, do: "form_data[#{item.id}]", else: nil}
              class={"w-full px-3 py-2 border border-gray-300 rounded-md bg-white min-h-[80px] #{if Map.has_key?(errors, item.id), do: "border-red-500"}"}
              placeholder={item.placeholder || ""}
              disabled={is_preview}
            ><%= if !is_preview, do: Map.get(form_data, item.id, "") %></textarea>
          <% :dropdown -> %>
            <select
              id={if !is_preview, do: item.id, else: nil}
              name={if !is_preview, do: "form_data[#{item.id}]", else: nil}
              class={"w-full px-3 py-2 border border-gray-300 rounded-md bg-white #{if Map.has_key?(errors, item.id), do: "border-red-500"}"}
              disabled={is_preview}
            >
              <option value="" disabled selected={is_preview || !Map.get(form_data, item.id)}>
                请选择...
              </option>
              <%= for option <- item.options || [] do %>
                <option
                  value={option.value}
                  disabled={is_preview}
                  selected={!is_preview && Map.get(form_data, item.id) == option.value}
                >
                  <%= if option.label && option.label != "" do %>
                    {option.label} {if option.value && option.value != "" &&
                                         option.label != option.value && is_preview,
                                       do: "(#{option.value})"}
                  <% else %>
                    选项 {option.value}
                  <% end %>
                </option>
              <% end %>
            </select>
            <%= if is_preview && !Enum.empty?(item.options || []) do %>
              <div class="mt-2 pt-2 border-t text-xs text-gray-500">
                选项: {Enum.map(item.options, &"#{&1.label} (#{&1.value})") |> Enum.join(", ")}
              </div>
            <% end %>
          <% :checkbox -> %>
            <div class="space-y-2">
              <%= for option <- item.options || [] do %>
                <% selected_values = if !is_preview, do: Map.get(form_data, item.id, []), else: []
                selected_values = if is_list(selected_values), do: selected_values, else: []
                checked = if !is_preview, do: option.value in selected_values, else: false %>
                <div class="form-item-option flex items-center">
                  <input
                    type="checkbox"
                    name={if !is_preview, do: "form_data[#{item.id}][]", else: "preview_#{item.id}[]"}
                    id={
                      if !is_preview,
                        do: "#{item.id}_#{option.value}",
                        else: "preview_#{item.id}_#{option.id}"
                    }
                    value={option.value}
                    checked={checked}
                    disabled={is_preview}
                    class="h-4 w-4 text-indigo-600 rounded border-gray-300 focus:ring-indigo-500"
                  />
                  <label
                    for={
                      if !is_preview,
                        do: "#{item.id}_#{option.value}",
                        else: "preview_#{item.id}_#{option.id}"
                    }
                    class="ml-2 text-gray-700"
                  >
                    <%= if option.label && option.label != "" do %>
                      {option.label} {if option.value && option.value != "" &&
                                           option.label != option.value && is_preview,
                                         do: "(#{option.value})"}
                    <% else %>
                      选项 {option.value}
                    <% end %>
                  </label>
                </div>
              <% end %>
              <%= if Enum.empty?(item.options || []) do %>
                <p class="text-xs text-gray-400 italic">无可用选项</p>
              <% end %>
            </div>
          <% :radio -> %>
            <div class="space-y-2">
              <%= for option <- item.options || [] do %>
                <%
                  # --- Add Detailed Logging ---
                  Logger.debug(
                    "[ItemRenderer :radio] Rendering Option for Item ID: #{inspect(item.id)}, Label: #{item.label}, Option Value: #{inspect(option.value)}, Current FormData: #{inspect(form_data)}"
                  )

                  current_value_for_item = Map.get(form_data, to_string(item.id))
                  # Compare as strings
                  is_checked_result =
                    !is_preview &&
                      !is_nil(current_value_for_item) && # Ensure value exists before comparing
                      to_string(current_value_for_item) == to_string(option.value)

                  Logger.debug(
                    "[ItemRenderer :radio] Retrieved Value: #{inspect(current_value_for_item)}, Comparing with Option Value: #{inspect(to_string(option.value))}, Calculated Checked: #{inspect(is_checked_result)}"
                  )
                  # --- End Logging ---
                %>
                <div class="form-item-option flex items-center">
                  <input
                    type="radio"
                    name={if !is_preview, do: "form_data[#{item.id}]", else: "preview_#{item.id}"}
                    id={
                      if !is_preview,
                        do: "#{item.id}_#{option.value}",
                        else: "preview_#{item.id}_#{option.id}"
                    }
                    value={option.value}
                    checked={is_checked_result}
                    disabled={is_preview}
                    class="h-4 w-4 text-indigo-600 border-gray-300 focus:ring-indigo-500"
                  />
                  <label
                    for={
                      if !is_preview,
                        do: "#{item.id}_#{option.value}",
                        else: "preview_#{item.id}_#{option.id}"
                    }
                    class="ml-2 text-gray-700"
                  >
                    <%= if option.label && option.label != "" do %>
                      {option.label} {if option.value && option.value != "" &&
                                           option.label != option.value && is_preview,
                                         do: "(#{option.value})"}
                    <% else %>
                      选项 {option.value}
                    <% end %>
                  </label>
                </div>
              <% end %>
              <%= if Enum.empty?(item.options || []) do %>
                <p class="text-xs text-gray-400 italic">无可用选项</p>
              <% end %>
            </div>
          <% :rating -> %>
            <div class="form-rating flex items-center space-x-1">
              <% max_rating = item.max_rating || 5

              selected_rating =
                if !is_preview,
                  do: Map.get(form_data, item.id, "0") |> to_string() |> String.to_integer(),
                  else: 0 %>
              <%= for i <- 1..max_rating do %>
                <div class="rating-option mr-2">
                  <input
                    type="radio"
                    id={if !is_preview, do: "#{item.id}_#{i}", else: nil}
                    name={if !is_preview, do: "form_data[#{item.id}]", else: nil}
                    value={i}
                    checked={!is_preview && selected_rating == i}
                    class="hidden"
                    disabled={is_preview}
                  />
                  <label
                    for={if !is_preview, do: "#{item.id}_#{i}", else: nil}
                    class={"rating-star text-2xl #{if !is_preview, do: "cursor-pointer", else: "cursor-default"} #{if i <= selected_rating || (!is_preview && i == 1), do: "text-yellow-400", else: "text-gray-300"}"}
                  >
                    ★
                  </label>
                </div>
              <% end %>
              <%= if is_preview do %>
                <span class="ml-2 text-sm text-gray-500">({max_rating}星评分)</span>
              <% end %>
            </div>
          <% :number -> %>
            <input
              type="number"
              id={if !is_preview, do: item.id, else: nil}
              name={if !is_preview, do: "form_data[#{item.id}]", else: nil}
              value={if !is_preview, do: Map.get(form_data, item.id, ""), else: ""}
              min={item.min}
              max={item.max}
              step={item.step || "any"}
              class={"w-full px-3 py-2 border border-gray-300 rounded-md bg-white #{if Map.has_key?(errors, item.id), do: "border-red-500"}"}
              placeholder={item.placeholder || "请输入数字"}
              disabled={is_preview}
            />
            <%= if is_preview && (item.min != nil || item.max != nil) do %>
              <div class="mt-1 text-xs text-gray-500">
                范围: {item.min || "-∞"} ~ {item.max || "+∞"} {if item.step,
                  do: "(步长: #{item.step})",
                  else: ""}
              </div>
            <% end %>
          <% :email -> %>
            <input
              type="email"
              id={if !is_preview, do: item.id, else: nil}
              name={if !is_preview, do: "form_data[#{item.id}]", else: nil}
              value={if !is_preview, do: Map.get(form_data, item.id, ""), else: ""}
              class={"w-full px-3 py-2 border border-gray-300 rounded-md bg-white #{if Map.has_key?(errors, item.id), do: "border-red-500"}"}
              placeholder={item.placeholder || "example@example.com"}
              disabled={is_preview}
            />
            <%= if is_preview && item.show_format_hint do %>
              <div class="mt-1 text-xs text-gray-500">格式: example@domain.com</div>
            <% end %>
          <% :phone -> %>
            <input
              type="tel"
              id={if !is_preview, do: item.id, else: nil}
              name={if !is_preview, do: "form_data[#{item.id}]", else: nil}
              value={if !is_preview, do: Map.get(form_data, item.id, ""), else: ""}
              class={"w-full px-3 py-2 border border-gray-300 rounded-md bg-white #{if Map.has_key?(errors, item.id), do: "border-red-500"}"}
              placeholder={item.placeholder || "13800138000"}
              disabled={is_preview}
            />
            <%= if is_preview && item.format_display do %>
              <div class="mt-1 text-xs text-gray-500">请输入11位手机号码</div>
            <% end %>
          <% :date -> %>
            <input
              type="date"
              id={if !is_preview, do: item.id, else: nil}
              name={if !is_preview, do: "form_data[#{item.id}]", else: nil}
              value={if !is_preview, do: Map.get(form_data, item.id, ""), else: ""}
              min={item.min_date}
              max={item.max_date}
              class={"w-full px-3 py-2 border border-gray-300 rounded-md bg-white #{if Map.has_key?(errors, item.id), do: "border-red-500"}"}
              disabled={is_preview}
            />
            <%= if is_preview && (item.min_date || item.max_date) do %>
              <div class="mt-1 text-xs text-gray-500">
                可选日期范围: {item.min_date || "无限制"} ~ {item.max_date || "无限制"}
              </div>
            <% end %>
          <% :time -> %>
            <input
              type="time"
              id={if !is_preview, do: item.id, else: nil}
              name={if !is_preview, do: "form_data[#{item.id}]", else: nil}
              value={if !is_preview, do: Map.get(form_data, item.id, ""), else: ""}
              min={item.min_time}
              max={item.max_time}
              step={item.step || "any"}
              class={"w-full px-3 py-2 border border-gray-300 rounded-md bg-white #{if Map.has_key?(errors, item.id), do: "border-red-500"}"}
              disabled={is_preview}
            />
            <%= if is_preview do %>
              <div class="mt-1 text-xs text-gray-500">
                <%= if item.min_time || item.max_time do %>
                  可选时间范围: {item.min_time || "无限制"} ~ {item.max_time || "无限制"}
                <% end %>
                <%= if item.time_format == "12h" do %>
                  (12小时制)
                <% else %>
                  (24小时制)
                <% end %>
              </div>
            <% end %>
          <% :region -> %>
            <%= if is_preview do %>

              <div class="space-y-2 opacity-70 pointer-events-none">
                <div class="flex gap-2">
                  <select class="flex-1 px-3 py-2 border border-gray-300 rounded-md bg-white" disabled>
                    <option>{item.default_province || "省/直辖市"}</option>
                    <%= for province <- MyApp.Regions.get_provinces() |> Enum.take(5) do %>
                      <option>{province.name}</option>
                    <% end %>
                  </select>
                  <%= if item.region_level == nil || item.region_level >= 2 do %>
                    <select
                      class="flex-1 px-3 py-2 border border-gray-300 rounded-md bg-white"
                      disabled
                    >
                      <option>市</option>
                      <option>北京市</option>
                      <option>上海市</option>
                      <option>广州市</option>
                    </select>
                  <% end %>
                  <%= if item.region_level == nil || item.region_level >= 3 do %>
                    <select
                      class="flex-1 px-3 py-2 border border-gray-300 rounded-md bg-white"
                      disabled
                    >
                      <option>区/县</option>
                      <option>海淀区</option>
                      <option>朝阳区</option>
                    </select>
                  <% end %>
                </div>
                <div class="mt-1 text-xs text-gray-500">地区级别: {item.region_level || 3} (预览模式)</div>
              </div>
            <% else %>

              <div
                class="region-selector grid grid-cols-2 md:grid-cols-3 gap-2"
                id={"region-selector-#{item.id}"}
                phx-hook="RegionSelect"
                data-field-id={item.id}
              >
                <select
                  id={"#{item.id}_province"}
                  name={"form_data[#{item.id}_province]"}
                  class="form-control p-2 border rounded"
                  phx-change="province_changed"
                  phx-value-field-id={item.id}
                  data-field-id={item.id}
                >
                  <option value="">请选择省份</option>
                  <!-- 省份选项会由JS钩子加载 -->
                </select>

                <select
                  id={"#{item.id}_city"}
                  name={"form_data[#{item.id}_city]"}
                  class="form-control p-2 border rounded"
                  phx-change="city_changed"
                  phx-value-field-id={item.id}
                  data-field-id={item.id}
                  disabled={!Map.get(form_data, "#{item.id}_province")}
                >
                  <option value="">请选择城市</option>
                  <!-- 城市选项会由JS钩子加载 -->
                </select>

                <%= if item.region_level == nil || item.region_level >= 3 do %>
                  <select
                    id={"#{item.id}_district"}
                    name={"form_data[#{item.id}_district]"}
                    class="form-control p-2 border rounded"
                    phx-change="district_changed"
                    phx-value-field-id={item.id}
                    data-field-id={item.id}
                    disabled={!Map.get(form_data, "#{item.id}_city")}
                  >
                    <option value="">请选择区县</option>
                    <!-- 区县选项会由JS钩子加载 -->
                  </select>
                <% end %>

    <!-- 隐藏字段用于保存完整地址值 -->
                <input
                  type="hidden"
                  id={item.id}
                  name={"form_data[#{item.id}]"}
                  value={Map.get(form_data, item.id, "")}
                />
              </div>
            <% end %>
          <% :matrix -> %>
            <div class={"space-y-2 #{is_preview && "opacity-60 pointer-events-none"}"}>
              <div class="overflow-x-auto">
                <table class="w-full border-collapse border border-gray-300">
                  <thead>
                    <tr>
                      <th class="border border-gray-300 p-2 bg-gray-50"></th>
                      <%= for column <- (item.matrix_columns || ["选项A", "选项B", "选项C"]) do %>
                        <th class="border border-gray-300 p-2 bg-gray-50 text-center">{column}</th>
                      <% end %>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for {row, row_index} <- Enum.with_index(item.matrix_rows || ["问题1", "问题2", "问题3"]) do %>
                      <tr>
                        <td class="border border-gray-300 p-2 font-medium">{row}</td>
                        <%= for {column, col_index} <- Enum.with_index(item.matrix_columns || ["选项A", "选项B", "选项C"]) do %>
                          <% input_id = "#{item.id}_#{row_index}_#{col_index}"

                          input_name =
                            if item.matrix_type == :multiple,
                              do: "form_data[#{item.id}][#{row_index}][]",
                              else: "form_data[#{item.id}][#{row_index}]"

                          input_value = column

                          # 在实际表单中获取已选值
                          # 先安全地获取item.id对应的表单数据，确保是map
                          item_data =
                            if !is_preview && is_map(form_data),
                              do: Map.get(form_data, item.id),
                              else: nil

                          # 再从该数据中安全地获取行索引对应的值
                          row_values =
                            cond do
                              is_map(item_data) -> Map.get(item_data, to_string(row_index), [])
                              true -> []
                            end

                          row_values = if is_list(row_values), do: row_values, else: [row_values]
                          checked = column in row_values %>
                          <td class="border border-gray-300 p-2 text-center">
                            <%= if item.matrix_type == :multiple do %>
                              <input
                                type="checkbox"
                                id={if !is_preview, do: input_id, else: nil}
                                name={if !is_preview, do: input_name, else: nil}
                                value={input_value}
                                checked={!is_preview && checked}
                                disabled={is_preview}
                                class="h-4 w-4 text-indigo-600 focus:ring-indigo-500"
                              />
                            <% else %>
                              <input
                                type="radio"
                                id={if !is_preview, do: input_id, else: nil}
                                name={if !is_preview, do: input_name, else: nil}
                                value={input_value}
                                checked={!is_preview && checked}
                                disabled={is_preview}
                                class="h-4 w-4 text-indigo-600 focus:ring-indigo-500"
                              />
                            <% end %>
                          </td>
                        <% end %>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
              <%= if is_preview do %>
                <div class="mt-1 text-xs text-gray-500">
                  矩阵类型: {if item.matrix_type == :multiple, do: "多选", else: "单选"}
                </div>
              <% end %>
            </div>
          <% :image_choice -> %>
            <div class={"space-y-2 #{is_preview && "opacity-60 pointer-events-none"}"}>
              <div class="flex flex-wrap gap-4">
                <%= if Enum.any?(item.options || []) do %>
                  <% # 在预览模式下最多显示2个，实际表单显示所有
                  display_options =
                    if is_preview,
                      do: Enum.take(item.options || [], min(2, length(item.options || []))),
                      else: item.options || []

                  # 获取选择值（仅实际表单）
                  selected_values = if !is_preview, do: Map.get(form_data, item.id, []), else: []

                  selected_values =
                    if is_list(selected_values), do: selected_values, else: [selected_values] %>
                  <%= for option <- display_options do %>
                    <% checked = if !is_preview, do: option.value in selected_values, else: false %>
                    <div class="w-40 border border-gray-300 rounded-md overflow-hidden bg-white">
                      <%= if item.image_caption_position == :top do %>
                        <div class="p-2 text-center text-sm">{option.label}</div>
                      <% end %>

                      <div class="h-32 bg-gray-100 flex items-center justify-center overflow-hidden">
                        <%= if option.image_filename do %>
                          <img
                            src={"/uploads/#{option.image_filename}"}
                            alt={option.label}
                            class="h-full w-full object-contain"
                          />
                        <% else %>
                          <svg
                            xmlns="http://www.w3.org/2000/svg"
                            class="h-10 w-10 text-gray-400"
                            fill="none"
                            viewBox="0 0 24 24"
                            stroke="currentColor"
                          >
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              stroke-width="2"
                              d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
                            />
                          </svg>
                        <% end %>
                      </div>
                      <%= if item.image_caption_position == :bottom || item.image_caption_position == nil do %>
                        <div class="p-2 text-center text-sm">{option.label}</div>
                      <% end %>
                      <div class="p-1 border-t border-gray-300 text-center">
                        <%= if item.selection_type == :multiple do %>
                          <input
                            type="checkbox"
                            id={if !is_preview, do: "#{item.id}_#{option.value}", else: nil}
                            name={if !is_preview, do: "form_data[#{item.id}][]", else: nil}
                            value={option.value}
                            checked={checked}
                            disabled={is_preview}
                            class="h-4 w-4 text-indigo-600"
                          />
                        <% else %>
                          <input
                            type="radio"
                            id={if !is_preview, do: "#{item.id}_#{option.value}", else: nil}
                            name={if !is_preview, do: "form_data[#{item.id}]", else: nil}
                            value={option.value}
                            checked={checked}
                            disabled={is_preview}
                            class="h-4 w-4 text-indigo-600"
                          />
                        <% end %>
                      </div>
                    </div>
                  <% end %>
                  <%= if is_preview && length(item.options || []) > 2 do %>
                    <div class="flex items-center justify-center h-32 text-gray-400">
                      还有{length(item.options) - 2}个选项...
                    </div>
                  <% end %>
                <% else %>
                  <div class="w-40 border border-gray-300 rounded-md overflow-hidden bg-white">
                    <%= if item.image_caption_position == :top do %>
                      <div class="p-2 text-center text-sm">示例图片选项</div>
                    <% end %>

                    <div class="h-32 bg-gray-100 flex items-center justify-center overflow-hidden">
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        class="h-10 w-10 text-gray-400"
                        fill="none"
                        viewBox="0 0 24 24"
                        stroke="currentColor"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
                        />
                      </svg>
                    </div>
                    <%= if item.image_caption_position == :bottom || item.image_caption_position == nil do %>
                      <div class="p-2 text-center text-sm">示例图片选项</div>
                    <% end %>
                    <div class="p-1 border-t border-gray-300 text-center">
                      <%= if item.selection_type == :multiple do %>
                        <input type="checkbox" disabled class="h-4 w-4 text-indigo-600" />
                      <% else %>
                        <input type="radio" disabled class="h-4 w-4 text-indigo-600" />
                      <% end %>
                    </div>
                  </div>
                <% end %>
              </div>
              <%= if is_preview do %>
                <div class="mt-1 text-xs text-gray-500">
                  选择类型: {if item.selection_type == :multiple, do: "多选", else: "单选"},
                  标题位置:
                  <%= case item.image_caption_position do %>
                    <% :top -> %>
                      图片上方
                    <% :bottom -> %>
                      图片下方
                    <% :none -> %>
                      无标题
                    <% _ -> %>
                      图片下方
                  <% end %>
                </div>
              <% end %>
            </div>
          <% :file_upload -> %>
            <%= if is_preview do %>

              <div class="space-y-2 opacity-60 pointer-events-none">
                <div class="border-2 border-dashed border-gray-300 rounded-md p-6 text-center">
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="mx-auto h-12 w-12 text-gray-400"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"
                    />
                  </svg>
                  <div class="mt-2 text-sm text-gray-600">
                    点击或拖拽文件到此区域上传
                  </div>
                  <div class="mt-1 text-xs text-gray-500">
                    <%= if item.allowed_extensions && !Enum.empty?(item.allowed_extensions) do %>
                      支持格式: {Enum.join(item.allowed_extensions, ", ")}
                    <% else %>
                      支持所有文件格式
                    <% end %>
                  </div>
                  <div class="mt-1 text-xs text-gray-500">
                    最大文件大小: {item.max_file_size || 5} MB
                  </div>
                  <div class="mt-1 text-xs text-gray-500">
                    <%= if item.multiple_files do %>
                      可上传多个文件{if item.max_files, do: " (最多 #{item.max_files} 个)"}
                    <% else %>
                      只能上传单个文件
                    <% end %>
                  </div>
                  <button
                    type="button"
                    disabled
                    class="mt-3 inline-flex items-center px-3 py-1.5 border border-transparent text-xs rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 disabled:opacity-50 cursor-not-allowed"
                  >
                    选择文件
                  </button>
                </div>
              </div>
            <% else %>

              <div
                class="border-2 border-dashed border-gray-300 rounded-md p-6"
                id={"dropzone-#{item.id}"}
                phx-hook="FileUploadDropzone"
              >
                <div class="text-center">
                  <p class="text-gray-600 mb-4">
                    <%= if item.allowed_extensions && length(item.allowed_extensions) > 0 do %>
                      允许的文件类型: {Enum.join(item.allowed_extensions, ", ")}
                    <% else %>
                      允许上传任何类型的文件
                    <% end %>
                  </p>

                  <p class="text-gray-600 mb-4">
                    <%= if item.multiple_files do %>
                      最多可上传 {item.max_files || 5} 个文件
                    <% else %>
                      只能上传单个文件
                    <% end %>

                    <%= if item.max_file_size do %>
                      (每个文件最大 {item.max_file_size}MB)
                    <% end %>
                  </p>
                </div>

                <div class="flex justify-center mt-4">
                  <a
                    href="/uploads"
                    class="file-upload-button px-4 py-2 bg-indigo-600 text-white rounded hover:bg-indigo-700 inline-block"
                    id={"file-trigger-#{item.id}"}
                    phx-hook="FileInputTrigger"
                    data-file-input-id="file-upload-input-#{item.id}"
                  >
                    <%= if is_map(form_data) && Map.has_key?(form_data, item.id) && is_list(Map.get(form_data, item.id)) && length(Map.get(form_data, item.id)) > 0 do %>
                      管理已上传文件
                    <% else %>
                      选择并上传文件
                    <% end %>
                  </a>
                  <input
                    type="file"
                    id={"file-upload-input-#{item.id}"}
                    class="hidden"
                    multiple={item.multiple_files}
                  />
                </div>

                <%= if is_map(form_data) && Map.has_key?(form_data, item.id) && is_list(Map.get(form_data, item.id)) && length(Map.get(form_data, item.id)) > 0 do %>
                  <div class="mt-4 border-t pt-4">
                    <h4 class="font-medium text-sm mb-2">已上传的文件:</h4>
                    <ul class="text-sm">
                      <%= for {file, _index} <- Enum.with_index(Map.get(form_data, item.id, [])) do %>
                        <li class="flex items-center gap-2 mb-2 text-gray-800">
                          <span class="text-sm truncate flex-1">
                            {file.original_filename}
                          </span>
                          <a
                            href={file.path}
                            target="_blank"
                            class="text-blue-600 hover:underline text-xs"
                          >
                            查看
                          </a>
                        </li>
                      <% end %>
                    </ul>
                  </div>
                <% end %>
              </div>
            <% end %>
          <% other -> %>
            <div class="text-center py-2 text-gray-400 bg-gray-100 rounded text-sm">
              不支持的控件类型: {other}
            </div>
        <% end %>
      </div>

      <%= if !is_preview && Map.has_key?(errors, item.id) do %>
        <div class="error-message text-red-500 text-sm mt-1">
          {errors[item.id]}
        </div>
      <% end %>
    </div>
    """
  end
end
