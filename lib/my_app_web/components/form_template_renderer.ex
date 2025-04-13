defmodule MyAppWeb.FormTemplateRenderer do
  @moduledoc """
  表单模板渲染模块。

  提供表单模板的加载、渲染和处理功能，支持将表单控件和装饰元素组合显示。
  """

  use Phoenix.Component
  import Phoenix.HTML
  require Logger

  alias MyApp.FormTemplates
  alias MyApp.Forms
  alias MyAppWeb.FormLive.ItemRendererComponent
  alias MyAppWeb.DecorationComponents

  @doc """
  加载表单关联的模板。

  ## 参数
    - form: 表单结构体

  ## 返回值
    表单模板结构体或nil（如果没有关联模板）
  """
  def load_form_template(form) do
    if form.form_template_id do
      FormTemplates.get_template(form.form_template_id)
    else
      nil
    end
  end

  @doc """
  加载表单的完整数据，包括关联的模板。

  ## 参数
    - form_id: 表单ID

  ## 返回值
    包含表单和关联模板的结构体
  """
  def load_form_with_template(form_id) do
    with form when not is_nil(form) <- Forms.get_form(form_id),
         template <- load_form_template(form) do
      %{form: form, template: template}
    else
      nil -> %{form: nil, template: nil}
      error -> error
    end
  end

  @doc """
  渲染完整表单，包含装饰元素。

  ## 参数
    - assigns: 包含表单和模板数据的assigns
      - form: 表单结构体
      - form_template: 表单模板结构体
      - form_data: 表单数据（可选）
      - mode: 渲染模式，:display（默认）或 :edit_preview

  ## 示例
    ```heex
    <.render_form_with_decorations
      form={@form}
      form_template={@form_template}
      form_data={@form_data}
    />
    ```
  """
  attr :form, :map, required: true
  attr :form_template, :map
  attr :form_data, :map, default: %{}
  attr :mode, :atom, default: :display
  attr :errors, :map, default: %{}

  def render_form_with_decorations(assigns) do
    ~H"""
    <div class="form-container">
      <%= if @form_template do %>
        <%= render_with_template(@form, @form_template, @form_data, @mode, @errors) %>
      <% else %>
        <%= render_without_template(@form, @form_data, @mode, @errors) %>
      <% end %>
    </div>
    """
  end

  @doc """
  渲染特定页面，包含装饰元素。
  适用于分页表单场景。

  ## 参数
    - assigns: 包含表单、页面和模板数据的assigns
      - form: 表单结构体
      - form_template: 表单模板结构体
      - current_page: 当前页面
      - page_items: 当前页面的表单项
      - form_data: 表单数据（可选）
      - errors: 表单错误信息（可选）
  """
  attr :form, :map, required: true
  attr :form_template, :map
  attr :current_page, :map, required: true
  attr :page_items, :list, required: true
  attr :form_data, :map, default: %{}
  attr :errors, :map, default: %{}

  def render_page_with_decorations(assigns) do
    ~H"""
    <div class="form-page">
      <%= if @form_template do %>
        <%= render_page_with_template(@form, @form_template, @current_page, @page_items, @form_data, @errors) %>
      <% else %>
        <%= render_page_without_template(@current_page, @page_items, @form_data, @errors) %>
      <% end %>
    </div>
    """
  end

  # 使用模板渲染完整表单
  defp render_with_template(form, template, form_data, mode, errors) do
    case mode do
      :display ->
        if template && template.decoration && is_list(template.decoration) && !Enum.empty?(template.decoration) do
          # 有装饰元素时，使用优化的渲染方法
          render_template_with_decorations(form, template, form_data, errors)
        else
          # 无装饰元素或模板时，使用简单的模板渲染
          template_html = FormTemplates.render_template(template, form_data)
          raw(template_html)
        end

      :edit_preview ->
        # 在编辑预览模式下使用定制渲染，可能需要额外的控制
        assigns = %{
          form: form,
          form_data: form_data,
          errors: errors
        }
        ~H"""
        <div class="form-template-preview">
          <div class="form-items">
            <%= for item <- @form.items do %>
              <ItemRendererComponent.render_item item={item} mode={:edit_preview} form_data={@form_data} errors={@errors} />
            <% end %>
          </div>
        </div>
        """
    end
  end

  # 使用装饰元素渲染完整表单
  defp render_template_with_decorations(form, template, form_data, errors) do
    require Logger

    # 筛选表单项
    form_items = form.items || []
    Logger.info("============= 表单项列表 =============")
    Enum.each(form_items, fn item ->
      Logger.info("项目ID: #{item.id}, 标签: #{item.label || "无标签"}")
    end)
    
    # 获取所有装饰元素
    decorations = template.decoration || []

    # 从模板结构中加载逻辑规则
    template_structure = if template, do: template.structure || [], else: []
    template_id = if template, do: template.id, else: "nil"
    
    Logger.info("============= 模板信息 =============")
    Logger.info("模板ID: #{template_id}")
    Logger.info("模板结构类型: #{if is_list(template_structure), do: "List", else: inspect(template_structure.__struct__)}")
    
    # 直接打印整个模板结构以便查看
    IO.puts("\n模板ID: #{template_id}, 结构长度: #{length(template_structure)}")
    IO.inspect(template_structure, label: "完整的模板结构")
    
    # 检查模板结构中是否包含逻辑规则
    IO.puts("\n============= 检查模板结构中的逻辑规则 =============")
    Enum.each(template_structure, fn item ->
      item_id = item["id"] || Map.get(item, :id)
      item_type = item["type"] || Map.get(item, :type)
      item_label = item["label"] || Map.get(item, :label)
      
      # 检查项是否有逻辑规则
      has_logic = Map.has_key?(item, "logic") || Map.has_key?(item, :logic)
      logic = if has_logic, do: (item["logic"] || Map.get(item, :logic)), else: nil
      
      IO.puts("项: ID=#{item_id}, 类型=#{item_type}, 标签=#{item_label}")
      if has_logic do
        logic_type = (logic["type"] || Map.get(logic, :type))
        logic_target = (logic["target_id"] || Map.get(logic, :target_id))
        logic_condition = (logic["condition"] || Map.get(logic, :condition))
        IO.puts("  发现逻辑！类型: #{logic_type}, 目标ID: #{logic_target}, 条件: #{inspect(logic_condition)}")
      end
      
      # 特别查找目标ID
      target_item_id = "fe01d45d-fb33-4a47-b19c-fdd53b35d93e" # "我是🐷"项目ID
      jump_target_id = "f029db4f-e30d-4799-be1f-f330b1a6b9fe" # 跳转目标ID
      
      if item_id == target_item_id do
        IO.puts("*** 发现目标源项目: #{item_label} ***")
        IO.inspect(item, label: "源项目完整数据")
      end
      
      if item_id == jump_target_id do
        IO.puts("*** 发现跳转目标项目: #{item_label} ***")
        IO.inspect(item, label: "目标项目完整数据")
      end
    end)
    
    # 为表单项添加模板逻辑 - 使用与脚本相同的方法
    form_items_with_logic = Enum.map(form_items, fn item ->
      Logger.info("🔎 开始处理表单项: #{item.id} (#{item.label || ""})")
      
      # 使用直接字符串比较找到对应的表单项 - 与脚本中相同的方法
      template_item = Enum.find(template_structure, fn struct_item -> 
        template_id = struct_item["id"] || struct_item[:id]
        to_string(template_id) == to_string(item.id)
      end)
      
      # 如果在模板结构中找到了对应项
      if template_item do
        # 将完整的模板项记录到日志中，方便调试
        IO.inspect(template_item, label: "模板项: #{item.id}")
        Logger.info("✅ 在模板中找到表单项 #{item.id} (#{item.label || ""})")
        
        # 检查是否有逻辑规则 - 尝试所有可能的键格式
        has_logic = Map.has_key?(template_item, "logic") || Map.has_key?(template_item, :logic)
        
        if has_logic do
          # 确保从模板项中获取逻辑规则时考虑所有可能的键格式
          logic = template_item["logic"] || template_item[:logic]
          Logger.info("🎯 发现逻辑规则: #{inspect(logic)}")
          
          # 确保将逻辑规则拷贝到表单项上使用正确的格式
          Map.put(item, :logic, logic)
        else
          Logger.info("❌ 该表单项没有逻辑规则")
          item
        end
      else
        Logger.info("❌ 在模板结构中未找到该表单项")
        item
      end
    end)
    
    # 构建表单项映射
    items_map = Enum.reduce(form_items_with_logic, %{}, fn item, acc ->
      Map.put(acc, item.id, item)
    end)
    
    # 预处理表单项的可见性状态 - 从刚加载的模板逻辑
    form_items_with_visibility = Enum.map(form_items_with_logic, fn item ->
      # 获取表单项的逻辑（在前一步已加载）
      template_logic = Map.get(item, :logic)
      
      # 构建所有跳转逻辑的索引 - 从表单中获取对其他项目的跳转规则
      jump_logic_map = Enum.reduce(form_items_with_logic, %{}, fn source_item, acc ->
        source_logic = Map.get(source_item, :logic)
        if source_logic do
          logic_type = Map.get(source_logic, "type") || Map.get(source_logic, :type)
          target_id = Map.get(source_logic, "target_id") || Map.get(source_logic, :target_id)
          
          # 只处理跳转类型的逻辑，且有目标ID
          if logic_type == "jump" && target_id do
            # 添加源项目ID到逻辑中，以便后续处理
            updated_logic = Map.put(source_logic, "source_item_id", source_item.id)
            # 按目标ID索引
            Map.update(acc, target_id, [updated_logic], fn existing -> [updated_logic | existing] end)
          else
            acc
          end
        else
          acc
        end
      end)
      
      # 如果当前项是跳转目标，记录对应的跳转逻辑
      target_logic = Map.get(jump_logic_map, item.id)
      
      # 获取最终应用的逻辑规则
      final_logic = if is_nil(template_logic) && target_logic do
        # 如果项目自身没有逻辑，但是它是跳转目标
        # 如果有多个跳转到此项的逻辑，取第一个
        List.first(target_logic)
      else
        # 优先使用项目自身的逻辑
        template_logic
      end
      
      # 记录找到的最终逻辑规则（如果有）
      if final_logic do
        Logger.info("表单项 #{item.id} (#{item.label || ""}) 使用的最终逻辑: #{inspect(final_logic)}")
      else
        Logger.info("表单项 #{item.id} (#{item.label || ""}) 没有找到适用的逻辑规则")
      end
      
      # 评估表单项可见性
      should_show = evaluate_item_visibility(item, final_logic, form_data, true)
      
      Logger.info("表单项 #{item.id} (#{item.label || "无标签"}) 最终可见性: #{should_show}")
      
      # 将可见性状态添加到表单项
      Map.put(item, :should_show, should_show)
    end)

    assigns = %{
      form: form,
      template: template,
      form_items: form_items_with_visibility,
      decorations: decorations,
      items_map: items_map,
      form_data: form_data,
      errors: errors
    }

    ~H"""
    <div class="form-container-with-decorations">
      <!-- 1. 首先渲染位置为"start"的装饰元素 -->
      <%= for decoration <- Enum.filter(@decorations, fn d ->
          position = Map.get(d, "position") || Map.get(d, :position) || %{}
          position_type = Map.get(position, "type") || Map.get(position, :type)
          position_type == "start"
        end) do %>
        <.render_decoration element={decoration} />
      <% end %>

      <!-- 2. 遍历表单项，将"before"和"after"的装饰元素插入适当位置 -->
      <%= for item <- @form_items do %>
        <!-- 渲染"before"装饰元素 -->
        <%= for decoration <- Enum.filter(@decorations, fn d ->
            position = Map.get(d, "position") || Map.get(d, :position) || %{}
            position_type = Map.get(position, "type") || Map.get(position, :type)
            target_id = Map.get(position, "target_id") || Map.get(position, :target_id)
            position_type == "before" && target_id == item.id
          end) do %>
          <.render_decoration element={decoration} />
        <% end %>

        <!-- 渲染表单项，检查条件可见性 -->
        <%= if Map.get(item, :should_show, true) do %>
          <div data-item-id={item.id}>
            <ItemRendererComponent.render_item item={item} mode={:display} form_data={@form_data} errors={@errors} />
          </div>
        <% end %>

        <!-- 渲染"after"装饰元素 -->
        <%= for decoration <- Enum.filter(@decorations, fn d ->
            position = Map.get(d, "position") || Map.get(d, :position) || %{}
            position_type = Map.get(position, "type") || Map.get(position, :type)
            target_id = Map.get(position, "target_id") || Map.get(position, :target_id)
            position_type == "after" && target_id == item.id
          end) do %>
          <.render_decoration element={decoration} />
        <% end %>
      <% end %>

      <!-- 3. 渲染位置为"end"的装饰元素 -->
      <%= for decoration <- Enum.filter(@decorations, fn d ->
          position = Map.get(d, "position") || Map.get(d, :position) || %{}
          position_type = Map.get(position, "type") || Map.get(position, :type)
          position_type == "end"
        end) do %>
        <.render_decoration element={decoration} />
      <% end %>

      <!-- 4. 渲染没有指定位置的装饰元素 -->
      <%= for decoration <- Enum.filter(@decorations, fn d ->
          position = Map.get(d, "position") || Map.get(d, :position) || %{}
          position_type = Map.get(position, "type") || Map.get(position, :type)
          is_nil(position_type) || (position_type not in ["start", "end", "before", "after"])
        end) do %>
        <.render_decoration element={decoration} />
      <% end %>
    </div>
    """
  end

  # 新增：渲染单个装饰元素的辅助函数
  # 它会根据元素类型调用 DecorationComponents 中的组件
  # 注意：这里假设 DecorationComponents 已经定义了相应的组件
  # 例如：DecorationComponents.title, DecorationComponents.paragraph 等
  # 并且这些组件接受一个 :element 的 assign，其中包含元素的所有属性。
  attr :element, :map, required: true
  defp render_decoration(assigns) do
    # 从 assigns map 中获取 element
    element = assigns.element
    type = element["type"] || element[:type]
    # 提取通用 ID，确保有值
    elem_id = element["id"] || element[:id] || Ecto.UUID.generate()

    case type do
      "title" ->
        title = Map.get(element, "title", Map.get(element, :title, "未命名标题"))
        level = Map.get(element, "level", Map.get(element, :level, 2))
        align = Map.get(element, "align", Map.get(element, :align, "left"))
        style = Map.get(element, "style", Map.get(element, :style))
        # 将需要传递的变量放入 assigns map
        assigns = %{
          elem_id: elem_id,
          title: title,
          level: level,
          align: align,
          style: style
        }
        # 将参数传递给 title_element 组件
        ~H"""
        <DecorationComponents.title_element
          id={@elem_id}
          title={@title}
          level={@level}
          align={@align}
          style={@style}
        />
        """
      "paragraph" ->
        content = Map.get(element, "content", Map.get(element, :content, ""))
        style = Map.get(element, "style", Map.get(element, :style))
        assigns = %{
          elem_id: elem_id,
          content: content,
          style: style
        }
        # 将参数传递给 content_paragraph 组件
        ~H"""
        <DecorationComponents.content_paragraph
          id={@elem_id}
          content={@content}
          style={@style}
        />
        """
      "section" ->
        title = Map.get(element, "title", Map.get(element, :title))
        divider_style = Map.get(element, "divider_style", Map.get(element, :divider_style, "solid"))
        assigns = %{
          elem_id: elem_id,
          title: title,
          divider_style: divider_style
        }
        # 将参数传递给 section_divider 组件
        ~H"""
        <DecorationComponents.section_divider
          id={@elem_id}
          title={@title}
          divider_style={@divider_style}
        />
        """
      "explanation" ->
        content = Map.get(element, "content", Map.get(element, :content, ""))
        icon = Map.get(element, "icon", Map.get(element, :icon, "info")) # 假设编辑器保存了icon, 否则用默认值
        note_type = Map.get(element, "note_type", Map.get(element, :note_type, "info"))
        assigns = %{
          elem_id: elem_id,
          content: content,
          icon: icon,
          note_type: note_type
        }
        # 将参数传递给 explanation_box 组件
        ~H"""
        <DecorationComponents.explanation_box
          id={@elem_id}
          content={@content}
          icon={@icon}
          type={@note_type}
        />
        """
      "header_image" ->
        image_url = Map.get(element, "image_url", Map.get(element, :image_url, ""))
        height = Map.get(element, "height", Map.get(element, :height, "300px"))
        alt = Map.get(element, "alt", Map.get(element, :alt, ""))
        assigns = %{
          elem_id: elem_id,
          image_url: image_url,
          height: height,
          alt: alt
        }
        # 直接传递独立参数给 header_image 组件
        ~H"""
        <DecorationComponents.header_image
          id={@elem_id}
          image_url={@image_url}
          height={@height}
          alt={@alt}
        />
        """
      "inline_image" ->
        image_url = Map.get(element, "image_url", Map.get(element, :image_url, ""))
        caption = Map.get(element, "caption", Map.get(element, :caption))
        width = Map.get(element, "width", Map.get(element, :width, "100%"))
        align = Map.get(element, "align", Map.get(element, :align, "center"))
        assigns = %{
          elem_id: elem_id,
          image_url: image_url,
          caption: caption,
          width: width,
          align: align
        }
        # 直接传递独立参数给 inline_image 组件
        ~H"""
        <DecorationComponents.inline_image
          id={@elem_id}
          image_url={@image_url}
          caption={@caption}
          width={@width}
          align={@align}
        />
        """
      # spacer 暂时不处理，归入未知类型
      # "spacer" -> ...
      _ ->
        # 对于未知类型或 spacer，渲染一个占位符或错误信息
        # 确保 assigns 包含 type 供 ~H 使用
        assigns = %{type: type}
        ~H"""
        <div class="text-red-500">未知或暂未处理的装饰元素类型: <%= @type %></div>
        """
    end
  end

  # 无模板时的渲染（回退到传统渲染）
  defp render_without_template(form, form_data, mode, errors) do
    assigns = %{
      form: form,
      form_data: form_data,
      mode: mode,
      errors: errors
    }
    ~H"""
    <div class="form-items">
      <%= for item <- @form.items do %>
        <ItemRendererComponent.render_item item={item} mode={@mode} form_data={@form_data} errors={@errors} />
      <% end %>
    </div>
    """
  end

  # 使用模板渲染特定页面
  defp render_page_with_template(form, template, current_page, page_items, form_data, errors) do
    # 获取所有装饰元素
    decorations = template.decoration || []

    # 获取当前页码和总页数 (假设 form.pages 是一个列表，并且 current_page 有 order)
    pages = form.pages || []
    total_pages = length(pages)
    current_page_number = current_page.order # 假设 current_page.order 代表页码 (从1开始)
    
    # 预处理表单项的可见性状态 - 只使用模板逻辑，与前面的代码保持一致
    page_items_with_visibility = Enum.map(page_items, fn item ->
      # 从表单项中提取逻辑
      template_logic = Map.get(item, :logic) || Map.get(item, "logic")
      
      # 构建所有跳转逻辑的索引 - 从页面表单项中获取对其他项目的跳转规则
      jump_logic_map = Enum.reduce(page_items, %{}, fn source_item, acc ->
        source_logic = Map.get(source_item, :logic) || Map.get(source_item, "logic")
        if source_logic do
          logic_type = Map.get(source_logic, "type") || Map.get(source_logic, :type)
          target_id = Map.get(source_logic, "target_id") || Map.get(source_logic, :target_id)
          
          # 只处理跳转类型的逻辑，且有目标ID
          if logic_type == "jump" && target_id do
            # 添加源项目ID到逻辑中，以便后续处理
            updated_logic = Map.put(source_logic, "source_item_id", source_item.id)
            # 按目标ID索引
            Map.update(acc, target_id, [updated_logic], fn existing -> [updated_logic | existing] end)
          else
            acc
          end
        else
          acc
        end
      end)
      
      # 如果当前项是跳转目标，使用对应的跳转逻辑
      target_logic = Map.get(jump_logic_map, item.id)
      
      # 优先使用项目自身的逻辑，其次是以它为目标的跳转逻辑
      final_logic = if is_nil(template_logic) && target_logic do
        # 如果有多个跳转到此项的逻辑，取第一个
        List.first(target_logic)
      else
        template_logic
      end
      
      # 记录找到的模板逻辑（如果有）
      if final_logic do
        Logger.info("页面表单项 #{item.id} (#{item.label || ""}) 使用的逻辑: #{inspect(final_logic)}")
      else
        Logger.info("页面表单项 #{item.id} (#{item.label || ""}) 没有找到适用的逻辑规则")
      end
      
      # 注意：不再使用visibility_condition，只使用模板逻辑
      should_show = evaluate_item_visibility(item, final_logic, form_data, true)
      
      Logger.info("表单项 #{item.id} (#{item.label || "无标签"}) 最终可见性: #{should_show}")
      
      # 将可见性状态添加到表单项
      Map.put(item, :should_show, should_show)
    end)

    assigns = %{
      form: form,
      template: template,
      current_page: current_page,
      page_items: page_items_with_visibility,
      form_data: form_data,
      errors: errors,
      decorations: decorations,
      current_page_number: current_page_number,
      total_pages: total_pages
    }

    ~H"""
    <div class="form-page-items">
      <!-- 1. 仅在第一页渲染 "start" 装饰元素 -->
      <%= if @current_page_number == 1 do %>
        <%= for decoration <- Enum.filter(@decorations, fn d ->
            position = Map.get(d, "position") || Map.get(d, :position) || %{}
            position_type = Map.get(position, "type") || Map.get(position, :type)
            position_type == "start"
          end) do %>
          <.render_decoration element={decoration} />
        <% end %>
      <% end %>

      <!-- 2. 遍历当前页的表单项，渲染 before/after 装饰元素 -->
      <%= for item <- @page_items do %>
        <!-- 渲染 "before" 装饰元素 -->
        <%= for decoration <- Enum.filter(@decorations, fn d ->
            position = Map.get(d, "position") || Map.get(d, :position) || %{}
            position_type = Map.get(position, "type") || Map.get(position, :type)
            target_id = Map.get(position, "target_id") || Map.get(position, :target_id)
            position_type == "before" && target_id == item.id
          end) do %>
          <.render_decoration element={decoration} />
        <% end %>

        <!-- 渲染表单项，检查条件可见性 -->
        <%= if Map.get(item, :should_show, true) do %>
          <div data-item-id={item.id}>
            <ItemRendererComponent.render_item item={item} mode={:display} form_data={@form_data} errors={@errors} />
          </div>
        <% end %>

        <!-- 渲染 "after" 装饰元素 -->
        <%= for decoration <- Enum.filter(@decorations, fn d ->
            position = Map.get(d, "position") || Map.get(d, :position) || %{}
            position_type = Map.get(position, "type") || Map.get(position, :type)
            target_id = Map.get(position, "target_id") || Map.get(position, :target_id)
            position_type == "after" && target_id == item.id
          end) do %>
          <.render_decoration element={decoration} />
        <% end %>
      <% end %>

      <!-- 3. 仅在最后一页渲染 "end" 装饰元素 -->
      <%= if @current_page_number == @total_pages do %>
        <%= for decoration <- Enum.filter(@decorations, fn d ->
            position = Map.get(d, "position") || Map.get(d, :position) || %{}
            position_type = Map.get(position, "type") || Map.get(position, :type)
            position_type == "end"
          end) do %>
          <.render_decoration element={decoration} />
        <% end %>
      <% end %>

      <!-- 4. 不渲染无位置或未知位置的装饰元素 -->

    </div>
    """
  end

  # 无模板时渲染特定页面
  defp render_page_without_template(current_page, page_items, form_data, errors) do
    # !!! FIX: Create assigns map for ~H sigil !!!
    assigns = %{
      current_page: current_page,
      page_items: page_items,
      form_data: form_data,
      errors: errors
    }

    ~H"""
    <div class="form-page-items">
      <%= for item <- @page_items do %>
        <ItemRendererComponent.render_item item={item} mode={:display} form_data={@form_data} errors={@errors} />
      <% end %>
    </div>
    """
  end

  # 其他辅助函数可以在这里添加...
  
  # 评估表单项可见性 - 使用与脚本相同的方法
  defp evaluate_item_visibility(item, template_logic, form_data, _default_visibility) do
    require Logger
    
    # 如果没有模板逻辑，默认显示项目
    if template_logic == nil do
      Logger.info("表单项 #{item.id} 没有模板逻辑，默认显示")
      true
    else
      # 记录实际发现的模板逻辑并使用IO.inspect以显示完整内容
      IO.inspect(template_logic, label: "表单项 #{item.id} 的模板逻辑")
      Logger.info("发现模板逻辑: #{inspect(template_logic)}")
      
      # 获取逻辑类型 - 尝试所有可能的键格式
      logic_type = Map.get(template_logic, "type") || Map.get(template_logic, :type)
      Logger.info("表单项 #{item.id} 的模板逻辑类型: #{logic_type}")
      
      # 基于逻辑类型处理
      case logic_type do
        "jump" ->
          # 从逻辑中获取条件、目标ID - 确保考虑所有键格式
          condition = Map.get(template_logic, "condition") || Map.get(template_logic, :condition) || %{}
          target_id = Map.get(template_logic, "target_id") || Map.get(template_logic, :target_id)
          
          # 确保条件信息完整
          value = Map.get(condition, "value") || Map.get(condition, :value)
          operator = Map.get(condition, "operator") || Map.get(condition, :operator)
          
          Logger.info("跳转逻辑详情: 条件值='#{value}', 操作符='#{operator}', 目标项='#{target_id}'")
          
          # 特别标记"我是🐷"逻辑
          if "#{value}" == "我是🐷" do
            Logger.info("🚨 检测到'我是🐷'跳转逻辑，源项=#{item.id}, 目标项=#{target_id}")
          end
          
          # 处理跳转逻辑 - 使用已更新的函数
          evaluate_jump_logic(item, condition, target_id, form_data)
          
        "show" ->
          # 处理显示逻辑 - 当条件满足时显示项目
          condition = Map.get(template_logic, "condition") || Map.get(template_logic, :condition) || %{}
          target_id = Map.get(template_logic, "target_id") || Map.get(template_logic, :target_id)
          
          # 获取条件源ID，可能是当前项或指定的源
          source_id = Map.get(condition, "source_item_id") || 
                      Map.get(condition, :source_item_id) ||
                      Map.get(template_logic, "source_id") || 
                      Map.get(template_logic, :source_id) ||
                      item.id
                      
          if item.id == target_id do
            # 当前项是目标项，评估条件
            evaluate_show_hide_logic(condition, form_data, true, source_id)
          else
            # 非目标项始终显示
            true 
          end
          
        "hide" ->
          # 处理隐藏逻辑 - 当条件满足时隐藏项目
          condition = Map.get(template_logic, "condition") || Map.get(template_logic, :condition) || %{}
          target_id = Map.get(template_logic, "target_id") || Map.get(template_logic, :target_id)
          
          # 获取条件源ID，可能是当前项或指定的源
          source_id = Map.get(condition, "source_item_id") || 
                      Map.get(condition, :source_item_id) ||
                      Map.get(template_logic, "source_id") || 
                      Map.get(template_logic, :source_id) ||
                      item.id
                      
          if item.id == target_id do
            # 当前项是目标项，评估条件
            evaluate_show_hide_logic(condition, form_data, false, source_id)
          else
            # 非目标项始终显示
            true
          end
          
        "visibility" ->
          # 旧式可见性逻辑兼容处理
          condition = Map.get(template_logic, "condition") || Map.get(template_logic, :condition) || %{}
          source_id = Map.get(template_logic, "source_id") || Map.get(template_logic, :source_id) ||
                      Map.get(condition, "source_id") || Map.get(condition, :source_id)
          operator = Map.get(condition, "operator") || Map.get(condition, :operator)
          value = Map.get(condition, "value") || Map.get(condition, :value)
          
          # 创建简单条件并评估
          if source_id && operator && value do
            Logger.info("评估旧式可见性逻辑: 源ID=#{source_id}, 操作符=#{operator}, 值=#{inspect(value)}")
            simple_condition = %{"type" => "simple", "source_item_id" => source_id, "operator" => operator, "value" => value}
            result = MyApp.FormLogic.evaluate_condition(simple_condition, form_data)
            Logger.info("旧式可见性逻辑评估结果: #{result}")
            result
          else
            Logger.warning("旧式可见性逻辑条件不完整")
            true # 如果条件不完整，默认显示
          end
          
        _ ->
          Logger.warn("未知的逻辑类型: #{logic_type}")
          true # 默认显示
      end
    end
  end
  
  # 评估跳转逻辑的辅助函数 - 使用与脚本相同的方法
  defp evaluate_jump_logic(item, condition, target_id, form_data) do
    require Logger
    
    # 从条件中获取源ID，如果没有则使用当前项ID
    source_id = Map.get(condition, "source_item_id") || 
                Map.get(condition, :source_item_id) || 
                item.id
    
    # 获取条件信息
    operator = Map.get(condition, "operator") || Map.get(condition, :operator)
    value = Map.get(condition, "value") || Map.get(condition, :value)
    
    # 详细记录跳转逻辑的评估
    Logger.info("评估跳转逻辑: 项目ID=#{item.id}, 源ID=#{source_id}, 操作符=#{operator}, 值=#{inspect(value)}, 目标ID=#{target_id}")
    
    # 特别的情况：检查是否是"我是🐷"逻辑 - 使用与脚本相同的检测方式
    is_pig_logic = "#{value}" == "我是🐷"
    if is_pig_logic do
      Logger.info("🚨 检测到'我是🐷'跳转逻辑")
    end
    
    if operator && value do
      # 获取源字段的当前值（用户选择的值）- 与脚本相同
      source_value = Map.get(form_data, source_id)
      Logger.info("源字段 #{source_id} 的当前值: #{inspect(source_value)}")
      
      # 特殊标记选择了"a"的情况 - 方便调试
      if source_value == "a" do
        Logger.info("🎯🎯 检测到用户选择了'a'，不符合'我是🐷'条件，应执行跳转")
      end
      
      # 评估条件 - 使用与脚本相同的方法
      condition_result = case operator do
        "equals" -> "#{source_value}" == "#{value}"
        "not_equals" -> "#{source_value}" != "#{value}"
        "contains" -> is_binary(source_value) && String.contains?("#{source_value}", "#{value}")
        _ -> false
      end
      
      Logger.info("跳转条件评估结果: #{condition_result}")
      
      # 处理跳转逻辑：
      # 1. 条件满足（例如选择了"我是🐷"）：所有项目正常显示
      # 2. 条件不满足（例如选择了"a"）：只显示目标项，跳过中间项
      
      if condition_result do
        # 条件满足（选择了"我是🐷"），不执行跳转，所有项目正常显示
        Logger.info("🟢 条件满足（'#{source_value}' = '#{value}'），不执行跳转，表单项 #{item.id} 将被显示")
        true
      else
        # 条件不满足（选择了其他值如"a"），执行跳转
        # 只有目标项会显示，其他项被跳过
        should_show = item.id == target_id
        
        # 记录跳转决策
        Logger.info("🔴 条件不满足（'#{source_value}' ≠ '#{value}'），执行跳转")
        Logger.info("当前项: #{item.id}, 跳转目标: #{target_id}, 是否目标项? #{should_show}")
        
        # 返回可见性结果
        should_show
      end
    else
      Logger.warning("跳转逻辑条件不完整: #{inspect(condition)}")
      true # 条件不完整或异常情况，默认显示
    end
  end
  
  # 评估显示/隐藏逻辑的辅助函数
  defp evaluate_show_hide_logic(condition, form_data, show_when_true, item_id \\ nil) do
    require Logger
    
    # 获取条件信息
    operator = Map.get(condition, "operator") || Map.get(condition, :operator)
    value = Map.get(condition, "value") || Map.get(condition, :value)
    
    # 尝试从条件中提取源字段ID
    source_id = Map.get(condition, "source_id") || Map.get(condition, :source_id) ||
                Map.get(condition, "source_item_id") || Map.get(condition, :source_item_id)
    
    # 如果没有source_id，检查left属性
    left = Map.get(condition, "left") || Map.get(condition, :left) || %{}
    source_id = source_id || (Map.get(left, "name") || Map.get(left, :name))
    
    # 如果source_id仍然没有，但我们知道当前项目ID，则使用它作为源
    source_id = source_id || item_id
    
    # 记录显示/隐藏逻辑的评估
    action_type = if show_when_true, do: "显示", else: "隐藏"
    Logger.info("评估#{action_type}逻辑: 源ID=#{source_id}, 操作符=#{operator}, 值=#{inspect(value)}")
    
    if source_id && operator && value do
      # 获取源字段的当前值
      source_value = Map.get(form_data, source_id)
      Logger.info("用户选择的值: #{inspect(source_value)}")
      
      # 直接评估条件，确保字符串比较
      condition_result = case operator do
        "equals" -> "#{source_value}" == "#{value}"
        "not_equals" -> "#{source_value}" != "#{value}" 
        "contains" -> is_binary(source_value) && String.contains?("#{source_value}", "#{value}")
        _ -> false
      end
      
      Logger.info("#{action_type}条件评估结果: #{condition_result}")
      
      # 根据show_when_true决定结果: 
      # - 如果是show逻辑，条件为true时显示；
      # - 如果是hide逻辑，条件为true时隐藏
      result = if show_when_true, do: condition_result, else: !condition_result
      Logger.info("最终可见性: #{result}")
      result
    else
      Logger.warning("#{action_type}逻辑条件不完整: #{inspect(condition)}")
      true # 条件不完整，默认显示
    end
  end
end
