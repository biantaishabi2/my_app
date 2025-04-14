defmodule MyAppWeb.FormLive.Edit do
  use MyAppWeb, :live_view

  alias MyApp.Forms
  alias MyApp.Forms.FormItem
  alias MyAppWeb.FormLive.ItemRendererComponent
  alias MyApp.Upload
  # Repo在测试环境中的直接查询中使用，但可以通过完全限定名称访问
  # alias MyApp.Repo
  # 移除未使用的ItemOption别名

  # import Ecto.Query
  import MyAppWeb.FormComponents
  # Phoenix.LiveView.Upload 的函数已经通过 use MyAppWeb, :live_view 导入

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    form = Forms.get_form(id)

    if form do
      # 设置表单和默认值
      socket =
        socket
        |> assign(:form, form)
        # 确保不会是nil
        |> assign(:form_items, form.items || [])
        |> assign(:active_category, :basic)
        # 默认类型
        |> assign(:item_type, "text_input")
        |> assign(:editing_item, false)
        # 用于直接在列表中编辑
        |> assign(:editing_item_id, nil)
        |> assign(:current_item, nil)
        |> assign(:loading_complete, false)
        |> assign(:item_options, [])
        |> assign(:editing_form_info, false)
        |> assign(:editing_respondent_attributes, false)
        |> assign(:search_term, nil)
        |> assign(:delete_item_id, nil)
        |> assign(:editing_page, false)
        |> assign(:current_page, nil)
        |> assign(:delete_page_id, nil)
        # 用于发布确认
        |> assign(:show_publish_confirm, false)
        |> assign(:editing_conditions, false)
        |> assign(:current_condition_item, nil)
        # 用于追踪当前正在编辑的选项的索引
        |> assign(:current_option_index, nil)
        |> assign(:current_condition_type, nil)
        |> assign(:available_condition_items, [])
        # 用于临时存储图片上传信息
        |> assign(:temp_image_upload, %{})
        # 页面相关状态 - 在现有代码基础上添加这些
        |> assign(:current_page_idx, 0)
        |> assign(:page_items, [])

      # 允许Phoenix.LiveView上传图片
      socket =
        socket
        |> allow_upload(:image,
          accept: ~w(.jpg .jpeg .png .gif),
          max_entries: 1,
          # 5MB
          max_file_size: 5_000_000,
          auto_upload: false
        )

      {:ok, socket}
    else
      {:ok,
       socket
       |> put_flash(:error, "表单不存在")
       |> redirect(to: ~p"/forms")}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    if socket.assigns[:loading_complete] do
      # 已经加载过数据的情况下不重复加载
      {:noreply, apply_action(socket, socket.assigns.live_action, params)}
    else
      # 开始异步加载表单完整数据
      send(self(), {:load_form_data, socket.assigns.form.id})

      # 先返回正在加载的状态
      {:noreply,
       socket
       |> assign(:loading_complete, false)
       |> apply_action(socket.assigns.live_action, params)}
    end
  end

  # 异步加载表单数据
  @impl true
  def handle_info({:load_form_data, form_id}, socket) do
    # 并行获取需要的数据（控件类型和表单数据）
    all_types = Forms.list_available_form_item_types()
    form_with_pages = Forms.get_form_with_full_preload(form_id)

    # 确保表单有默认页面并处理未关联页面的表单项
    {:ok, _} = Forms.assign_default_page(form_with_pages)

    # 预先收集现有表单项，检查是否需要迁移
    all_form_items =
      Enum.flat_map(form_with_pages.pages, fn page ->
        # 提取每个页面的表单项
        page.items || []
      end)

    # 只有在确实需要迁移的情况下执行迁移操作
    form_with_pages =
      if length(form_with_pages.items) > length(all_form_items) do
        # 迁移未关联页面的表单项到默认页面
        {:ok, updated_form} = Forms.migrate_items_to_default_page_optimized(form_with_pages)
        updated_form
      else
        # 不需要迁移，直接使用现有表单
        form_with_pages
      end

    # 重新收集所有表单项
    all_form_items =
      Enum.flat_map(form_with_pages.pages, fn page ->
        page.items || []
      end)

    # 初始化当前页面数据 - 增加这部分代码
    current_page = List.first(form_with_pages.pages || [])
    current_page_idx = 0
    page_items = get_page_items(form_with_pages, current_page)

    # 更新socket状态
    {:noreply,
     socket
     |> assign(:form, form_with_pages)
     |> assign(:form_items, all_form_items)
     |> assign(:all_item_types, all_types)
     # 添加这些页面相关的状态
     |> assign(:current_page, current_page)
     |> assign(:current_page_idx, current_page_idx)
     |> assign(:page_items, page_items)
     |> assign(:loading_complete, true)
     |> assign(
       :editing_form_info,
       Enum.empty?(all_form_items) &&
         (form_with_pages.title == nil || form_with_pages.title == "")
     )}
  end

  @impl true
  # 处理异步表单项添加后的事件，确保界面正确更新
  def handle_info({:update_matrix_defaults, updated_item}, socket) do
    {:noreply, assign(socket, :current_item, updated_item)}
  end

  @impl true
  def handle_info({:respondent_attributes_updated, updated_form}, socket) do
    {:noreply,
     socket
     |> assign(:form, updated_form)
     |> put_flash(:info, "回答者属性设置已更新")}
  end

  @impl true
  def handle_info({:respondent_attributes_error, message}, socket) do
    {:noreply, put_flash(socket, :error, message)}
  end

  defp apply_action(socket, :edit, _params) do
    socket
    |> assign(:page_title, "编辑表单 - #{socket.assigns.form.title}")
  end

  @impl true
  def handle_event("add_page", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_page, true)
     |> assign(:current_page, nil)}
  end

  @impl true
  def handle_event("delete_page", %{"id" => id}, socket) do
    # 设置要删除的页面ID，以便确认
    {:noreply, assign(socket, :delete_page_id, id)}
  end

  @impl true
  def handle_event("cancel_delete_page", _params, socket) do
    {:noreply, assign(socket, :delete_page_id, nil)}
  end

  @impl true
  def handle_event("pages_reordered", %{"pageIds" => page_ids}, socket) do
    form = socket.assigns.form

    case Forms.reorder_form_pages(form.id, page_ids) do
      {:ok, _} ->
        # 重新加载表单
        updated_form = Forms.get_form(form.id)

        {:noreply,
         socket
         |> assign(:form, updated_form)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "页面排序失败: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("confirm_delete_page", _params, socket) do
    id = socket.assigns.delete_page_id
    form = socket.assigns.form

    # 查找页面
    page = Enum.find(form.pages, fn p -> p.id == id end)

    if page do
      case Forms.delete_form_page(page) do
        {:ok, _} ->
          # 重新加载表单
          updated_form = Forms.get_form(form.id)

          {:noreply,
           socket
           |> assign(:form, updated_form)
           |> assign(:delete_page_id, nil)
           |> put_flash(:info, "页面已删除")}
        {:error, _} ->
          {:noreply,
           socket
           |> put_flash(:error, "无法删除页面")}
      end
    else
      {:noreply, put_flash(socket, :error, "找不到要删除的页面")}
    end
  end

  @impl true
  def handle_event("edit_page", %{"id" => id}, socket) do
    page = Enum.find(socket.assigns.form.pages, fn p -> p.id == id end)

    if page do
      # Assign the values
      new_socket =
        socket
        |> assign(:editing_page, true)
        |> assign(:current_page, page)

      {:noreply, new_socket} # 返回修改后的 socket
    else
      {:noreply, put_flash(socket, :error, "页面不存在")}
    end
  end

  @impl true
  def handle_event("cancel_edit_page", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_page, false)
     |> assign(:current_page, nil)}
  end

  @impl true
  def handle_event("save_page", %{"page" => page_params}, socket) do
    form = socket.assigns.form
    current_page = socket.assigns.current_page

    if current_page do
      # 更新现有页面
      case Forms.update_form_page(current_page, page_params) do
        {:ok, _updated_page} ->
          # 重新加载表单以获取更新后的页面数据
          updated_form = Forms.get_form(form.id)

          {:noreply,
           socket
           |> assign(:form, updated_form)
           |> assign(:editing_page, false)
           |> assign(:current_page, nil)
           |> put_flash(:info, "页面已更新")}

        {:error, changeset} ->
          {:noreply, put_flash(socket, :error, "页面更新失败: #{inspect(changeset.errors)}")}
      end
    else
      # 创建新页面
      # ---- 新增转换 ----
      page_params_with_atom_keys =
        Enum.into(page_params, %{}, fn {key, value} -> {String.to_existing_atom(key), value} end)
      # ---- 结束转换 ----

      case Forms.create_form_page(form, page_params_with_atom_keys) do
        {:ok, _new_page} ->
          # 重新加载表单以获取新页面数据
          updated_form = Forms.get_form(form.id)

          {:noreply,
           socket
           |> assign(:form, updated_form)
           |> assign(:editing_page, false)
           |> assign(:current_page, nil)
           |> put_flash(:info, "页面已添加")}

        {:error, changeset} ->
          {:noreply, put_flash(socket, :error, "页面添加失败: #{inspect(changeset.errors)}\n请检查日志了解详情。")}
      end
    end
  end

  @impl true
  def handle_event("edit_form_info", _params, socket) do
    {:noreply, assign(socket, :editing_form_info, true)}
  end

  @impl true
  def handle_event("cancel_edit_form_info", _params, socket) do
    {:noreply, assign(socket, :editing_form_info, false)}
  end

  @impl true
  def handle_event("edit_respondent_attributes", _params, socket) do
    {:noreply, assign(socket, :editing_respondent_attributes, true)}
  end

  @impl true
  def handle_event("cancel_edit_respondent_attributes", _params, socket) do
    {:noreply, assign(socket, :editing_respondent_attributes, false)}
  end

  @impl true
  def handle_event("save_form_info", params, socket) do
    form = socket.assigns.form

    # 优先使用表单提交的参数，如果没有则使用临时存储的值
    form_params = params["form"] || %{}
    title = form_params["title"] || socket.assigns[:temp_title] || form.title

    description =
      form_params["description"] || socket.assigns[:temp_description] || form.description


    form_params = %{
      "title" => title,
      "description" => description
    }

    case Forms.update_form(form, form_params) do
      {:ok, updated_form} ->
        # 使用公共函数重新加载表单和更新socket
        {:noreply, reload_form_and_update_socket(socket, updated_form.id, "表单信息已更新")}

      {:error, %Ecto.Changeset{} = changeset} ->

        {:noreply,
         socket
         |> assign(:form_changeset, changeset)
         |> put_flash(:error, "表单更新失败")}
    end
  end

  @impl true
  def handle_event("add_item", params, socket) do
    # 检查是否指定了页面ID
    page_id = Map.get(params, "page_id")
    form = socket.assigns.form

    # 获取默认页面ID
    default_page_id =
      form.default_page_id || if length(form.pages) > 0, do: List.first(form.pages).id, else: nil

    # 使用指定的页面ID或默认页面ID
    page_id = page_id || default_page_id

    # 使用当前选择的控件类型
    item_type_str = socket.assigns.item_type || "text_input"

    item_type =
      case item_type_str do
        "text_input" -> :text_input
        "textarea" -> :textarea
        "radio" -> :radio
        "checkbox" -> :checkbox
        "dropdown" -> :dropdown
        "rating" -> :rating
        "number" -> :number
        "email" -> :email
        "phone" -> :phone
        "date" -> :date
        "time" -> :time
        "region" -> :region
        "matrix" -> :matrix
        "image_choice" -> :image_choice
        "file_upload" -> :file_upload
        _ -> :text_input
      end

    # 使用当前表单类型设置默认标签
    default_label =
      case item_type do
        :radio -> "新单选问题"
        :checkbox -> "新复选问题"
        :matrix -> "新矩阵题"
        :dropdown -> "新下拉菜单"
        :rating -> "新评分题"
        _ -> "新问题"
      end

    # 保留现有临时标签（如果存在），或使用默认标签
    temp_label = socket.assigns[:temp_label] || default_label

    # 创建初始化的表单项
    new_item = %FormItem{
      type: item_type,
      required: false,
      page_id: page_id,
      label: temp_label
    }

    # 根据控件类型设置默认属性
    new_item =
      cond do
        item_type == :matrix ->
          new_item
          |> Map.put(:matrix_rows, ["问题1", "问题2", "问题3"])
          |> Map.put(:matrix_columns, ["选项A", "选项B", "选项C"])
          |> Map.put(:matrix_type, :single)

        # 图片选择类型的特殊处理：预设选择类型和标题位置
        item_type == :image_choice ->
          new_item
          |> Map.put(:selection_type, :single)
          |> Map.put(:image_caption_position, :bottom)

        true ->
          new_item
      end


    # 准备选项数据
    initial_options =
      cond do
        # 为图片选择题添加默认选项
        item_type == :image_choice ->
          # 创建两个示例选项
          [
            %{
              id: Ecto.UUID.generate(),
              label: "示例图片A",
              value: "option_a",
              image_id: nil,
              image_filename: nil
            },
            %{
              id: Ecto.UUID.generate(),
              label: "示例图片B",
              value: "option_b",
              image_id: nil,
              image_filename: nil
            }
          ]

        # 为选项类控件添加默认选项（单选、复选、下拉）
        item_type in [:radio, :checkbox, :dropdown] ->
          [
            %{id: Ecto.UUID.generate(), label: "选项A", value: "option_a"},
            %{id: Ecto.UUID.generate(), label: "选项B", value: "option_b"}
          ]

        # 其他控件类型没有默认选项
        true ->
          []
      end

    # 给当前表单项分配一个ID，防止有多个"添加问题"按钮
    # 注意：设置editing_item=true但不设置editing_item_id，使用顶部编辑区域
    {:noreply,
     socket
     |> assign(:current_item, new_item)
     # 使用根据控件类型生成的初始选项
     |> assign(:item_options, initial_options)
     |> assign(:item_type, item_type)
     |> assign(:editing_item, true)
     # 明确设置为nil，确保使用顶部编辑区域
     |> assign(:editing_item_id, nil)
     # 保留标签值，不清除
     |> assign(:temp_label, temp_label)}
  end

  @impl true
  def handle_event("edit_item", %{"id" => id}, socket) do
    item = Enum.find(socket.assigns.form_items, fn item -> item.id == id end)

    if item do
      options =
        case item.options do
          nil -> []
          opts -> opts
        end


      # 改为设置editing_item_id而不是editing_item=true
      {:noreply,
       socket
       |> assign(:current_item, item)
       |> assign(:item_options, options)
       |> assign(:item_type, to_string(item.type))
       # 设置当前正在原地编辑的表单项ID
       |> assign(:editing_item_id, id)
       |> assign(:temp_label, item.label)}
    else
      {:noreply, put_flash(socket, :error, "表单项不存在")}
    end
  end

  @impl true
  def handle_event("cancel_edit_item", _params, socket) do

    {:noreply,
     socket
     |> assign(:current_item, nil)
     |> assign(:editing_item, false)
     # 清除原地编辑ID
     |> assign(:editing_item_id, nil)
     |> assign(:item_options, [])
     |> assign(:editing_conditions, false)
     |> assign(:current_condition, nil)}
  end

  # 条件逻辑事件处理

  def handle_event("edit_conditions", %{"id" => item_id, "type" => condition_type}, socket) do
    # 获取表单项
    form_item = Enum.find(socket.assigns.form_items, &(&1.id == item_id))

    # 确定条件类型（可见性或必填）
    condition_type = String.to_existing_atom(condition_type)

    # 获取现有条件（如果有）
    current_condition =
      case condition_type do
        :visibility ->
          if form_item.visibility_condition do
            Jason.decode!(form_item.visibility_condition)
          else
            nil
          end

        :required ->
          if form_item.required_condition do
            Jason.decode!(form_item.required_condition)
          else
            nil
          end
      end

    # 获取可以作为条件源的表单项（不包括当前表单项）
    available_items =
      Enum.filter(socket.assigns.form_items, fn item ->
        item.id != item_id
      end)

    {:noreply,
     socket
     |> assign(:editing_conditions, true)
     |> assign(:current_item, form_item)
     |> assign(:condition_type, condition_type)
     |> assign(:current_condition, current_condition)
     |> assign(:available_items, available_items)}
  end

  def handle_event("cancel_edit_conditions", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_conditions, false)
     |> assign(:current_item, nil)
     |> assign(:current_condition, nil)}
  end

  def handle_event("add_simple_condition", params, socket) do
    parent_id = Map.get(params, "parent-id")

    # 创建一个新的简单条件
    new_condition = %{
      "type" => "simple",
      "source_item_id" => nil,
      "operator" => "equals",
      "value" => ""
    }

    # 处理不同情况
    updated_condition =
      cond do
        # 如果是顶级条件且当前没有条件
        is_nil(parent_id) && is_nil(socket.assigns.current_condition) ->
          new_condition

        # 如果是顶级条件但已有一个简单条件，则创建一个 AND 组合条件
        is_nil(parent_id) && socket.assigns.current_condition["type"] == "simple" ->
          %{
            "type" => "compound",
            "operator" => "and",
            "conditions" => [socket.assigns.current_condition, new_condition]
          }

        # 如果是顶级条件且已有一个复合条件，则向该复合条件添加子条件
        is_nil(parent_id) && socket.assigns.current_condition["type"] == "compound" ->
          updated_conditions = socket.assigns.current_condition["conditions"] ++ [new_condition]
          Map.put(socket.assigns.current_condition, "conditions", updated_conditions)

        # 如果是子条件，则找到父条件并添加新的子条件
        !is_nil(parent_id) ->
          # 递归函数，在嵌套条件中查找并更新父条件
          add_to_parent = fn condition, parent_id, recurse ->
            case condition do
              %{"type" => "compound", "conditions" => conditions} = compound ->
                if condition["id"] == parent_id do
                  # 找到了父条件，添加新的子条件
                  Map.put(compound, "conditions", conditions ++ [new_condition])
                else
                  # 递归查找子条件
                  updated_conditions = Enum.map(conditions, &recurse.(&1, parent_id, recurse))
                  Map.put(compound, "conditions", updated_conditions)
                end

              # 不是复合条件，返回原条件
              _ ->
                condition
            end
          end

          add_to_parent.(socket.assigns.current_condition, parent_id, add_to_parent)
      end

    {:noreply, assign(socket, :current_condition, updated_condition)}
  end

  def handle_event("add_condition_group", params, socket) do
    parent_id = Map.get(params, "parent-id")

    # 创建一个新的复合条件组
    new_group = %{
      "type" => "compound",
      "operator" => "and",
      "conditions" => []
    }

    # 处理不同情况（与add_simple_condition类似）
    updated_condition =
      cond do
        # 如果是顶级条件且当前没有条件
        is_nil(parent_id) && is_nil(socket.assigns.current_condition) ->
          new_group

        # 如果是顶级条件但已有一个简单条件，则创建一个 AND 组合条件
        is_nil(parent_id) && socket.assigns.current_condition["type"] == "simple" ->
          %{
            "type" => "compound",
            "operator" => "and",
            "conditions" => [socket.assigns.current_condition, new_group]
          }

        # 如果是顶级条件且已有一个复合条件，则向该复合条件添加子条件组
        is_nil(parent_id) && socket.assigns.current_condition["type"] == "compound" ->
          updated_conditions = socket.assigns.current_condition["conditions"] ++ [new_group]
          Map.put(socket.assigns.current_condition, "conditions", updated_conditions)

        # 如果是子条件，则找到父条件并添加新的子条件组
        !is_nil(parent_id) ->
          # 递归函数，在嵌套条件中查找并更新父条件
          add_to_parent = fn condition, parent_id, recurse ->
            case condition do
              %{"type" => "compound", "conditions" => conditions} = compound ->
                if condition["id"] == parent_id do
                  # 找到了父条件，添加新的子条件组
                  Map.put(compound, "conditions", conditions ++ [new_group])
                else
                  # 递归查找子条件
                  updated_conditions = Enum.map(conditions, &recurse.(&1, parent_id, recurse))
                  Map.put(compound, "conditions", updated_conditions)
                end

              # 不是复合条件，返回原条件
              _ ->
                condition
            end
          end

          add_to_parent.(socket.assigns.current_condition, parent_id, add_to_parent)
      end

    {:noreply, assign(socket, :current_condition, updated_condition)}
  end

  def handle_event("delete_condition", %{"condition_id" => condition_id}, socket) do
    # 递归函数，在嵌套条件中查找并删除条件
    delete_condition = fn condition, condition_id, recurse ->
      case condition do
        %{"type" => "compound", "conditions" => conditions} = compound ->
          # 筛选出不等于condition_id的子条件
          filtered_conditions = Enum.reject(conditions, &(&1["id"] == condition_id))

          if length(filtered_conditions) == length(conditions) do
            # 如果没有找到要删除的条件，则递归查找子条件
            updated_conditions =
              Enum.map(filtered_conditions, &recurse.(&1, condition_id, recurse))

            Map.put(compound, "conditions", updated_conditions)
          else
            # 找到并删除了条件
            Map.put(compound, "conditions", filtered_conditions)
          end

        # 不是复合条件，返回原条件
        _ ->
          condition
      end
    end

    updated_condition =
      if socket.assigns.current_condition["id"] == condition_id do
        # 如果是顶级条件，则整个条件都被删除
        nil
      else
        # 否则递归查找并删除子条件
        delete_condition.(socket.assigns.current_condition, condition_id, delete_condition)
      end

    {:noreply, assign(socket, :current_condition, updated_condition)}
  end

  def handle_event(
        "update_condition_operator",
        %{"condition_id" => condition_id, "operator" => operator},
        socket
      ) do
    # 递归函数，在嵌套条件中查找并更新条件的操作符
    update_operator = fn condition, condition_id, operator, recurse ->
      cond do
        condition["id"] == condition_id ->
          # 找到目标条件，更新操作符
          Map.put(condition, "operator", operator)

        condition["type"] == "compound" ->
          # 递归查找子条件
          updated_conditions =
            Enum.map(condition["conditions"], &recurse.(&1, condition_id, operator, recurse))

          Map.put(condition, "conditions", updated_conditions)

        true ->
          # 其他情况，保持不变
          condition
      end
    end

    updated_condition =
      update_operator.(socket.assigns.current_condition, condition_id, operator, update_operator)

    {:noreply, assign(socket, :current_condition, updated_condition)}
  end

  def handle_event(
        "update_condition_source",
        %{"condition_id" => condition_id, "source_id" => source_id},
        socket
      ) do
    # 递归函数，在嵌套条件中查找并更新条件的源表单项
    update_source = fn condition, condition_id, source_id, recurse ->
      cond do
        condition["id"] == condition_id ->
          # 找到目标条件，更新源表单项
          Map.put(condition, "source_item_id", source_id)

        condition["type"] == "compound" ->
          # 递归查找子条件
          updated_conditions =
            Enum.map(condition["conditions"], &recurse.(&1, condition_id, source_id, recurse))

          Map.put(condition, "conditions", updated_conditions)

        true ->
          # 其他情况，保持不变
          condition
      end
    end

    updated_condition =
      update_source.(socket.assigns.current_condition, condition_id, source_id, update_source)

    {:noreply, assign(socket, :current_condition, updated_condition)}
  end

  def handle_event(
        "update_condition_value",
        %{"condition_id" => condition_id, "value" => value},
        socket
      ) do
    # 递归函数，在嵌套条件中查找并更新条件的值
    update_value = fn condition, condition_id, value, recurse ->
      cond do
        condition["id"] == condition_id ->
          # 找到目标条件，更新值
          Map.put(condition, "value", value)

        condition["type"] == "compound" ->
          # 递归查找子条件
          updated_conditions =
            Enum.map(condition["conditions"], &recurse.(&1, condition_id, value, recurse))

          Map.put(condition, "conditions", updated_conditions)

        true ->
          # 其他情况，保持不变
          condition
      end
    end

    updated_condition =
      update_value.(socket.assigns.current_condition, condition_id, value, update_value)

    {:noreply, assign(socket, :current_condition, updated_condition)}
  end

  def handle_event(
        "update_condition_group_type",
        %{"group_id" => group_id, "group_type" => group_type},
        socket
      ) do
    # 递归函数，在嵌套条件中查找并更新条件组的类型
    update_group_type = fn condition, group_id, group_type, recurse ->
      cond do
        condition["id"] == group_id && condition["type"] == "compound" ->
          # 找到目标条件组，更新类型
          Map.put(condition, "operator", group_type)

        condition["type"] == "compound" ->
          # 递归查找子条件
          updated_conditions =
            Enum.map(condition["conditions"], &recurse.(&1, group_id, group_type, recurse))

          Map.put(condition, "conditions", updated_conditions)

        true ->
          # 其他情况，保持不变
          condition
      end
    end

    updated_condition =
      update_group_type.(
        socket.assigns.current_condition,
        group_id,
        group_type,
        update_group_type
      )

    {:noreply, assign(socket, :current_condition, updated_condition)}
  end

  def handle_event("save_conditions", _params, socket) do
    form_item = socket.assigns.current_item
    condition_type = socket.assigns.condition_type
    condition = socket.assigns.current_condition

    # 根据条件类型更新表单项
    result =
      case condition_type do
        :visibility ->
          Forms.add_condition_to_form_item(form_item, condition, :visibility)

        :required ->
          Forms.add_condition_to_form_item(form_item, condition, :required)
      end

    case result do
      {:ok, _} ->
        # 更新成功，重新加载表单和表单项
        updated_form = Forms.get_form_with_items(socket.assigns.form.id)

        {:noreply,
         socket
         |> assign(:form, updated_form)
         |> assign(:form_items, updated_form.items)
         |> assign(:editing_conditions, false)
         |> assign(:current_item, nil)
         |> assign(:current_condition, nil)
         |> put_flash(:info, "条件规则已保存")}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, "条件规则保存失败: #{inspect(changeset.errors)}")}
    end
  end

  @impl true
  def handle_event("type_changed", %{"item" => %{"type" => type}}, socket) do
    {:noreply, assign(socket, :item_type, type)}
  end

  @impl true
  def handle_event("type_changed", %{"type" => type}, socket) do
    # 清除高亮状态，重置current_item，确保切换类型时不保留之前输入框的高亮状态
    {:noreply,
     socket
     |> assign(:item_type, type)
     |> assign(:current_item, %FormItem{})
     |> assign(:temp_label, nil)}
  end

  @impl true
  def handle_event("form_change", %{"form" => form_params} = params, socket) do
    # 处理表单整体的变化
    target = params["_target"]


    socket =
      cond do
        # 添加防御性检查，确保target是列表
        is_list(target) && (target == ["form", "title"] || List.last(target) == "title") ->
          # 存储表单标题，并写入日志
          title = form_params["title"]
          socket |> assign(:temp_title, title)

        is_list(target) &&
            (target == ["form", "description"] || List.last(target) == "description") ->
          # 存储表单描述，并写入日志
          description = form_params["description"]
          socket |> assign(:temp_description, description)

        # 处理表单项的标签字段
        is_list(target) && (target == ["form", "item", "label"] || List.last(target) == "label") ->
          label_value = get_in(form_params, ["item", "label"]) || ""
          # 同时更新临时标签和当前项的标签
          current_item = socket.assigns.current_item

          updated_item =
            if current_item, do: Map.put(current_item, :label, label_value), else: current_item

          socket
          |> assign(:temp_label, label_value)
          |> assign(:current_item, updated_item)

        true ->
          socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("form_change", %{"value" => value} = params, socket) do
    # 保存表单元素的值变化
    element_id = params["id"] || ""

    # 添加直接调试信息

    socket =
      cond do
        element_id == "form-title" || String.contains?(element_id, "title") ->
          # 存储表单标题，并写入日志

          socket
          |> assign(:temp_title, value)

        element_id == "form-description" || String.contains?(element_id, "description") ->
          # 存储表单描述，并写入日志

          socket
          |> assign(:temp_description, value)

        element_id == "edit-item-label" || element_id == "new-item-label" ||
          String.contains?(element_id, "item-label") || String.contains?(element_id, "label") ->
          # 存储表单项标签，并写入日志
          # 同时更新临时标签和当前项的标签
          current_item = socket.assigns.current_item

          updated_item =
            if current_item, do: Map.put(current_item, :label, value), else: current_item

          socket
          |> assign(:temp_label, value)
          |> assign(:current_item, updated_item)

        true ->
          socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("form_change", _params, socket) do
    # 仅用于处理表单变化，不需要更新状态
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_group", %{"group" => _group}, socket) do
    # 侧边栏分组折叠/展开的处理在前端JavaScript中完成
    # 这里只需返回不变的socket
    {:noreply, socket}
  end

  @impl true
  def handle_event("add_matrix_row", _params, socket) do
    current_item = socket.assigns.current_item

    # 获取当前所有行
    current_rows = current_item.matrix_rows || ["问题1", "问题2", "问题3"]
    next_idx = length(current_rows) + 1

    # 添加新行
    updated_item = Map.put(current_item, :matrix_rows, current_rows ++ ["问题#{next_idx}"])

    {:noreply, assign(socket, :current_item, updated_item)}
  end

  @impl true
  def handle_event("remove_matrix_row", %{"index" => index}, socket) do
    current_item = socket.assigns.current_item

    # 获取当前所有行
    current_rows = current_item.matrix_rows || ["问题1", "问题2", "问题3"]
    index = String.to_integer(index)

    # 确保至少保留一行
    if length(current_rows) > 1 do
      # 删除指定行
      updated_rows = List.delete_at(current_rows, index)
      updated_item = Map.put(current_item, :matrix_rows, updated_rows)

      {:noreply, assign(socket, :current_item, updated_item)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("add_matrix_column", _params, socket) do
    current_item = socket.assigns.current_item

    # 获取当前所有列
    current_columns = current_item.matrix_columns || ["选项A", "选项B", "选项C"]
    next_idx = length(current_columns)
    # A=65, B=66, ...
    column_letter = <<65 + next_idx::utf8>>

    # 添加新列
    updated_item =
      Map.put(current_item, :matrix_columns, current_columns ++ ["选项#{column_letter}"])

    {:noreply, assign(socket, :current_item, updated_item)}
  end

  @impl true
  def handle_event("remove_matrix_column", %{"index" => index}, socket) do
    current_item = socket.assigns.current_item

    # 获取当前所有列
    current_columns = current_item.matrix_columns || ["选项A", "选项B", "选项C"]
    index = String.to_integer(index)

    # 确保至少保留一列
    if length(current_columns) > 1 do
      # 删除指定列
      updated_columns = List.delete_at(current_columns, index)
      updated_item = Map.put(current_item, :matrix_columns, updated_columns)

      {:noreply, assign(socket, :current_item, updated_item)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("add_option", _params, socket) do
    current_options = socket.assigns.item_options
    # 使用字母A/B/C/D等作为选项标签
    next_idx = length(current_options)
    # A=65, B=66, ...
    option_letter = <<65 + next_idx::utf8>>
    # 确保新选项包含所有必要的键，特别是图片相关的键设为 nil
    new_option = %{
      id: Ecto.UUID.generate(),
      label: "选项#{option_letter}",
      value: "option_#{String.downcase(option_letter)}",
      image_id: nil,
      image_filename: nil
    }

    {:noreply, assign(socket, :item_options, current_options ++ [new_option])}
  end

  @impl true
  def handle_event("select_image_for_option", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)

    # 记录当前正在编辑的选项索引
    socket = assign(socket, :current_option_index, index)

    # 为此选项准备上传引用
    option_ref = "option-image-#{index}"

    socket =
      Phoenix.LiveView.allow_upload(socket, option_ref,
        accept: ~w(.jpg .jpeg .png .gif),
        max_entries: 1,
        max_file_size: 5_000_000
      )

    # 准备图片上传
    {:noreply, socket}
  end

  @impl true
  def handle_event("remove_image_from_option", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    options = socket.assigns.item_options

    if index >= 0 and index < length(options) do
      # 获取要移除图片的选项
      option = Enum.at(options, index)

      # 移除相关的图片信息
      updated_option =
        option
        |> Map.delete(:image_id)
        |> Map.delete(:image_filename)

      # 更新选项列表
      updated_options = List.replace_at(options, index, updated_option)

      # 如果有图片ID，尝试删除图片文件（异步，不等待结果）
      if option.image_id do
        old_image_id = option.image_id

        Task.start(fn ->
          case Upload.delete_file(old_image_id) do
            {:ok, _} -> :ok
            {:error, _reason} -> :error
          end
        end)
      end

      {:noreply, assign(socket, :item_options, updated_options)}
    else
      {:noreply, socket}
    end
  end

  # 取消图片上传模态框
  @impl true
  def handle_event("cancel_image_upload", _params, socket) do
    {:noreply, assign(socket, :current_option_index, nil)}
  end

  # 取消单个上传条目
  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    # 找出该ref对应的upload key
    option_index = socket.assigns.current_option_index
    option_ref = "option-image-#{option_index}"

    # 使用正确的upload key取消上传
    {:noreply, Phoenix.LiveView.cancel_upload(socket, option_ref, ref)}
  end

  # 验证上传
  @impl true
  def handle_event("validate_upload", _params, socket) do
    # 验证上传并更新socket
    {:noreply, socket}
  end

  # 处理图片上传完成事件
  @impl true
  def handle_event("upload_image", _params, socket) do
    option_index = socket.assigns.current_option_index
    options = socket.assigns.item_options

    # 确保索引有效
    if option_index >= 0 and option_index < length(options) do
      _option = Enum.at(options, option_index)
      option_ref = "option-image-#{option_index}"

      # 创建并配置该选项的上传引用
      socket =
        Phoenix.LiveView.allow_upload(socket, option_ref,
          accept: ~w(.jpg .jpeg .png .gif),
          max_entries: 1,
          max_file_size: 5_000_000
        )

      # 更新模态框状态
      {:noreply, socket}
    else
      # 索引无效
      {:noreply,
       socket
       |> put_flash(:error, "无效的选项索引")
       # 关闭模态框
       |> assign(:current_option_index, nil)}
    end
  end

  @impl true
  def handle_event("apply_upload_to_option", _params, socket) do
    option_index = socket.assigns.current_option_index
    options = socket.assigns.item_options
    current_item = socket.assigns.current_item


    # 确保索引有效
    if option_index >= 0 and option_index < length(options) do
      option = Enum.at(options, option_index)
      option_ref = "option-image-#{option_index}"

      # 检查是否有图片可上传
      if upload = socket.assigns.uploads[option_ref] do

        if upload.entries != [] do
          form_id = socket.assigns.form.id
          # 如果表单项还没有保存，则使用临时ID
          form_item_id =
            if current_item && current_item.id,
              do: current_item.id,
              else: "temp_#{Ecto.UUID.generate()}"


          # 处理图片上传
          upload_results =
            Phoenix.LiveView.consume_uploaded_entries(socket, option_ref, fn %{path: path},
                                                                             entry ->
              # 存储图片文件
              ext = Path.extname(entry.client_name)
              filename = "#{Ecto.UUID.generate()}#{ext}"
              dest_path = Path.join([:code.priv_dir(:my_app), "static", "uploads", filename])

              # 确保目标目录存在
              File.mkdir_p!(Path.dirname(dest_path))

              # 复制文件到目标位置
              File.cp!(path, dest_path)

              # 如果选项有旧图片，尝试删除
              if option.image_id do
                old_image_id = option.image_id

                Task.start(fn ->
                  case Upload.delete_file(old_image_id) do
                    {:ok, _} -> :ok
                    {:error, _reason} -> :error
                  end
                end)
              end

              case Upload.save_uploaded_file(form_id, form_item_id, %{
                     original_filename: entry.client_name,
                     filename: filename,
                     path: "/uploads/#{filename}",
                     content_type: entry.client_type,
                     size: entry.client_size
                   }) do
                {:ok, file} ->
                  {:ok, %{id: file.id, filename: filename}}

                {:error, changeset} ->
                  error_message =
                    changeset.errors
                    |> Enum.map(fn {field, {msg, _}} -> "#{field}: #{msg}" end)
                    |> Enum.join(", ")

                  {:error, "图片保存失败: #{error_message}"}
              end
            end)


          # 根据上传结果更新选项
          case upload_results do
            # 直接匹配 Map 列表
            [%{id: image_id, filename: filename}] ->
              # 更新选项的图片信息
              updated_option =
                Map.merge(option, %{
                  image_id: image_id,
                  image_filename: filename
                })


              # 更新选项列表
              updated_options = List.replace_at(options, option_index, updated_option)

              # 同时更新 current_item 中的选项
              updated_current_item =
                if current_item do
                  %{current_item | options: updated_options}
                else
                  current_item
                end

              # 关闭图片上传模态框并更新状态
              {:noreply,
               socket
               |> assign(:item_options, updated_options)
               |> assign(:current_item, updated_current_item)
               # 关闭模态框
               |> assign(:current_option_index, nil)
               |> put_flash(:info, "图片上传成功！")}

            _ ->

              {:noreply,
               socket
               |> put_flash(:error, "图片上传或保存失败")}
          end
        else

          {:noreply,
           socket
           |> put_flash(:error, "请先选择要上传的图片")}
        end
      else

        {:noreply,
         socket
         |> put_flash(:error, "上传组件未准备好")}
      end
    else
      # 索引无效
      {:noreply,
       socket
       |> put_flash(:error, "无效的选项索引")
       # 关闭模态框
       |> assign(:current_option_index, nil)}
    end
  end

  @impl true
  def handle_event("remove_option", %{"index" => index}, socket) do
    index = String.to_integer(index)
    current_options = socket.assigns.item_options
    updated_options = List.delete_at(current_options, index)

    {:noreply, assign(socket, :item_options, updated_options)}
  end

  @impl true
  def handle_event("save_item", %{"item" => item_params} = _params, socket) do

    current_item_at_start = socket.assigns.current_item

    _current_item_options_at_start =
      if current_item_at_start,
        do: Map.get(current_item_at_start, :options),
        else: "current_item is nil"



    form = socket.assigns.form
    current_item = socket.assigns.current_item
    editing_item_id = socket.assigns.editing_item_id
    # 使用当前socket中的选项
    item_options = socket.assigns.item_options


    # 处理 item 参数 (类型转换, required 标准化)
    clean_item_params = process_item_params(item_params)
    item_type = clean_item_params["type"]

    # 区分是更新还是添加
    if current_item && (current_item.id || editing_item_id) do
      # 更新现有表单项
      item_id_to_update = editing_item_id || current_item.id
      existing_item = Forms.get_form_item(item_id_to_update)

      if existing_item do

        # 如果是矩阵类型，确保行列存在
        clean_item_params =
          if item_type == :matrix do
            rows = Map.get(clean_item_params, "matrix_rows") || existing_item.matrix_rows || []

            cols =
              Map.get(clean_item_params, "matrix_columns") || existing_item.matrix_columns || []

            Map.merge(clean_item_params, %{"matrix_rows" => rows, "matrix_columns" => cols})
          else
            clean_item_params
          end

        case Forms.update_form_item(existing_item, clean_item_params) do
          {:ok, updated_item} -> :ok
            # 直接使用当前选项状态，不需要再处理图片上传
            # 因为每个选项的图片已经在apply_upload_to_option中处理过了
            process_options(updated_item, item_options)

            # 强制重新加载表单数据
            socket = reload_form_and_update_socket(socket, form.id, "表单项已更新")

            {:noreply,
             socket
             |> assign(:current_item, nil)
             |> assign(:editing_item, false)
             |> assign(:editing_item_id, nil)
             # 清空临时选项
             |> assign(:item_options, [])
             # 清除当前选项索引
             |> assign(:current_option_index, nil)}

          {:error, changeset} -> :error
            error_msg = inspect(changeset.errors)
            {:noreply, put_flash(socket, :error, "表单项更新失败: #{error_msg}")}
        end
      else
        {:noreply, put_flash(socket, :error, "要更新的表单项不存在")}
      end
    else
      # 添加新表单项
      clean_params = process_item_params(item_params)

      case Forms.add_form_item(form, clean_params) do
        {:ok, new_item} -> :ok

          # 直接使用当前选项状态，不需要再处理图片上传
          # 因为每个选项的图片已经在apply_upload_to_option中处理过了
          process_options(new_item, item_options)

          # 强制重新加载表单数据
          socket = reload_form_and_update_socket(socket, form.id, "表单项已添加")

          {:noreply,
           socket
           |> assign(:current_item, nil)
           |> assign(:editing_item, false)
           |> assign(:editing_item_id, nil)
           # 清空临时选项
           |> assign(:item_options, [])
           # 清除当前选项索引
           |> assign(:current_option_index, nil)}

        {:error, changeset} ->
          error_msg = inspect(changeset.errors)

          {:noreply,
           socket
           |> put_flash(:error, "表单项添加失败: #{error_msg}")}
      end
    end
  end

  @impl true
  def handle_event("delete_item", %{"id" => id}, socket) do
    item = Forms.get_form_item(id)

    if item do
      # 设置当前选择的表单项以便确认删除
      {:noreply, assign(socket, :delete_item_id, id)}
    else
      {:noreply, put_flash(socket, :error, "表单项不存在")}
    end
  end

  @impl true
  def handle_event("confirm_delete", _params, socket) do
    id = socket.assigns.delete_item_id
    item = Forms.get_form_item(id)

    if item do
      case Forms.delete_form_item(item) do
        {:ok, _} ->
          # 获取完整的表单包括关联项
          form_id = socket.assigns.form.id

          # 使用公共函数重新加载表单
          socket = reload_form_and_update_socket(socket, form_id, "表单项已删除")

          # 清除删除项ID
          {:noreply, assign(socket, :delete_item_id, nil)}

        {:error, _} ->
          {:noreply,
           socket
           |> assign(:delete_item_id, nil)
           |> put_flash(:error, "表单项删除失败")}
      end
    else
      {:noreply,
       socket
       |> assign(:delete_item_id, nil)
       |> put_flash(:error, "表单项不存在")}
    end
  end

  @impl true
  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, :delete_item_id, nil)}
  end

  @impl true
  def handle_event("reorder_items", %{"item_ids" => item_ids}, socket) do
    form_id = socket.assigns.form.id

    case Forms.reorder_form_items(form_id, item_ids) do
      :ok ->
        # 重新加载表单项
        updated_form = Forms.get_form(form_id)

        {:noreply,
         socket
         |> assign(:form, updated_form)
         |> assign(:form_items, updated_form.items)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "表单项排序失败: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event(
        "item_moved_to_page",
        %{"itemId" => item_id, "targetPageId" => page_id},
        socket
      ) do
    case Forms.move_item_to_page(item_id, page_id) do
      {:ok, _} ->
        # 重新加载表单
        updated_form = Forms.get_form(socket.assigns.form.id)

        {:noreply,
         socket
         |> assign(:form, updated_form)
         |> assign(:form_items, updated_form.items)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "移动表单项失败: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("publish_form", _params, socket) do
    form = socket.assigns.form

    if Enum.empty?(form.items) do
      {:noreply, put_flash(socket, :error, "表单至少需要一个表单项才能发布")}
    else
      # 显示确认提示
      {:noreply, assign(socket, :show_publish_confirm, true)}
    end
  end

  @impl true
  def handle_event("confirm_publish", _params, socket) do
    form = socket.assigns.form

    case Forms.publish_form(form) do
      {:ok, updated_form} ->
        {:noreply,
         socket
         |> assign(:form, updated_form)
         |> assign(:show_publish_confirm, false)
         |> put_flash(:info, "表单已发布")}

      {:error, :already_published} ->
        {:noreply,
         socket
         |> assign(:show_publish_confirm, false)
         |> put_flash(:info, "表单已经是发布状态")}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:show_publish_confirm, false)
         |> put_flash(:error, "表单发布失败: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("cancel_publish", _params, socket) do
    {:noreply, assign(socket, :show_publish_confirm, false)}
  end

  @impl true
  def handle_event("change_category", %{"category" => category}, socket) do
    # 将类别字符串转为原子
    category_atom = String.to_existing_atom(category)

    {:noreply,
     socket
     |> assign(:active_category, category_atom)
     # 切换类别时清空搜索
     |> assign(:search_term, nil)}
  end

  @impl true
  def handle_event("search_item_types", %{"search" => search_term}, socket) do
    filtered_types =
      if search_term == "" do
        # 空搜索恢复正常类别显示
        nil
      else
        Forms.search_form_item_types(search_term)
      end

    {:noreply,
     socket
     |> assign(:search_term, filtered_types)}
  end


  # 辅助函数

  # 处理表单项参数
  defp process_item_params(params) do
    # 确保所有键都是字符串
    params = normalize_params(params)

    # 类型转换
    params = convert_type_to_atom(params)

    # 必填项处理
    normalize_required_field(params)
  end

  # 检查矩阵类型控件是否有行和列

  # 确保所有键都是字符串
  defp normalize_params(params) do
    params
    |> Enum.map(fn {k, v} -> {to_string(k), v} end)
    |> Map.new()
  end

  # 将类型字符串转换为atom
  defp convert_type_to_atom(params) do
    case params["type"] do
      "text_input" ->
        Map.put(params, "type", :text_input)

      "textarea" ->
        Map.put(params, "type", :textarea)

      "radio" ->
        Map.put(params, "type", :radio)

      "checkbox" ->
        Map.put(params, "type", :checkbox)

      "dropdown" ->
        Map.put(params, "type", :dropdown)

      "rating" ->
        Map.put(params, "type", :rating)

      "number" ->
        Map.put(params, "type", :number)

      "email" ->
        Map.put(params, "type", :email)

      "phone" ->
        Map.put(params, "type", :phone)

      "date" ->
        Map.put(params, "type", :date)

      "time" ->
        Map.put(params, "type", :time)

      "region" ->
        Map.put(params, "type", :region)

      "matrix" ->
        Map.put(params, "type", :matrix)

      type when is_binary(type) ->
        Map.put(params, "type", String.to_existing_atom(type))

      _ ->
        params
    end
  end

  # 处理required字段的值
  defp normalize_required_field(params) do

    case params["required"] do
      "true" -> Map.put(params, "required", true)
      true -> Map.put(params, "required", true)
      "on" -> Map.put(params, "required", true)
      nil -> Map.put(params, "required", false)
      false -> Map.put(params, "required", false)
      "false" -> Map.put(params, "required", false)
      _ -> params
    end
  end


  # 处理选项 (公有函数，可被其他模块导入)
  def process_options(item, options_list) do

    # 先获取当前数据库中的选项以备参考（主要用于更新场景，判断是否需要删除旧选项）
    current_options =
      case MyApp.Repo.preload(item, :options).options do
        nil ->
          []

        options when is_list(options) ->
          options
      end


    # 直接使用传入的 options_list (可能已经包含处理过的图片信息)
    # 提取需要的字段来构建用于保存的参数 Map 列表
    options_to_save =
      options_list
      |> Enum.map(fn opt ->
        # 使用Map.get安全地获取字段，避免KeyError
        %{
          "label" => Map.get(opt, :label, ""),
          "value" => Map.get(opt, :value, ""),
          "image_id" => Map.get(opt, :image_id, nil),
          "image_filename" => Map.get(opt, :image_filename, nil)
        }
      end)
      |> Enum.filter(fn opt ->
        # 过滤掉完全空的选项（除非它有关联的图片）
        opt["label"] != "" || opt["value"] != "" || !is_nil(opt["image_id"])
      end)


    # 使用 Multi 来确保原子性：先删除旧选项，再添加新选项
    multi = Ecto.Multi.new()

    # 1. 删除旧选项
    multi =
      Enum.reduce(current_options, multi, fn option, multi_acc ->
        Ecto.Multi.delete(multi_acc, "delete_option_#{option.id}", option)
      end)

    # 2. 添加新选项 (使用新的 options_to_save 列表)
    multi =
      Enum.with_index(options_to_save, 1)
      |> Enum.reduce(multi, fn {option_params, index}, multi_acc ->
        # 添加 order 字段
        params_with_order = Map.put(option_params, "order", index)

        # 创建 ItemOption changeset
        changeset =
          MyApp.Forms.ItemOption.changeset(
            %MyApp.Forms.ItemOption{form_item_id: item.id},
            params_with_order
          )

        Ecto.Multi.insert(multi_acc, "insert_option_#{index}", changeset)
      end)

    # 执行事务
    case MyApp.Repo.transaction(multi) do
      {:ok, _result_map} ->
        # 重新加载并返回更新后的项目，确保选项已关联
        updated_item = Forms.get_form_item_with_options(item.id)
        updated_item

      {:error, _failed_operation, _failed_value, _changes_so_far} ->
        # 返回原始 item，或者可以考虑返回错误信息
        # 或者 {:error, ...}
        item
    end
  end

  # 公共函数：重新加载表单并更新socket
  defp reload_form_and_update_socket(socket, form_id, info_message) do
    # 强制重新加载，确保所有字段都已更新
    updated_form = Forms.get_form(form_id)


    # 收集所有页面的表单项
    all_form_items =
      Enum.flat_map(updated_form.pages, fn page ->
        # 提取每个页面的表单项
        page.items || []
      end)


    socket
    |> assign(:form, updated_form)
    # 使用从页面收集的表单项
    |> assign(:form_items, all_form_items)
    |> assign(:editing_form_info, false)
    |> put_flash(:info, info_message)
  end

  #
  # 页面管理相关函数都已移至前面相关的函数区域
  #

  # 辅助函数：显示选中的控件类型名称
  defp display_selected_type(nil), do: "未选择"
  defp display_selected_type("text_input"), do: "文本输入"
  defp display_selected_type("textarea"), do: "文本区域"
  defp display_selected_type("radio"), do: "单选按钮"
  defp display_selected_type("dropdown"), do: "下拉菜单"
  defp display_selected_type("checkbox"), do: "复选框"
  defp display_selected_type("rating"), do: "评分"
  defp display_selected_type("number"), do: "数字输入"
  defp display_selected_type("email"), do: "邮箱输入"
  defp display_selected_type("phone"), do: "电话号码"
  defp display_selected_type("date"), do: "日期选择"
  defp display_selected_type("time"), do: "时间选择"
  defp display_selected_type("region"), do: "地区选择"
  defp display_selected_type("matrix"), do: "矩阵题"
  defp display_selected_type("image_choice"), do: "图片选择"
  defp display_selected_type("file_upload"), do: "文件上传"
  defp display_selected_type(_), do: "未知类型"

  # 条件相关辅助函数（简化版）

  # 辅助函数：将上传错误转换为友好字符串
  defp error_to_string(:too_large), do: "文件太大"
  defp error_to_string(:too_many_files), do: "文件数量过多"
  defp error_to_string(:not_accepted), do: "文件类型不被接受"
  defp error_to_string(_), do: "无效的文件"

  # 格式化文件大小
  defp format_bytes(bytes) when is_integer(bytes) do
    cond do
      # 1 MB
      bytes >= 1_048_576 ->
        "#{Float.round(bytes / 1_048_576, 1)} MB"

      # 1 KB
      bytes >= 1024 ->
        "#{Float.round(bytes / 1024, 1)} KB"

      true ->
        "#{bytes} B"
    end
  end

  defp format_bytes(_), do: "未知大小"

  # 获取页面的表单项
  defp get_page_items(form, page) do
    if page do
      # 过滤出当前页面的表单项
      Enum.filter(form.items || [], fn item ->
        item.page_id == page.id
      end)
    else
      # 如果没有页面，返回所有表单项
      form.items || []
    end
  end

  # 注释掉未使用的查找函数
  # defp find_page(form, page_id) do
  #   Enum.find(form.pages || [], fn p -> p.id == page_id end)
  # end

  # 查找页面索引
  # defp find_page_index(form, page_id) do
  #   Enum.find_index(form.pages || [], fn p -> p.id == page_id end) || 0
  # end
end
