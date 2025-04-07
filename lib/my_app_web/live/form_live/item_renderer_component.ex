defmodule MyAppWeb.FormLive.ItemRendererComponent do
  use Phoenix.Component

  @doc """
  Renders a single form item based on its type and the display mode.

  Assigns:
    - item: The FormItem struct to render.
    - mode: The rendering mode (:display for actual form, :edit_preview for editor list).
            Defaults to :display.
  """
  def render_item(assigns) do
    ~H"""
    <%# Component to render a single form item based on mode %>
    <% item = @item %>
    <% mode = assigns[:mode] || :display # Default to display mode %>
    <% is_preview = (mode == :edit_preview) %>

    <div class={"form-item-display type-#{item.type} #{if is_preview, do: "p-4 bg-gray-50 rounded-lg border border-gray-200", else: ""}"}>
      <%# Display Label and Required indicator (common part) %>
      <div class="flex justify-between mb-3">
        <h3 class="font-medium text-gray-800">
          <%= item.label %>
          <%= if item.required do %>
            <span class="form-item-required text-red-500 ml-1">*</span>
            <%= if is_preview do %>(必填)<% end %>
          <% end %>
        </h3>
        <%= if is_preview do %>
          <span class="text-xs text-gray-500">
            <%= case item.type do %>
              <% :text_input -> %> 文本输入
              <% :textarea -> %> 文本区域
              <% :dropdown -> %> 下拉菜单
              <% :radio -> %> 单选
              <% :checkbox -> %> 复选框
              <% :rating -> %> 评分
              <% :number -> %> 数字输入
              <% :email -> %> 邮箱输入
              <% :phone -> %> 电话号码
              <% :date -> %> 日期选择
              <% :time -> %> 时间选择
              <% :region -> %> 地区选择
              <% :matrix -> %> 矩阵题
              <% :image_choice -> %> 图片选择
              <% :file_upload -> %> 文件上传
              <% other -> %> <%= other %>
            <% end %>
          </span>
        <% end %>
      </div>

      <%# Render the actual input based on type %>
      <div class={if is_preview, do: "mt-3", else: ""}>
        <%= case item.type do %>
          <% :text_input -> %>
            <input
              type="text"
              class="w-full px-3 py-2 border border-gray-300 rounded-md bg-white"
              placeholder={item.placeholder || ""}
              disabled={is_preview}
            />

          <% :textarea -> %>
            <textarea
              class="w-full px-3 py-2 border border-gray-300 rounded-md bg-white min-h-[80px]"
              placeholder={item.placeholder || ""}
              disabled={is_preview}
            ></textarea>

          <% :dropdown -> %>
            <select
              class="w-full px-3 py-2 border border-gray-300 rounded-md bg-white"
              disabled={is_preview}
            >
              <option value="" disabled selected>请选择...</option>
              <%= for option <- item.options || [] do %>
                <option value={option.value} disabled={is_preview}>
                  <%= if option.label && option.label != "" do %>
                    <%= option.label %> <%= if option.value && option.value != "" && option.label != option.value, do: "(#{option.value})" %>
                  <% else %>
                    选项 <%= option.value %>
                  <% end %>
                </option>
              <% end %>
            </select>
            <%= if is_preview && !Enum.empty?(item.options || []) do %>
              <div class="mt-2 pt-2 border-t text-xs text-gray-500">
                选项: <%= Enum.map(item.options, &("#{&1.label} (#{&1.value})")) |> Enum.join(", ") %>
              </div>
            <% end %>


          <% :checkbox -> %>
            <div class="space-y-2">
              <%= for option <- item.options || [] do %>
                <div class="form-item-option flex items-center">
                  <input
                    type="checkbox"
                    name={"preview_#{item.id}[]"}
                    id={"preview_#{item.id}_#{option.id}"}
                    value={option.value}
                    disabled={is_preview}
                    class="h-4 w-4 text-indigo-600 rounded border-gray-300 focus:ring-indigo-500"
                  />
                  <label for={"preview_#{item.id}_#{option.id}"} class="ml-2 text-gray-700">
                    <%= if option.label && option.label != "" do %>
                      <%= option.label %> <%= if option.value && option.value != "" && option.label != option.value, do: "(#{option.value})" %>
                    <% else %>
                      选项 <%= option.value %>
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
                <div class="form-item-option flex items-center">
                  <input
                    type="radio"
                    name={"preview_#{item.id}"}
                    id={"preview_#{item.id}_#{option.id}"}
                    value={option.value}
                    disabled={is_preview}
                    class="h-4 w-4 text-indigo-600 border-gray-300 focus:ring-indigo-500"
                  />
                  <label for={"preview_#{item.id}_#{option.id}"} class="ml-2 text-gray-700">
                    <%= if option.label && option.label != "" do %>
                      <%= option.label %> <%= if option.value && option.value != "" && option.label != option.value, do: "(#{option.value})" %>
                    <% else %>
                      选项 <%= option.value %>
                    <% end %>
                  </label>
                </div>
              <% end %>
              <%= if Enum.empty?(item.options || []) do %>
                 <p class="text-xs text-gray-400 italic">无可用选项</p>
              <% end %>
            </div>

          <% :rating -> %>
            <div class="rating-preview py-2 flex items-center space-x-1">
              <% max_rating = item.max_rating || 5 %>
              <%= for _i <- 1..max_rating do %>
                 <button type="button" disabled={is_preview} class={"text-2xl #{if is_preview, do: "text-gray-300", else: "text-yellow-400 hover:text-yellow-500 cursor-pointer"}"}>★</button>
              <% end %>
              <%= if is_preview do %> <span class="ml-2 text-sm text-gray-500">(<%= max_rating %>星评分)</span> <% end %>
            </div>

          <% :number -> %>
            <input
              type="number"
              min={item.min}
              max={item.max}
              step={item.step || "any"}
              class="w-full px-3 py-2 border border-gray-300 rounded-md bg-white"
              placeholder={item.placeholder || "请输入数字"}
              disabled={is_preview}
            />
             <%= if is_preview && (item.min != nil || item.max != nil) do %>
              <div class="mt-1 text-xs text-gray-500">
                范围: <%= item.min || "-∞" %> ~ <%= item.max || "+∞" %> <%= if item.step, do: "(步长: #{item.step})", else: "" %>
              </div>
            <% end %>

          <% :email -> %>
            <input
              type="email"
              class="w-full px-3 py-2 border border-gray-300 rounded-md bg-white"
              placeholder={item.placeholder || "example@example.com"}
              disabled={is_preview}
            />
             <%= if is_preview && item.show_format_hint do %>
              <div class="mt-1 text-xs text-gray-500">格式: example@domain.com</div>
            <% end %>

          <% :phone -> %>
            <input
              type="tel"
              class="w-full px-3 py-2 border border-gray-300 rounded-md bg-white"
              placeholder={item.placeholder || "13800138000"}
              disabled={is_preview}
            />
             <%= if is_preview && item.format_display do %>
              <div class="mt-1 text-xs text-gray-500">请输入11位手机号码</div>
            <% end %>

          <% :date -> %>
            <input
              type="date"
              min={item.min_date}
              max={item.max_date}
              class="w-full px-3 py-2 border border-gray-300 rounded-md bg-white"
              disabled={is_preview}
            />
             <%= if is_preview && (item.min_date || item.max_date) do %>
              <div class="mt-1 text-xs text-gray-500">
                可选日期范围: <%= item.min_date || "无限制" %> ~ <%= item.max_date || "无限制" %>
              </div>
            <% end %>

          <% :time -> %>
            <input
              type="time"
              min={item.min_time}
              max={item.max_time}
              step={item.step || "any"}
              class="w-full px-3 py-2 border border-gray-300 rounded-md bg-white"
              disabled={is_preview}
            />
             <%= if is_preview do %>
              <div class="mt-1 text-xs text-gray-500">
                <%= if item.min_time || item.max_time do %>
                  可选时间范围: <%= item.min_time || "无限制" %> ~ <%= item.max_time || "无限制" %>
                <% end %>
                <%= if item.time_format == "12h" do %>(12小时制)<% else %>(24小时制)<% end %>
              </div>
             <% end %>

          <%# TODO: Add rendering for :region, :matrix, :image_choice, :file_upload %>
          <% :region -> %>
             <%# Extracted from old commit - Region Preview %>
             <div class={"space-y-2 #{is_preview && 'opacity-60 pointer-events-none'}"}>
               <div class="flex gap-2">
                 <select class="flex-1 px-3 py-2 border border-gray-300 rounded-md bg-white" disabled>
                   <option><%= item.default_province || "省/直辖市" %></option>
                 </select>
                 <%= if item.region_level == nil || item.region_level >= 2 do %>
                   <select class="flex-1 px-3 py-2 border border-gray-300 rounded-md bg-white" disabled>
                     <option>市</option>
                   </select>
                 <% end %>
                 <%= if item.region_level == nil || item.region_level >= 3 do %>
                   <select class="flex-1 px-3 py-2 border border-gray-300 rounded-md bg-white" disabled>
                     <option>区/县</option>
                   </select>
                 <% end %>
               </div>
               <%= if is_preview do %>
                 <div class="mt-1 text-xs text-gray-500">地区级别: <%= item.region_level || 3 %></div>
               <% end %>
             </div>

          <% :matrix -> %>
            <%# Extracted and adapted from old commit - Matrix Preview %>
            <div class={"space-y-2 #{is_preview && 'opacity-60 pointer-events-none'}"}>
              <div class="overflow-x-auto">
                <table class="w-full border-collapse border border-gray-300">
                  <thead>
                    <tr>
                      <th class="border border-gray-300 p-2 bg-gray-50"></th>
                      <%= for column <- (item.matrix_columns || ["选项A", "选项B", "选项C"]) do %>
                        <th class="border border-gray-300 p-2 bg-gray-50 text-center"><%= column %></th>
                      <% end %>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for row <- (item.matrix_rows || ["问题1", "问题2", "问题3"]) do %>
                      <tr>
                        <td class="border border-gray-300 p-2 font-medium"><%= row %></td>
                        <%= for _column <- (item.matrix_columns || ["选项A", "选项B", "选项C"]) do %>
                          <td class="border border-gray-300 p-2 text-center">
                            <%= if item.matrix_type == :multiple do %>
                              <input type="checkbox" disabled class="h-4 w-4 text-indigo-600 focus:ring-indigo-500"/>
                            <% else %>
                              <input type="radio" disabled class="h-4 w-4 text-indigo-600 focus:ring-indigo-500"/>
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
                  矩阵类型: <%= if item.matrix_type == :multiple, do: "多选", else: "单选" %>
                </div>
              <% end %>
            </div>

          <% :image_choice -> %>
            <%# 图片选择控件预览 %>
             <div class={"space-y-2 #{is_preview && 'opacity-60 pointer-events-none'}"}>
               <div class="flex flex-wrap gap-4">
                 <%= if Enum.any?(item.options || []) do %>
                   <%= for option <- Enum.take(item.options || [], min(2, length(item.options || []))) do %>
                     <div class="w-40 border border-gray-300 rounded-md overflow-hidden bg-white">
                       <%= if item.image_caption_position == :top do %>
                         <div class="p-2 text-center text-sm"><%= option.label %></div>
                       <% end %>
                       <div class="h-32 bg-gray-100 flex items-center justify-center overflow-hidden">
                         <%= if option[:image_filename] || option["image_filename"] do %>
                           <img 
                             src={"/uploads/#{option[:image_filename] || option["image_filename"]}"} 
                             alt={option[:label] || option["label"]} 
                             class="h-full w-full object-contain"
                           />
                         <% else %>
                           <svg xmlns="http://www.w3.org/2000/svg" class="h-10 w-10 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                             <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                           </svg>
                         <% end %>
                       </div>
                       <%= if item.image_caption_position == :bottom || item.image_caption_position == nil do %>
                         <div class="p-2 text-center text-sm"><%= option.label %></div>
                       <% end %>
                       <div class="p-1 border-t border-gray-300 text-center">
                         <%= if item.selection_type == :multiple do %>
                           <input type="checkbox" disabled class="h-4 w-4 text-indigo-600"/>
                         <% else %>
                           <input type="radio" disabled class="h-4 w-4 text-indigo-600"/>
                         <% end %>
                       </div>
                     </div>
                   <% end %>
                   <%= if length(item.options || []) > 2 do %>
                     <div class="flex items-center justify-center h-32 text-gray-400">
                       还有<%= length(item.options) - 2 %>个选项...
                     </div>
                   <% end %>
                 <% else %>
                   <div class="w-40 border border-gray-300 rounded-md overflow-hidden bg-white">
                     <%= if item.image_caption_position == :top do %>
                       <div class="p-2 text-center text-sm">示例图片选项</div>
                     <% end %>
                     <div class="h-32 bg-gray-100 flex items-center justify-center">
                       <svg xmlns="http://www.w3.org/2000/svg" class="h-10 w-10 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                         <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                       </svg>
                     </div>
                     <%= if item.image_caption_position == :bottom || item.image_caption_position == nil do %>
                       <div class="p-2 text-center text-sm">示例图片选项</div>
                     <% end %>
                     <div class="p-1 border-t border-gray-300 text-center">
                       <%= if item.selection_type == :multiple do %>
                         <input type="checkbox" disabled class="h-4 w-4 text-indigo-600"/>
                       <% else %>
                         <input type="radio" disabled class="h-4 w-4 text-indigo-600"/>
                       <% end %>
                     </div>
                   </div>
                 <% end %>
               </div>
               <%= if is_preview do %>
                 <div class="mt-1 text-xs text-gray-500">
                   选择类型: <%= if item.selection_type == :multiple, do: "多选", else: "单选" %>,
                   标题位置: <%= case item.image_caption_position do %><% :top -> %>图片上方<% :bottom -> %>图片下方<% :none -> %>无标题<% _ -> %>图片下方<% end %>
                 </div>
               <% end %>
            </div>

          <% :file_upload -> %>
             <%# Extracted from old commit - File Upload Preview (Placeholder) %>
             <div class={"space-y-2 #{is_preview && 'opacity-60 pointer-events-none'}"}>
                <div class="border-2 border-dashed border-gray-300 rounded-md p-6 text-center">
                  <svg xmlns="http://www.w3.org/2000/svg" class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
                  </svg>
                  <div class="mt-2 text-sm text-gray-600">
                    点击或拖拽文件到此区域上传
                  </div>
                  <div class="mt-1 text-xs text-gray-500">
                    <%= if item.allowed_extensions && !Enum.empty?(item.allowed_extensions) do %>
                      支持格式: <%= Enum.join(item.allowed_extensions, ", ") %>
                    <% else %>
                      支持所有文件格式
                    <% end %>
                  </div>
                  <div class="mt-1 text-xs text-gray-500">
                    最大文件大小: <%= item.max_file_size || 5 %> MB
                  </div>
                  <div class="mt-1 text-xs text-gray-500">
                    <%= if item.multiple_files do %>
                      可上传多个文件<%= if item.max_files, do: " (最多 #{item.max_files} 个)" %>
                    <% else %>
                      只能上传单个文件
                    <% end %>
                  </div>
                  <button type="button" disabled class="mt-3 inline-flex items-center px-3 py-1.5 border border-transparent text-xs rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 disabled:opacity-50 cursor-not-allowed">
                    选择文件
                  </button>
                </div>
             </div>

          <% other -> %>
            <div class="text-center py-2 text-gray-400 bg-gray-100 rounded text-sm">
              不支持的控件类型预览: <%= other %>
            </div>
        <% end %>
      </div>
    </div>
    """
  end
end
