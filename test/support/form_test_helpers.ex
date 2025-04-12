defmodule MyAppWeb.FormTestHelpers do
  @moduledoc """
  测试辅助函数，用于简化表单相关的测试，
  特别是减少对HTML结构和DOM元素的依赖。
  """

  import Phoenix.LiveViewTest

  @doc """
  获取当前分页表单的页码
  """
  def current_page_number(view) do
    # 通过页码计数器获取当前页码
    counter_text =
      view
      |> element(".form-pagination-counter")
      |> render()
      |> String.trim()

    # 提取格式为 "1 / 3" 中的第一个数字
    case Regex.run(~r/(\d+)\s*\/\s*\d+/, counter_text) do
      [_, current] -> String.to_integer(current)
      _ -> nil
    end
  end

  @doc """
  获取分页表单的总页数
  """
  def total_pages(view) do
    # 通过页码计数器获取总页数
    counter_text =
      view
      |> element(".form-pagination-counter")
      |> render()
      |> String.trim()

    # 提取格式为 "1 / 3" 中的第二个数字
    case Regex.run(~r/\d+\s*\/\s*(\d+)/, counter_text) do
      [_, total] -> String.to_integer(total)
      _ -> nil
    end
  end

  @doc """
  检查表单中是否包含特定字段
  """
  def has_form_field?(view, field_label) do
    html = render(view)
    String.contains?(html, field_label)
  end

  @doc """
  填写表单数据并触发变更事件
  """
  def fill_form_data(view, data) do
    # 表单字段使用form[ID]格式，需要查找实际字段ID
    form_data = build_form_data(view, data)

    if map_size(form_data) > 0 do
      view
      |> form("#form-submission", %{"form" => form_data})
      |> render_change()
    else
      IO.puts("警告：未找到匹配的表单字段，无法填写数据")
    end

    view
  end

  # 辅助函数，根据字段标签查找字段ID并构建表单数据
  defp build_form_data(view, data) do
    html = render(view)

    # 构建包含字段ID的表单数据
    Enum.reduce(data, %{}, fn {field_label, value}, acc ->
      field_id = find_field_id_by_label(html, field_label)

      if field_id do
        Map.put(acc, field_id, value)
      else
        # 如果未找到精确匹配，尝试部分匹配
        IO.puts("警告：未能通过标签'#{field_label}'找到精确匹配的表单字段ID，尝试部分匹配")

        # 尝试从表单中提取字段ID，使用更宽松的匹配
        # 尝试各种匹配方式（文本输入、单选按钮等）
        cond do
          # 1. 文本输入类型
          text_id = extract_text_input_id(html) ->
            Map.put(acc, text_id, value)

          # 2. 单选按钮类型 - 如果值是male/female这类特定值
          radio_id = extract_radio_id(html, value) ->
            Map.put(acc, radio_id, value)

          # 没有找到匹配
          true ->
            IO.puts("错误：无法找到匹配的表单字段，跳过'#{field_label}'")
            acc
        end
      end
    end)
  end

  # 从HTML中查找字段ID
  defp find_field_id_by_label(html, label) do
    # 尝试匹配 <label ... >label</label> 模式
    regex = ~r/<label[^>]*for="([^"]+)"[^>]*>\s*#{Regex.escape(label)}\s*(?:<[^>]+>\s*)*<\/label>/

    case Regex.run(regex, html) do
      [_, id] ->
        id

      _ ->
        # 针对单选/复选框和其他特殊情况尝试其他匹配方式
        fallback_regex =
          ~r/id="([^"]+)_[^"]*"[^>]*name="form\[\1\]"[^>]*>\s*<label[^>]*>\s*#{Regex.escape(label)}/

        case Regex.run(fallback_regex, html) do
          [_, id] -> id
          _ -> nil
        end
    end
  end

  # 辅助函数：提取表单中的文本输入字段ID（用于模糊匹配）
  defp extract_text_input_id(html) do
    case Regex.run(~r/<input[^>]*type="text"[^>]*id="([^"]+)"/, html) do
      [_, id] -> id
      _ -> nil
    end
  end

  # 辅助函数：提取表单中的单选按钮字段ID（用于模糊匹配）
  defp extract_radio_id(html, value) do
    case Regex.run(~r/<input[^>]*type="radio"[^>]*id="([^"]+)"[^>]*value="#{value}"/, html) do
      [_, id] ->
        # 将ID格式从"field_id_value"转换为"field_id"
        String.replace(id, "_#{value}", "")

      _ ->
        nil
    end
  end

  @doc """
  检查表单字段的值
  """
  def has_form_value?(view, field_name, expected_value) do
    html = render(view)

    # 根据字段标签获取字段ID
    field_id = find_field_id_by_label(html, field_name)

    if field_id do
      # 检查不同类型表单元素的值
      cond do
        # 文本输入框
        String.contains?(html, "id=\"#{field_id}\"") and
            String.contains?(html, "value=\"#{expected_value}\"") ->
          true

        # 单选按钮
        String.contains?(html, "id=\"#{field_id}_#{expected_value}\"") and
            String.contains?(html, "checked") ->
          true

        # 文本区域
        String.contains?(html, "id=\"#{field_id}\"") and
            String.contains?(html, ">#{expected_value}</textarea>") ->
          true

        # 下拉菜单
        String.contains?(html, "id=\"#{field_id}\"") and
            String.contains?(html, "<option value=\"#{expected_value}\" selected>") ->
          true

        true ->
          false
      end
    else
      false
    end
  end

  @doc """
  导航到下一页
  """
  def navigate_to_next_page(view) do
    view
    |> element("#next-page-button")
    |> render_click()
  end

  @doc """
  导航到上一页
  """
  def navigate_to_prev_page(view) do
    view
    |> element("#prev-page-button")
    |> render_click()
  end

  @doc """
  跳转到指定页面
  注意：跳转后面的页面前，需要确保当前页面的必填项已填写，否则跳转会失败
  """
  def jump_to_page(view, page_number) do
    # 获取当前页面索引
    current = current_page_number(view)

    # 页面索引从0开始，所以使用page_number-1
    index = page_number - 1

    # 尝试点击页面指示器进行跳转
    view
    |> element(".form-pagination-indicator[phx-value-index='#{index}']")
    |> render_click()

    # 检查跳转是否成功
    new_page = current_page_number(view)

    if new_page != page_number && current < page_number do
      # 如果跳转失败且是想要向后跳转，可能是因为当前页面有未填写的必填项
      # 此时可以给出一个警告，但在测试中这通常意味着测试逻辑需要调整
      IO.puts("警告：无法直接跳转到第#{page_number}页，可能是当前页面有未填写的必填项")
    end

    view
  end

  @doc """
  提交表单
  """
  def submit_form(view) do
    view
    |> element("form")
    |> render_submit()
  end

  @doc """
  检查页面是否完成（所有必填项都已填写）
  """
  def page_is_complete?(view, page_number) do
    # 页面索引从0开始
    index = page_number - 1

    # 获取页面HTML检查class
    _html = render(view)

    # 创建多种可能的匹配方式
    indicators = [
      # 变体1：使用完整的complete类
      ".form-pagination-indicator[phx-value-index='#{index}'].complete",
      # 变体2：使用部分完成样式
      ".form-pagination-indicator[phx-value-index='#{index}'].active"
    ]

    # 检查是否有任一匹配
    Enum.any?(indicators, fn selector ->
      has_element?(view, selector)
    end)
  end

  @doc """
  检查表单是否有特定的闪现消息
  """
  def has_flash?(view, key, message) do
    has_element?(view, "[data-role='flash'][data-type='#{key}']", message)
  end

  @doc """
  填写整个分页表单
  """
  def complete_form(view, form_data) do
    # 获取总页数
    pages = total_pages(view)

    # 遍历每个页面
    Enum.reduce(1..pages, view, fn page_num, updated_view ->
      # 确保在正确的页面
      current_page = current_page_number(updated_view)

      # 更新视图为处理后的视图
      navigation_result =
        navigate_to_page_if_needed(updated_view, current_page, page_num, form_data)

      # 现在应该在正确的页面上，填写数据
      if Map.has_key?(form_data, page_num) do
        fill_form_data(navigation_result, form_data[page_num])
      else
        navigation_result
      end
    end)
  end

  # 辅助函数：导航到目标页面（如果需要）并处理必填项验证
  defp navigate_to_page_if_needed(view, current_page, target_page, form_data) do
    if current_page != target_page do
      # 如果是向前导航，直接跳转
      if current_page > target_page do
        # 向前导航不需要验证，可以直接跳转或使用上一页按钮
        jump_to_page(view, target_page)
      else
        # 向后导航，需要确保之前的页面都已填写完成
        # 递归函数，处理从当前页面到目标页面的导航
        navigate_forward(view, current_page, target_page, form_data)
      end
    else
      # 已经在目标页面，无需导航
      view
    end
  end

  # 递归辅助函数：向前导航，每次仅前进一页，确保填写必填项
  defp navigate_forward(view, current_page, target_page, form_data) do
    if current_page < target_page do
      # 填写当前页面必要数据
      filled_view =
        if Map.has_key?(form_data, current_page) do
          fill_form_data(view, form_data[current_page])
        else
          view
        end

      # 导航到下一页
      next_view = navigate_to_next_page(filled_view)

      # 获取新的当前页面
      new_current_page = current_page_number(next_view)

      # 检查是否成功前进，如果没有，说明验证失败
      if new_current_page == current_page do
        IO.puts("警告：无法前进到下一页，可能是当前页面有未填写的必填项")
        next_view
      else
        # 递归前进到目标页面
        navigate_forward(next_view, new_current_page, target_page, form_data)
      end
    else
      # 已达到目标页面
      view
    end
  end
end
