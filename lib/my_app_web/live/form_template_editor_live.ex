defmodule MyAppWeb.FormTemplateEditorLive do
  use MyAppWeb, :live_view
  import MyAppWeb.FormLive.ItemRendererComponent
  import MyAppWeb.FormComponents
  # 导入FormLive.Edit中的函数，特别是process_options
  # import MyAppWeb.FormLive.Edit, only: [process_options: 2]
  # === 假设你创建了以下 Helper 模块 ===
  import MyAppWeb.FormHelpers
  import MyAppWeb.DecorationHelpers
  # === End Helper 模块导入 ===
  alias MyApp.FormTemplates
  alias MyApp.Forms # 添加缺失的别名
  alias MyApp.Forms.FormItem
  alias MyApp.Upload # Ensure Upload alias is present
  # 添加 Logger 别名，因为 render 函数中的回退逻辑使用了它
  require Logger

  @max_file_size 5_000_000 # 5MB
  @allowed_image_types ~w(.jpg .jpeg .png .gif)

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    # 加载表单模板 (id 是 template_id)
    template = FormTemplates.get_template!(id) # 改回使用 FormTemplates

    # 使用新函数，根据 template.id 查找对应的 Form 记录
    form = Forms.get_form_by_template_id!(template.id)

    # 现在使用正确的 form.id 加载表单及其所有预加载数据
    form_with_data = Forms.get_form_with_full_preload(form.id)
    form_items = form_with_data.items || [] # 提取表单项列表

    # 获取或初始化装饰元素列表
    decoration = Map.get(template, :decoration, []) |> ensure_list() # Use Map.get for safe access & ensure list

    socket = socket
      |> assign(:template, template)
      |> assign(:structure, template.structure || [])
      |> assign(:decoration, decoration) # 页面装饰元素列表
      |> assign(:form_items, form_items) # 使用从 form_with_data 加载的 items
      |> assign(:editing_item_id, nil)
      |> assign(:item_type, "text_input")
      |> assign(:decoration_category, :content) # 默认选中内容装饰分类
      |> assign(:decoration_type, "title") # 默认装饰元素类型
      |> assign(:editing_decoration_id, nil) # 当前正在编辑的装饰元素ID
      |> assign(:current_decoration, nil) # 当前编辑的装饰元素
      |> assign(:decoration_search_term, nil) # 装饰元素搜索关键词
      |> assign(:delete_decoration_id, nil) # 要删除的装饰元素ID
      |> assign(:search_term, nil)
      |> assign(:tab_title, "结构设计")
      |> assign(:active_tab, "structure") # 添加：默认激活结构设计标签页
      |> assign(:active_category, :basic)   # 添加：默认激活基础控件类别
      |> assign(:delete_item_id, nil) # 添加：初始化 delete_item_id
      |> assign(:editing_logic_item_id, nil) # 添加：初始化逻辑编辑项ID
      |> assign(:logic_type, nil)            # 添加：初始化逻辑类型
      |> assign(:logic_target_id, nil)       # 添加：初始化逻辑目标ID
      |> assign(:logic_condition, nil)       # 添加：初始化逻辑条件
      # --- Explicitly assign the config name to assigns, trying to fix KeyError ---
      # --- Add allow_upload ---
      # --- Add allow_upload ---

    # 打印加载的表单项及其选项 (来自 form_with_data)
    # IO.inspect(socket.assigns.form_items, label: "Loaded Form Items via get_form_with_full_preload")

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
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    # 标签页之间切换
    tab_titles = %{
      "structure" => "结构设计",
      "conditions" => "条件逻辑",
      "decoration" => "页面装饰"
    }

    {:noreply,
      socket
      |> assign(:active_tab, tab)
      |> assign(:tab_title, Map.get(tab_titles, tab, "模板编辑"))
    }
  end

  @impl true
  def handle_event("next_tab", _params, socket) do
    # 移动到下一个标签页
    next_tab = case socket.assigns.active_tab do
      "structure" -> "conditions"
      "conditions" -> "decoration"
      "decoration" -> "structure" # 循环回到第一个标签
      _ -> "structure"
    end

    # 执行标签变更
    handle_event("change_tab", %{"tab" => next_tab}, socket)
  end

  @impl true
  def handle_event("prev_tab", _params, socket) do
    # 移动到上一个标签页
    prev_tab = case socket.assigns.active_tab do
      "structure" -> "decoration" # 循环到最后一个标签
      "conditions" -> "structure"
      "decoration" -> "conditions"
      _ -> "structure"
    end

    # 执行标签变更
    handle_event("change_tab", %{"tab" => prev_tab}, socket)
  end

  # 添加从FormLive.Edit复用的事件处理函数

  @impl true
  def handle_event("change_category", %{"category" => category}, socket) do
    # 将类别字符串转为原子
    category_atom = String.to_existing_atom(category)

    {:noreply,
      socket
      |> assign(:active_category, category_atom)
      |> assign(:search_term, nil) # 切换类别时清空搜索
    }
  end

  @impl true
  def handle_event("search_item_types", %{"search" => search_term}, socket) do
    filtered_types = if search_term == "" do
      nil # 空搜索恢复正常类别显示
    else
      ["text_input", "textarea", "radio", "checkbox", "dropdown", "rating",
      "number", "email", "phone", "date", "time", "region", "matrix",
      "image_choice", "file_upload"]
      |> Enum.filter(fn type ->
        String.contains?(type, search_term) ||
        String.contains?(display_selected_type(type), search_term)
      end)
    end

    {:noreply,
      socket
      |> assign(:search_term, filtered_types)
    }
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
  def handle_event("add_item", _params, socket) do
    # 使用当前选择的控件类型
    item_type = socket.assigns.item_type || "text_input"
    type_atom = case item_type do
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
    default_label = case item_type do
      "radio" -> "新单选问题"
      "checkbox" -> "新复选问题"
      "matrix" -> "新矩阵题"
      "dropdown" -> "新下拉菜单"
      "rating" -> "新评分题"
      _ -> "新问题"
    end

    # 准备要添加到模板结构的新项目
    new_item = %{
      "id" => Ecto.UUID.generate(),
      "type" => item_type,
      "label" => default_label,
      "required" => false,
      "description" => ""
    }

    # 根据控件类型设置特定属性
    new_item = cond do
      item_type == "matrix" ->
        new_item
        |> Map.put("matrix_rows", ["问题1", "问题2", "问题3"])
        |> Map.put("matrix_columns", ["选项A", "选项B", "选项C"])
        |> Map.put("matrix_type", "single")

      item_type == "image_choice" ->
        new_item
        |> Map.put("selection_type", "single")
        |> Map.put("image_caption_position", "bottom")

      item_type in ["radio", "checkbox", "dropdown"] ->
        new_item
        |> Map.put("options", [
          %{"id" => Ecto.UUID.generate(), "label" => "选项A", "value" => "option_a"},
          %{"id" => Ecto.UUID.generate(), "label" => "选项B", "value" => "option_b"}
        ])

      true -> new_item
    end

    # 添加新项目到结构中
    updated_structure = socket.assigns.structure ++ [new_item]

    # 保存更新后的模板结构
    case FormTemplates.update_template(socket.assigns.template, %{structure: updated_structure}) do
      {:ok, updated_template} ->
        {:noreply,
          socket
          |> assign(:template, updated_template)
          |> assign(:structure, updated_template.structure)
          |> put_flash(:info, "已添加新控件")
        }

      {:error, _changeset} ->
        {:noreply,
          socket
          |> put_flash(:error, "无法添加新控件")
        }
    end
  end

  @impl true
  def handle_event("delete_item", %{"id" => id}, socket) do
    # 设置当前选择的表单项以便确认删除
    {:noreply, assign(socket, :delete_item_id, id)}
  end

  @impl true
  def handle_event("confirm_delete", _params, socket) do
    id = socket.assigns.delete_item_id

    # 从结构中移除指定ID的项目
    updated_structure = Enum.reject(socket.assigns.structure, fn item ->
      Map.get(item, "id") == id
    end)

    # 保存更新后的模板结构
    case FormTemplates.update_template(socket.assigns.template, %{structure: updated_structure}) do
      {:ok, updated_template} ->
        {:noreply,
          socket
          |> assign(:template, updated_template)
          |> assign(:structure, updated_template.structure)
          |> assign(:delete_item_id, nil)
          |> put_flash(:info, "控件已删除")
        }

      {:error, _changeset} ->
        {:noreply,
          socket
          |> assign(:delete_item_id, nil)
          |> put_flash(:error, "无法删除控件")
        }
    end
  end

  @impl true
  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, :delete_item_id, nil)}
  end

  @impl true
  def handle_event("open_logic_editor", %{"id" => item_id}, socket) do
    # 获取当前标签页
    current_tab = socket.assigns.active_tab

    # 查找要编辑的项目
    item = Enum.find(socket.assigns.structure, fn item -> item["id"] == item_id end)

    # 获取当前项目的逻辑（如果有的话）
    existing_logic = Map.get(item, "logic", nil)

    # 如果不在条件逻辑标签页，先切换到该标签页
    socket = if current_tab != "conditions" do
      # 设置标签页标题
      tab_titles = %{
        "structure" => "结构设计",
        "conditions" => "条件逻辑",
        "decoration" => "页面装饰"
      }

      socket
      |> assign(:active_tab, "conditions")
      |> assign(:tab_title, Map.get(tab_titles, "conditions", "条件逻辑"))
    else
      socket
    end

    # 打开逻辑编辑器
    {:noreply,
      socket
      |> assign(:editing_logic_item_id, item_id)
      |> assign(:logic_type, Map.get(existing_logic || %{}, "type", "jump"))
      |> assign(:logic_target_id, Map.get(existing_logic || %{}, "target_id", nil))
      |> assign(:logic_condition, Map.get(existing_logic || %{}, "condition", nil))
    }
  end

  @impl true
  def handle_event("close_logic_editor", _params, socket) do
    # 关闭逻辑编辑器
    {:noreply,
      socket
      |> assign(:editing_logic_item_id, nil)
      |> assign(:logic_type, nil)
      |> assign(:logic_target_id, nil)
      |> assign(:logic_condition, nil)
    }
  end

  @impl true
  def handle_event("save_logic", %{"logic" => logic_params}, socket) do
    item_id = socket.assigns.editing_logic_item_id

    # 仅在编辑项目存在时处理
    if item_id do
      # 查找并更新对应的表单项
      updated_structure = Enum.map(socket.assigns.structure, fn item ->
        if item["id"] == item_id do
          # 构建完整的逻辑结构
          logic = %{
            "type" => logic_params["type"],
            "target_id" => logic_params["target_id"],
            "condition" => %{
              "operator" => logic_params["condition_operator"],
              "value" => logic_params["condition_value"]
            }
          }

          # 将逻辑添加到表单项
          Map.put(item, "logic", logic)
        else
          item
        end
      end)

      # 保存更新后的模板结构
      case FormTemplates.update_template(socket.assigns.template, %{structure: updated_structure}) do
        {:ok, updated_template} ->
          {:noreply,
            socket
            |> assign(:template, updated_template)
            |> assign(:structure, updated_template.structure)
            |> assign(:editing_logic_item_id, nil)
            |> assign(:logic_type, nil)
            |> assign(:logic_target_id, nil)
            |> assign(:logic_condition, nil)
            |> put_flash(:info, "逻辑规则已保存")
          }

        {:error, _changeset} ->
          {:noreply,
            socket
            |> put_flash(:error, "无法保存逻辑规则")
          }
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("change_logic_type", %{"type" => logic_type}, socket) do
    {:noreply, assign(socket, :logic_type, logic_type)}
  end

  # 页面装饰相关的事件处理函数

  @impl true
  def handle_event("change_decoration_category", %{"category" => category}, socket) do
    # 将类别字符串转为原子
    category_atom = String.to_existing_atom(category)

    {:noreply,
     socket
     |> assign(:decoration_category, category_atom)
     |> assign(:decoration_search_term, nil) # 切换类别时清空搜索
    }
  end

  @impl true
  def handle_event("decoration_type_changed", %{"type" => type}, socket) do
    {:noreply, assign(socket, :decoration_type, type)}
  end

  @impl true
  def handle_event("add_decoration_element", _params, socket) do
    # 使用当前选择的装饰元素类型
    decoration_type = socket.assigns.decoration_type

    # 创建新的装饰元素
    new_element = case decoration_type do
      "title" ->
        %{
          "id" => Ecto.UUID.generate(),
          "type" => "title",
          "title" => "新标题",
          "level" => 2,
          "align" => "left"
        }

      "paragraph" ->
        %{
          "id" => Ecto.UUID.generate(),
          "type" => "paragraph",
          "content" => "这是一个段落内容。在这里填写文字说明。"
        }

      "section" ->
        %{
          "id" => Ecto.UUID.generate(),
          "type" => "section",
          "title" => "章节标题",
          "divider_style" => "solid"
        }

      "explanation" ->
        %{
          "id" => Ecto.UUID.generate(),
          "type" => "explanation",
          "content" => "这里是重要说明内容。",
          "note_type" => "info"
        }

      "header_image" ->
        %{
          "id" => Ecto.UUID.generate(),
          "type" => "header_image",
          "image_url" => "",
          "height" => "300px"
        }

      "inline_image" ->
        %{
          "id" => Ecto.UUID.generate(),
          "type" => "inline_image",
          "image_url" => "",
          "caption" => "图片说明",
          "width" => "80%",
          "align" => "center"
        }

      "spacer" ->
        %{
          "id" => Ecto.UUID.generate(),
          "type" => "spacer",
          "height" => "2rem"
        }

      _ ->
        %{
          "id" => Ecto.UUID.generate(),
          "type" => decoration_type
        }
    end

    # 添加新元素到装饰元素列表
    updated_decoration = socket.assigns.decoration ++ [new_element]

    # 保存更新后的模板
    case FormTemplates.update_template(socket.assigns.template, %{decoration: updated_decoration}) do
      {:ok, updated_template} ->
        {:noreply,
          socket
          |> assign(:template, updated_template)
          |> assign(:decoration, updated_template.decoration)
          |> put_flash(:info, "已添加装饰元素")
        }

      {:error, _changeset} ->
        {:noreply,
          socket
          |> put_flash(:error, "无法添加装饰元素")
        }
    end
  end

  @impl true
  def handle_event("edit_decoration_element", %{"id" => id}, socket) do
    # Find the decoration element by ID
    case find_decoration_and_index(socket.assigns.decoration, id) do
      {decoration, _index} ->
        # === START CHANGE ===
        # Check if it's an image type decoration
        elem_type = decoration["type"] || decoration[:type] # Get type consistently
        is_image_decoration = elem_type in ["header_image", "inline_image", :header_image, :inline_image]

        socket =
          if is_image_decoration do
            # Generate dynamic config name only for image types
            config_name = String.to_atom("decoration-#{id}")
            IO.puts("Allowing upload for image config: #{inspect(config_name)}")
            # Allow upload for this specific image decoration instance
            socket
            |> allow_upload(config_name,
              accept: @allowed_image_types,
              max_entries: 1,
              max_file_size: @max_file_size,
              auto_upload: false # Match Edit.ex, consume on save
            )
            |> assign(:current_upload_config_name, config_name) # Store config name
          else
            # Not an image decoration, ensure upload config name is nil
            IO.puts("Not an image decoration, clearing upload config.")
            assign(socket, :current_upload_config_name, nil)
          end
        # === END CHANGE ===

        {:noreply,
          socket
          |> assign(:editing_decoration_id, id)
          |> assign(:current_decoration, decoration) # Assign the full decoration map
        }

      nil ->
        # Decoration not found
        {:noreply, put_flash(socket, :error, "找不到要编辑的装饰元素")}
    end
  end

  @impl true
  def handle_event("cancel_edit_decoration_element", _params, socket) do
    {:noreply,
      socket
      |> assign(:editing_decoration_id, nil)
      |> assign(:current_decoration, nil)
      |> assign(:current_upload_config_name, nil) # Clear upload config name
    }
  end

  @impl true
  def handle_event("cancel_decoration_upload", %{"ref" => ref, "config_name" => config_name_str}, socket) do
    config_name = String.to_atom(config_name_str)
    {:noreply, cancel_upload(socket, config_name, ref)}
  end

  @impl true
  def handle_event("save_decoration_element", %{"id" => decoration_id, "decoration" => decoration_params}, socket) do
    IO.inspect(decoration_params, label: "Raw save_decoration_element params")

    %{template: template, decoration: decorations} = socket.assigns

    # Find the original decoration and its index
    case find_decoration_and_index(decorations, decoration_id) do
      {original_decoration, index} ->
        # Generate dynamic config name for potential consumption
        config_name = String.to_atom("decoration-#{decoration_id}")

        # 1. Consume uploads BEFORE merging params
        # TODO: Replace with call to new consume_decoration_upload helper
        # upload_path = consume_decoration_upload(socket, config_name, template.id, original_decoration)
        upload_result = consume_decoration_upload(socket, config_name, template.id, original_decoration) # Placeholder call

        # 2. Prepare final params based on upload result
        case upload_result do
           {:ok, upload_path} ->
             # If upload happened, use its path and remove any URL from form params
             final_params =
               decoration_params
               |> Map.put("image_url", upload_path)
               |> Map.drop(["_csrf_token", "_target", "_uploads"]) # Clean up Phoenix params
               |> stringify_keys() # Ensure keys are strings

             IO.inspect(final_params, label: "Final params after successful upload consumption")

             # Proceed with merging and saving
             merge_and_save_decoration(socket, template, decorations, index, original_decoration, final_params)

           :no_upload ->
              # No upload happened, clean up form params, keep existing/form URL
              final_params =
                decoration_params
                |> Map.drop(["_csrf_token", "_target", "_uploads"])
                |> stringify_keys()

              IO.inspect(final_params, label: "Final params (no upload)")

             # Proceed with merging and saving
             merge_and_save_decoration(socket, template, decorations, index, original_decoration, final_params)

           {:error, reason} ->
              IO.puts("Upload consumption failed: #{inspect(reason)}")
             # Keep editor open and show error
             {:noreply,
               socket
               |> assign(:editing_decoration_id, decoration_id) # Keep editor open on error
               # Maybe update current_decoration with attempted params?
               |> put_flash(:error, "图片处理失败: #{reason}")
             }
        end

      nil ->
        # Decoration not found
        {:noreply, put_flash(socket, :error, "找不到要保存的装饰元素")}
    end
  end

  # Helper to merge params and save the template (extracted from save_decoration_element)
  defp merge_and_save_decoration(socket, template, decorations, index, original_decoration, final_params) do
     # 获取装饰元素ID
     decoration_id = original_decoration["id"] || original_decoration[:id]
     # 3. Merge final params with original (preserving ID, type)
     # Important: Ensure essential keys like 'id' and 'type' are preserved
     # and merge logic handles potential nil values from the form correctly.
     # Prioritize image_url from final_params if it exists (means successful upload)
     updated_decoration_item = Map.merge(original_decoration, final_params)

     # Ensure required fields have fallbacks if cleared by form, but respect uploaded path
     updated_decoration_item =
        if Map.has_key?(final_params, "image_url") do
          updated_decoration_item # Keep the image_url from final_params (upload)
        else
          # No upload, ensure image_url has a fallback if removed by form
          Map.put(updated_decoration_item, "image_url", Map.get(final_params, "image_url") || Map.get(original_decoration, "image_url") || Map.get(original_decoration, :image_url) || "")
        end

     # 4. Update the list
     updated_decorations = List.replace_at(decorations, index, updated_decoration_item)

     # 5. Save to DB
     case FormTemplates.update_template(template, %{decoration: updated_decorations}) do
       {:ok, updated_template} ->
         {:noreply,
           socket
           |> assign(:template, updated_template)
           |> assign(:decoration, updated_decorations)
           |> assign(:editing_decoration_id, nil) # Close editor
           |> assign(:current_decoration, nil)
           |> assign(:current_upload_config_name, nil) # Clear upload config name
           |> put_flash(:info, "装饰元素已保存")
         }
       {:error, changeset} ->
          IO.inspect(changeset, label: "Template Update Error")
         {:noreply,
           socket
           |> assign(:editing_decoration_id, decoration_id) # Keep editor open on error
           |> assign(:current_decoration, updated_decoration_item) # Show potentially invalid state
           |> put_flash(:error, "保存装饰元素失败")
         }
     end
  end

  @impl true
  def handle_event("delete_decoration_element", %{"id" => id}, socket) do
    # 找到要删除的装饰元素
    updated_decoration = Enum.reject(socket.assigns.decoration, fn elem ->
      (elem["id"] || elem[:id]) == id
    end)

    # 保存更新后的模板
    case FormTemplates.update_template(socket.assigns.template, %{decoration: updated_decoration}) do
      {:ok, updated_template} ->
        {:noreply,
          socket
          |> assign(:template, updated_template)
          |> assign(:decoration, updated_decoration)
          |> put_flash(:info, "装饰元素已删除")
        }

      {:error, _changeset} ->
        {:noreply,
          socket
          |> put_flash(:error, "无法删除装饰元素")
        }
    end
  end

  @impl true
  def handle_event("update_decoration_order", %{"ordered_ids" => ordered_ids}, socket) do
    # 获取当前模板和装饰元素列表
    %{template: template, decoration: current_decoration} = socket.assigns

    # 创建一个ID到装饰元素的映射
    id_to_element_map = Enum.reduce(current_decoration, %{}, fn elem, acc ->
      elem_id = elem["id"] || elem[:id]
      if elem_id, do: Map.put(acc, elem_id, elem), else: acc
    end)

    # 按新顺序重组装饰元素
    reordered_elements = Enum.map(ordered_ids, fn id ->
      Map.get(id_to_element_map, id)
    end)
    |> Enum.filter(&(&1 != nil))

    # 处理可能不在ordered_ids中的项
    missing_elements = Enum.filter(current_decoration, fn elem ->
      elem_id = elem["id"] || elem[:id]
      elem_id && !Enum.member?(ordered_ids, elem_id)
    end)

    # 合并重排序的项和缺失的项
    updated_decoration = reordered_elements ++ missing_elements

    # 保存更新后的模板
    case FormTemplates.update_template(template, %{decoration: updated_decoration}) do
      {:ok, updated_template} ->
        {:noreply,
          socket
          |> assign(:template, updated_template)
          |> assign(:decoration, updated_decoration)
          |> put_flash(:info, "装饰元素顺序已更新")
        }

      {:error, _changeset} ->
        {:noreply,
          socket
          |> put_flash(:error, "无法更新装饰元素顺序")
        }
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="form-editor-container">

      <!-- 模板编辑页面 -->
      <div style="display: flex; max-width: 100%; overflow-hidden;">
        <!-- 左侧控件类型选择栏 - 仅在结构设计标签页显示 -->
        <div style={"flex: 0 0 16rem; border-right: 1px solid #e5e7eb; background-color: white; padding: 1rem; overflow-y: auto; height: calc(100vh - 4rem); #{if @active_tab != "structure", do: "display: none;"}"}>
          <h2 style="font-size: 1.125rem; font-weight: 500; margin-bottom: 1rem;">控件类型</h2>

          <!-- 分类标签 -->
          <div style="display: flex; border-bottom: 1px solid #e5e7eb; margin-bottom: 1rem;" data-test-id="form-item-category-selector">
            <button
              phx-click="change_category"
              phx-value-category="basic"
              data-category="basic"
              style={"padding: 0.5rem 0.75rem; border: none; background: none; font-size: 0.875rem; font-weight: 500; cursor: pointer; border-bottom: 2px solid #{if @active_category == :basic, do: "#4f46e5", else: "transparent"}; color: #{if @active_category == :basic, do: "#4f46e5", else: "#6b7280"}; display: flex; align-items: center; gap: 0.375rem;"}
            >
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.25rem; height: 1.25rem;">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 3v4M3 5h4M6 17v4m-2-2h4m5-16l2.286 6.857L21 12l-5.714 2.143L13 21l-2.286-6.857L5 12l5.714-2.143L13 3z" />
              </svg>
              基础控件
            </button>
            <button
              phx-click="change_category"
              phx-value-category="personal"
              data-category="personal"
              style={"padding: 0.5rem 0.75rem; border: none; background: none; font-size: 0.875rem; font-weight: 500; cursor: pointer; border-bottom: 2px solid #{if @active_category == :personal, do: "#4f46e5", else: "transparent"}; color: #{if @active_category == :personal, do: "#4f46e5", else: "#6b7280"}; display: flex; align-items: center; gap: 0.375rem;"}
            >
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.25rem; height: 1.25rem;">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
              </svg>
              个人信息
            </button>
            <button
              phx-click="change_category"
              phx-value-category="advanced"
              data-category="advanced"
              style={"padding: 0.5rem 0.75rem; border: none; background: none; font-size: 0.875rem; font-weight: 500; cursor: pointer; border-bottom: 2px solid #{if @active_category == :advanced, do: "#4f46e5", else: "transparent"}; color: #{if @active_category == :advanced, do: "#4f46e5", else: "#6b7280"}; display: flex; align-items: center; gap: 0.375rem;"}
            >
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.25rem; height: 1.25rem;">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19.428 15.428a2 2 0 00-1.022-.547l-2.387-.477a6 6 0 00-3.86.517l-.318.158a6 6 0 01-3.86.517L6.05 15.21a2 2 0 00-1.806.547M8 4h8l-1 1v5.172a2 2 0 00.586 1.414l5 5c1.26 1.26.367 3.414-1.415 3.414H4.828c-1.782 0-2.674-2.154-1.414-3.414l5-5A2 2 0 009 10.172V5L8 4z" />
              </svg>
              高级控件
            </button>
          </div>

          <!-- 控件类型搜索 -->
          <div style="margin-bottom: 1rem;">
            <div style="position: relative;">
              <input
                type="text"
                placeholder="搜索控件类型..."
                style="width: 100%; padding: 0.5rem 0.75rem; padding-left: 2rem; border: 1px solid #d1d5db; border-radius: 0.375rem; font-size: 0.875rem;"
                phx-keyup="search_item_types"
                phx-key="Enter"
                name="search"
              />
              <div style="position: absolute; left: 0.5rem; top: 0.5rem; color: #9ca3af;">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor" style="width: 1.25rem; height: 1.25rem;">
                  <path fill-rule="evenodd" d="M8 4a4 4 0 100 8 4 4 0 000-8zM2 8a6 6 0 1110.89 3.476l4.817 4.817a1 1 0 01-1.414 1.414l-4.816-4.816A6 6 0 012 8z" clip-rule="evenodd" />
                </svg>
              </div>
            </div>
          </div>

          <!-- 渲染控件类型列表 -->
          <%= if is_nil(@search_term) do %>
            <!-- 分类显示 -->
            <%= if @active_category == :basic do %>
              <div style="margin-bottom: 1rem;">
                <h3 style="font-size: 1rem; font-weight: 500; margin-bottom: 0.5rem; color: #4b5563;">基础控件</h3>
                <div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 0.5rem;">
                  <button
                    type="button"
                    phx-click="type_changed"
                    phx-value-type="text_input"
                    data-test-id="item-type-text_input"
                    style={"display: flex; flex-direction: column; align-items: center; padding: 0.75rem; border: 1px solid #{if @item_type == "text_input", do: "#4f46e5", else: "#e5e7eb"}; border-radius: 0.375rem; background-color: #{if @item_type == "text_input", do: "#f5f3ff", else: "white"}; cursor: pointer; text-align: center; color: #{if @item_type == "text_input", do: "#4f46e5", else: "#1f2937"};"}
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.5rem; height: 1.5rem; margin-bottom: 0.25rem;">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                    </svg>
                    <div style="font-size: 0.75rem; white-space: nowrap;">文本输入</div>
                  </button>

                  <button
                    type="button"
                    phx-click="type_changed"
                    phx-value-type="textarea"
                    data-test-id="item-type-textarea"
                    style={"display: flex; flex-direction: column; align-items: center; padding: 0.75rem; border: 1px solid #{if @item_type == "textarea", do: "#4f46e5", else: "#e5e7eb"}; border-radius: 0.375rem; background-color: #{if @item_type == "textarea", do: "#f5f3ff", else: "white"}; cursor: pointer; text-align: center; color: #{if @item_type == "textarea", do: "#4f46e5", else: "#1f2937"};"}
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.5rem; height: 1.5rem; margin-bottom: 0.25rem;">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h7" />
                    </svg>
                    <div style="font-size: 0.75rem; white-space: nowrap;">文本区域</div>
                  </button>

                  <button
                    type="button"
                    phx-click="type_changed"
                    phx-value-type="radio"
                    data-test-id="item-type-radio"
                    style={"display: flex; flex-direction: column; align-items: center; padding: 0.75rem; border: 1px solid #{if @item_type == "radio", do: "#4f46e5", else: "#e5e7eb"}; border-radius: 0.375rem; background-color: #{if @item_type == "radio", do: "#f5f3ff", else: "white"}; cursor: pointer; text-align: center; color: #{if @item_type == "radio", do: "#4f46e5", else: "#1f2937"};"}
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.5rem; height: 1.5rem; margin-bottom: 0.25rem;">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                    <div style="font-size: 0.75rem; white-space: nowrap;">单选按钮</div>
                  </button>

                  <button
                    type="button"
                    phx-click="type_changed"
                    phx-value-type="checkbox"
                    data-test-id="item-type-checkbox"
                    style={"display: flex; flex-direction: column; align-items: center; padding: 0.75rem; border: 1px solid #{if @item_type == "checkbox", do: "#4f46e5", else: "#e5e7eb"}; border-radius: 0.375rem; background-color: #{if @item_type == "checkbox", do: "#f5f3ff", else: "white"}; cursor: pointer; text-align: center; color: #{if @item_type == "checkbox", do: "#4f46e5", else: "#1f2937"};"}
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.5rem; height: 1.5rem; margin-bottom: 0.25rem;">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                    </svg>
                    <div style="font-size: 0.75rem; white-space: nowrap;">复选框</div>
                  </button>

                  <button
                    type="button"
                    phx-click="type_changed"
                    phx-value-type="dropdown"
                    data-test-id="item-type-dropdown"
                    style={"display: flex; flex-direction: column; align-items: center; padding: 0.75rem; border: 1px solid #{if @item_type == "dropdown", do: "#4f46e5", else: "#e5e7eb"}; border-radius: 0.375rem; background-color: #{if @item_type == "dropdown", do: "#f5f3ff", else: "white"}; cursor: pointer; text-align: center; color: #{if @item_type == "dropdown", do: "#4f46e5", else: "#1f2937"};"}
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.5rem; height: 1.5rem; margin-bottom: 0.25rem;">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 9l4-4 4 4m0 6l-4 4-4-4" />
                    </svg>
                    <div style="font-size: 0.75rem; white-space: nowrap;">下拉菜单</div>
                  </button>

                    <button
                      type="button"
                      phx-click="type_changed"
                    phx-value-type="number"
                    data-test-id="item-type-number"
                    style={"display: flex; flex-direction: column; align-items: center; padding: 0.75rem; border: 1px solid #{if @item_type == "number", do: "#4f46e5", else: "#e5e7eb"}; border-radius: 0.375rem; background-color: #{if @item_type == "number", do: "#f5f3ff", else: "white"}; cursor: pointer; text-align: center; color: #{if @item_type == "number", do: "#4f46e5", else: "#1f2937"};"}
                    >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.5rem; height: 1.5rem; margin-bottom: 0.25rem;">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 20l4-16m2 16l4-16M6 9h14M4 15h14" />
                    </svg>
                    <div style="font-size: 0.75rem; white-space: nowrap;">数字输入</div>
                    </button>
                </div>
              </div>
            <% end %>

            <%= if @active_category == :personal do %>
              <div style="margin-bottom: 1rem;">
                <h3 style="font-size: 1rem; font-weight: 500; margin-bottom: 0.5rem; color: #4b5563;">个人信息控件</h3>
                <div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 0.5rem;">
                  <button
                    type="button"
                    phx-click="type_changed"
                    phx-value-type="email"
                    data-test-id="item-type-email"
                    style={"display: flex; flex-direction: column; align-items: center; padding: 0.75rem; border: 1px solid #{if @item_type == "email", do: "#4f46e5", else: "#e5e7eb"}; border-radius: 0.375rem; background-color: #{if @item_type == "email", do: "#f5f3ff", else: "white"}; cursor: pointer; text-align: center; color: #{if @item_type == "email", do: "#4f46e5", else: "#1f2937"};"}
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.5rem; height: 1.5rem; margin-bottom: 0.25rem;">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                    </svg>
                    <div style="font-size: 0.75rem; white-space: nowrap;">电子邮箱</div>
                  </button>

                  <button
                    type="button"
                    phx-click="type_changed"
                    phx-value-type="phone"
                    data-test-id="item-type-phone"
                    style={"display: flex; flex-direction: column; align-items: center; padding: 0.75rem; border: 1px solid #{if @item_type == "phone", do: "#4f46e5", else: "#e5e7eb"}; border-radius: 0.375rem; background-color: #{if @item_type == "phone", do: "#f5f3ff", else: "white"}; cursor: pointer; text-align: center; color: #{if @item_type == "phone", do: "#4f46e5", else: "#1f2937"};"}
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.5rem; height: 1.5rem; margin-bottom: 0.25rem;">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z" />
                    </svg>
                    <div style="font-size: 0.75rem; white-space: nowrap;">电话号码</div>
                  </button>

                  <button
                    type="button"
                    phx-click="type_changed"
                    phx-value-type="date"
                    data-test-id="item-type-date"
                    style={"display: flex; flex-direction: column; align-items: center; padding: 0.75rem; border: 1px solid #{if @item_type == "date", do: "#4f46e5", else: "#e5e7eb"}; border-radius: 0.375rem; background-color: #{if @item_type == "date", do: "#f5f3ff", else: "white"}; cursor: pointer; text-align: center; color: #{if @item_type == "date", do: "#4f46e5", else: "#1f2937"};"}
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.5rem; height: 1.5rem; margin-bottom: 0.25rem;">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                    </svg>
                    <div style="font-size: 0.75rem; white-space: nowrap;">日期选择</div>
                  </button>

                  <button
                    type="button"
                    phx-click="type_changed"
                    phx-value-type="time"
                    data-test-id="item-type-time"
                    style={"display: flex; flex-direction: column; align-items: center; padding: 0.75rem; border: 1px solid #{if @item_type == "time", do: "#4f46e5", else: "#e5e7eb"}; border-radius: 0.375rem; background-color: #{if @item_type == "time", do: "#f5f3ff", else: "white"}; cursor: pointer; text-align: center; color: #{if @item_type == "time", do: "#4f46e5", else: "#1f2937"};"}
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.5rem; height: 1.5rem; margin-bottom: 0.25rem;">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                    <div style="font-size: 0.75rem; white-space: nowrap;">时间选择</div>
                  </button>

                    <button
                      type="button"
                      phx-click="type_changed"
                    phx-value-type="region"
                    data-test-id="item-type-region"
                    style={"display: flex; flex-direction: column; align-items: center; padding: 0.75rem; border: 1px solid #{if @item_type == "region", do: "#4f46e5", else: "#e5e7eb"}; border-radius: 0.375rem; background-color: #{if @item_type == "region", do: "#f5f3ff", else: "white"}; cursor: pointer; text-align: center; color: #{if @item_type == "region", do: "#4f46e5", else: "#1f2937"};"}
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.5rem; height: 1.5rem; margin-bottom: 0.25rem;">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
                    </svg>
                    <div style="font-size: 0.75rem; white-space: nowrap;">地区选择</div>
                    </button>
                </div>
              </div>
            <% end %>

            <%= if @active_category == :advanced do %>
              <div style="margin-bottom: 1rem;">
                <h3 style="font-size: 1rem; font-weight: 500; margin-bottom: 0.5rem; color: #4b5563;">高级控件</h3>
                <div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 0.5rem;">
                  <button
                    type="button"
                    phx-click="type_changed"
                    phx-value-type="rating"
                    data-test-id="item-type-rating"
                    style={"display: flex; flex-direction: column; align-items: center; padding: 0.75rem; border: 1px solid #{if @item_type == "rating", do: "#4f46e5", else: "#e5e7eb"}; border-radius: 0.375rem; background-color: #{if @item_type == "rating", do: "#f5f3ff", else: "white"}; cursor: pointer; text-align: center; color: #{if @item_type == "rating", do: "#4f46e5", else: "#1f2937"};"}
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.5rem; height: 1.5rem; margin-bottom: 0.25rem;">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z" />
                    </svg>
                    <div style="font-size: 0.75rem; white-space: nowrap;">评分控件</div>
                  </button>

                  <button
                    type="button"
                    phx-click="type_changed"
                    phx-value-type="matrix"
                    data-test-id="item-type-matrix"
                    style={"display: flex; flex-direction: column; align-items: center; padding: 0.75rem; border: 1px solid #{if @item_type == "matrix", do: "#4f46e5", else: "#e5e7eb"}; border-radius: 0.375rem; background-color: #{if @item_type == "matrix", do: "#f5f3ff", else: "white"}; cursor: pointer; text-align: center; color: #{if @item_type == "matrix", do: "#4f46e5", else: "#1f2937"};"}
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.5rem; height: 1.5rem; margin-bottom: 0.25rem;">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 10h16M4 14h16M4 18h16" />
                    </svg>
                    <div style="font-size: 0.75rem; white-space: nowrap;">矩阵问题</div>
                  </button>

                  <button
                    type="button"
                    phx-click="type_changed"
                    phx-value-type="image_choice"
                    data-test-id="item-type-image_choice"
                    style={"display: flex; flex-direction: column; align-items: center; padding: 0.75rem; border: 1px solid #{if @item_type == "image_choice", do: "#4f46e5", else: "#e5e7eb"}; border-radius: 0.375rem; background-color: #{if @item_type == "image_choice", do: "#f5f3ff", else: "white"}; cursor: pointer; text-align: center; color: #{if @item_type == "image_choice", do: "#4f46e5", else: "#1f2937"};"}
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.5rem; height: 1.5rem; margin-bottom: 0.25rem;">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                    </svg>
                    <div style="font-size: 0.75rem; white-space: nowrap;">图片选择</div>
                  </button>

                    <button
                      type="button"
                      phx-click="type_changed"
                    phx-value-type="file_upload"
                    data-test-id="item-type-file_upload"
                    style={"display: flex; flex-direction: column; align-items: center; padding: 0.75rem; border: 1px solid #{if @item_type == "file_upload", do: "#4f46e5", else: "#e5e7eb"}; border-radius: 0.375rem; background-color: #{if @item_type == "file_upload", do: "#f5f3ff", else: "white"}; cursor: pointer; text-align: center; color: #{if @item_type == "file_upload", do: "#4f46e5", else: "#1f2937"};"}
                    >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.5rem; height: 1.5rem; margin-bottom: 0.25rem;">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
                    </svg>
                    <div style="font-size: 0.75rem; white-space: nowrap;">文件上传</div>
                    </button>
                </div>
              </div>
            <% end %>
          <% else %>
            <!-- 搜索结果显示 -->
            <div style="margin-bottom: 1rem;">
              <h3 style="font-size: 1rem; font-weight: 500; margin-bottom: 0.5rem; color: #4b5563;">搜索结果</h3>
              <%= if Enum.empty?(@search_term) do %>
                <div style="text-align: center; padding: 1rem; color: #6b7280; background-color: #f9fafb; border-radius: 0.375rem;">
                  <p>没有找到匹配的控件类型</p>
                </div>
              <% else %>
                <div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 0.5rem;">
                  <%= for type <- @search_term do %>
                    <button
                      type="button"
                      phx-click="type_changed"
                      phx-value-type={type}
                      style={"display: flex; flex-direction: column; align-items: center; padding: 0.75rem; border: 1px solid #{if @item_type == to_string(type), do: "#4f46e5", else: "#e5e7eb"}; border-radius: 0.375rem; background-color: #{if @item_type == to_string(type), do: "#f5f3ff", else: "white"}; cursor: pointer; text-align: center; color: #{if @item_type == to_string(type), do: "#4f46e5", else: "#1f2937"};"}
                    >
                      <div style="font-size: 0.75rem; white-space: nowrap;"><%= display_selected_type(type) %></div>
                    </button>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>

          <!-- 添加控件按钮 -->
          <div style="margin-top: 1rem;">
            <button
              type="button"
              id="add-new-form-item-button"
              phx-click="add_item"
              disabled={is_nil(@item_type)}
              style={"width: 100%; padding: 0.75rem; border: none; border-radius: 0.375rem; background-color: #{if is_nil(@item_type), do: "#d1d5db", else: "#4f46e5"}; color: white; font-weight: 500; cursor: #{if is_nil(@item_type), do: "not-allowed", else: "pointer"}; display: flex; justify-content: center; align-items: center; gap: 0.5rem;"}
            >
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.25rem; height: 1.25rem;">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
              </svg>
              添加选中控件
            </button>
          </div>
        </div>

        <!-- 右侧内容区域 -->
        <div style="flex: 1; padding: 1.5rem; overflow-y: auto; height: calc(100vh - 4rem);">
          <!-- 模板标题和操作区 -->
          <div style="display: flex; justify-content: flex-end; align-items: center; margin-bottom: 1rem;">
            <%# <h1 style=\"font-size: 1.5rem; font-weight: 700;\">Template Name Removed</h1> REMOVED %>

            <div style="display: flex; gap: 0.75rem;">
              <.link
                patch={~p"/forms"}
                style="display: inline-flex; justify-content: center; padding: 0.5rem 1rem; background-color: white; color: #4b5563; border: 1px solid #d1d5db; border-radius: 0.375rem; font-weight: 500; font-size: 0.875rem; text-decoration: none;"
              >
                返回表单列表
              </.link>

              <button
                type="button"
                phx-click="save_structure"
                style="display: inline-flex; justify-content: center; padding: 0.5rem 1rem; background-color: #4f46e5; color: white; border-radius: 0.375rem; font-weight: 500; font-size: 0.875rem; border: none;"
              >
                保存模板
              </button>
            </div>
          </div>

          <!-- 标签页导航 -->
          <div style="border-bottom: 1px solid #e5e7eb; margin-bottom: 1.5rem;">
            <%# Changed: Use flex to distribute space, remove gap %>
            <div style="display: flex; width: 100%;">
              <button
                type="button"
                phx-click="change_tab"
                phx-value-tab="structure"
                style={"flex: 1; text-align: center; padding: 0.75rem 1rem; border: none; background-color: #{if @active_tab == "structure", do: "#f3f4f6", else: "transparent"}; font-size: 1rem; font-weight: #{if @active_tab == "structure", do: "600", else: "400"}; cursor: pointer; border-bottom: 3px solid #{if @active_tab == "structure", do: "#4f46e5", else: "transparent"}; color: #{if @active_tab == "structure", do: "#4f46e5", else: "#6b7280"};"}
              >
                1. 结构设计 <%# Changed: Added number %>
              </button>
              <button
                type="button"
                phx-click="change_tab"
                phx-value-tab="conditions"
                style={"flex: 1; text-align: center; padding: 0.75rem 1rem; border: none; background-color: #{if @active_tab == "conditions", do: "#f3f4f6", else: "transparent"}; font-size: 1rem; font-weight: #{if @active_tab == "conditions", do: "600", else: "400"}; cursor: pointer; border-bottom: 3px solid #{if @active_tab == "conditions", do: "#4f46e5", else: "transparent"}; color: #{if @active_tab == "conditions", do: "#4f46e5", else: "#6b7280"};"}
              >
                2. 条件逻辑 <%# Changed: Added number %>
              </button>
              <button
                type="button"
                phx-click="change_tab"
                phx-value-tab="decoration"
                style={"flex: 1; text-align: center; padding: 0.75rem 1rem; border: none; background-color: #{if @active_tab == "decoration", do: "#f3f4f6", else: "transparent"}; font-size: 1rem; font-weight: #{if @active_tab == "decoration", do: "600", else: "400"}; cursor: pointer; border-bottom: 3px solid #{if @active_tab == "decoration", do: "#4f46e5", else: "transparent"}; color: #{if @active_tab == "decoration", do: "#4f46e5", else: "#6b7280"};"}
              >
                3. 页面装饰 <%# Changed: Added number %>
              </button>
            </div>
          </div>

          <!-- 标签页导航按钮 -->
          <div style="display: flex; justify-content: space-between; margin-bottom: 1.5rem;">
            <%= if @active_tab != "structure" do %>
              <button
                type="button"
                phx-click="prev_tab"
                style="display: inline-flex; align-items: center; padding: 0.5rem 1rem; background-color: white; color: #4b5563; border: 1px solid #d1d5db; border-radius: 0.375rem; font-weight: 500; font-size: 0.875rem;"
              >
                <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1rem; height: 1rem; margin-right: 0.25rem;">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
                </svg>
                上一步
              </button>
            <% else %>
              <!-- 在第一个标签页时占位或不显示 -->
              <div></div>
            <% end %>

            <%= if @active_tab != "decoration" do %>
              <button
                type="button"
                phx-click="next_tab"
                style="display: inline-flex; align-items: center; padding: 0.5rem 1rem; background-color: white; color: #4b5563; border: 1px solid #d1d5db; border-radius: 0.375rem; font-weight: 500; font-size: 0.875rem;"
              >
                下一步
                <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 ml-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1rem; height: 1rem; margin-left: 0.25rem;">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
                </svg>
              </button>
            <% else %>
              <!-- 在最后一个标签页时占位或不显示 -->
              <div></div>
            <% end %>
          </div>

          <!-- 确认删除对话框 -->
          <%= if @delete_item_id do %>
            <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
              <div class="bg-white rounded-lg p-6 max-w-md w-full shadow-xl">
                <h3 class="text-lg font-medium mb-4">确认删除控件</h3>
                <p class="text-gray-600 mb-6">您确定要删除这个控件吗？此操作无法撤销。</p>
                <div class="flex justify-end space-x-3">
                  <button
                    type="button"
                    phx-click="cancel_delete"
                    class="px-4 py-2 bg-white border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                  >
                    取消
                  </button>
                  <button
                    type="button"
                    phx-click="confirm_delete"
                    data-test-id="confirm-delete"
                    class="inline-flex justify-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-red-600 hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500"
                  >
                    确认删除
                  </button>
                </div>
              </div>
            </div>
          <% end %>

          <!-- 标签页内容区域 -->
          <%= case @active_tab do %>
            <% "structure" -> %>
              <!-- 模板结构列表 -->
              <div class="form-card">
                <h2 style="font-size: 1.125rem; font-weight: 500; margin-bottom: 1rem;">模板结构设计</h2>

                <div id="structure-list" phx-hook="Sortable" class="space-y-4">
                  <%= if Enum.empty?(@structure) do %>
                    <div style="text-align: center; padding: 3rem 0;">
                      <div style="margin: 0 auto; height: 3rem; width: 3rem; color: #9ca3af;">
                        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
                        </svg>
                      </div>
                      <h3 style="font-size: 1.125rem; font-weight: 500; color: #1f2937; margin-top: 0.5rem;">模板还没有元素</h3>
                      <p style="margin-top: 0.5rem; font-size: 0.875rem; color: #6b7280;">从左侧选择控件类型并点击"添加选中控件"按钮</p>
                    </div>
                  <% else %>
                    <%= for element <- @structure do %>
                      <%
                        elem_id = Map.get(element, "id", "unknown")
                        # 优先从 @form_items 中查找数据库记录
                        db_item = Enum.find(@form_items, fn fi -> fi.id == elem_id end)

                        # 如果找到 db_item，则使用数据库数据，否则回退到 structure 数据
                        form_item = if db_item do
                          # 使用来自数据库的 item 数据 (Map 形式以兼容 ItemRendererComponent)
                          %{
                            id: db_item.id,
                            type: db_item.type,
                            label: db_item.label,
                            required: db_item.required,
                            description: db_item.description,
                            placeholder: db_item.placeholder,
                            # !!! 关键改动：直接使用数据库预加载的 options (已经是 %MyApp.Forms.ItemOption{} 列表) !!!
                            options: db_item.options,
                            min: db_item.min,
                            max: db_item.max,
                            step: db_item.step,
                            max_rating: db_item.max_rating,
                            min_date: db_item.min_date,
                            max_date: db_item.max_date,
                            min_time: db_item.min_time,
                            max_time: db_item.max_time,
                            time_format: db_item.time_format,
                            show_format_hint: db_item.show_format_hint,
                            format_display: db_item.format_display,
                            matrix_rows: db_item.matrix_rows,
                            matrix_columns: db_item.matrix_columns,
                            matrix_type: db_item.matrix_type,
                            image_caption_position: db_item.image_caption_position,
                            selection_type: db_item.selection_type,
                            multiple_files: db_item.multiple_files,
                            max_files: db_item.max_files,
                            max_file_size: db_item.max_file_size,
                            allowed_extensions: db_item.allowed_extensions,
                            region_level: db_item.region_level,
                            default_province: db_item.default_province
                          }
                        else
                          # 回退：使用模板结构中的数据 (记录警告)
                          Logger.warning("FormTemplateEditorLive: Could not find form item with ID #{elem_id} in @form_items. Falling back to template structure data.")
                          elem_type_str = Map.get(element, "type", "text_input")
                          %{
                            id: elem_id,
                            type: safe_to_atom(elem_type_str), # 确保是 atom
                            label: Map.get(element, "label") || "未命名元素",
                            required: Map.get(element, "required", false),
                            description: Map.get(element, "description"),
                            placeholder: Map.get(element, "placeholder"),
                            # !!! 回退时仍需格式化，确保 options 是 Map 列表 !!!
                            options: format_options_for_component(Map.get(element, "options", [])),
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
                        end

                        # 从构建好的 form_item 中获取显示所需的变量
                        elem_type = to_string(form_item.type)
                        elem_label = form_item.label
                        elem_required = form_item.required
                        elem_description = form_item.description
                      %>
                      <div
                        id={"item-#{elem_id}"}
                        data-id={elem_id}
                        class="p-3 border rounded bg-white shadow-sm form-card"
                      >
                        <div class="flex justify-between items-center">
                          <div class="flex items-center">
                            <span class="drag-handle text-gray-400 hover:text-gray-600 mr-3 cursor-move text-xl">⠿</span>
                            <div>
                              <div class="flex items-center">
                                <span class="font-medium text-gray-700"><%= elem_label %></span>
                                <%= if elem_required do %>
                                  <span class="ml-2 text-red-500">*</span>
                                <% end %>
                                <%= if Map.get(element, "logic") do %>
                                  <span class="ml-2 text-blue-500 text-xs bg-blue-50 px-1 rounded">
                                    <%= case get_in(element, ["logic", "type"]) do %>
                                      <% "jump" -> %>跳转
                                      <% "show" -> %>显示
                                      <% "hide" -> %>隐藏
                                      <% "end" -> %>结束
                                      <% _ -> %>逻辑
                                    <% end %>
                                  </span>
                                <% end %>
                              </div>
                              <div class="text-xs text-gray-500 mt-1">
                                控件类型: <%= display_selected_type(elem_type) %>
                              </div>
                            </div>
                          </div>

                          <div class="flex gap-2">
                            <button type="button" phx-click="delete_item" phx-value-id={elem_id} style="color: #ef4444; background: none; border: none; cursor: pointer;">
                              删除
                            </button>
                          </div>
                        </div>

                        <%= if elem_description do %>
                          <div class="text-sm text-gray-500 mt-2"><%= elem_description %></div>
                        <% end %>

                        <!-- 逻辑编辑面板 - 仅在选中时显示 -->
                        <%= if @editing_logic_item_id == elem_id do %>
                          <div class="mt-3 p-3 border border-blue-200 bg-blue-50 rounded-md">
                            <div class="flex justify-between items-center mb-3">
                              <h3 class="font-medium text-blue-800">设置题目逻辑</h3>
                              <button
                                type="button"
                                phx-click="close_logic_editor"
                                class="text-gray-500 hover:text-gray-800"
                              >
                                <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                                  <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
                                </svg>
                              </button>
                            </div>

                            <form phx-submit="save_logic" class="space-y-3">
                              <div>
                                <label class="block text-sm font-medium text-gray-700 mb-1">如果此题答案为：</label>
                                <div class="flex items-center gap-2">
                                  <select name="logic[condition_operator]" class="block w-1/3 px-3 py-2 bg-white border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm">
                                    <option value="equals" selected={get_in(@logic_condition || %{}, ["operator"]) == "equals"}>等于</option>
                                    <option value="not_equals" selected={get_in(@logic_condition || %{}, ["operator"]) == "not_equals"}>不等于</option>
                                    <option value="contains" selected={get_in(@logic_condition || %{}, ["operator"]) == "contains"}>包含</option>
                                  </select>
                                  <.render_condition_value_input item={Enum.find(@structure, fn item -> item["id"] == elem_id end)} condition={@logic_condition} />
                                </div>
                              </div>

                              <div>
                                <label class="block text-sm font-medium text-gray-700 mb-1">执行动作：</label>
                                <div class="flex flex-col gap-2">
                                  <label class="inline-flex items-center">
                                    <input
                                      type="radio"
                                      name="logic[type]"
                                      value="jump"
                                      checked={@logic_type == "jump"}
                                      phx-click="change_logic_type"
                                      phx-value-type="jump"
                                      class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded"
                                    />
                                    <span class="ml-2 text-gray-700">跳转到指定题目</span>
                                  </label>
                                  <label class="inline-flex items-center">
                                    <input
                                      type="radio"
                                      name="logic[type]"
                                      value="show"
                                      checked={@logic_type == "show"}
                                      phx-click="change_logic_type"
                                      phx-value-type="show"
                                      class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded"
                                    />
                                    <span class="ml-2 text-gray-700">显示指定题目</span>
                                  </label>
                                  <label class="inline-flex items-center">
                                    <input
                                      type="radio"
                                      name="logic[type]"
                                      value="hide"
                                      checked={@logic_type == "hide"}
                                      phx-click="change_logic_type"
                                      phx-value-type="hide"
                                      class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded"
                                    />
                                    <span class="ml-2 text-gray-700">隐藏指定题目</span>
                                  </label>
                                  <label class="inline-flex items-center">
                                    <input
                                      type="radio"
                                      name="logic[type]"
                                      value="end"
                                      checked={@logic_type == "end"}
                                      phx-click="change_logic_type"
                                      phx-value-type="end"
                                      class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded"
                                    />
                                    <span class="ml-2 text-gray-700">结束问卷</span>
                                  </label>
                                </div>
                              </div>

                              <%= if @logic_type in ["jump", "show", "hide"] do %>
                                <div>
                                  <label class="block text-sm font-medium text-gray-700 mb-1">选择目标题目：</label>
                                  <select
                                    name="logic[target_id]"
                                    class="block w-full px-3 py-2 bg-white border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm"
                                  >
                                    <option value="">-- 请选择题目 --</option>
                                    <%= for target_item <- @structure do %>
                                      <% target_id = Map.get(target_item, "id") %>
                                      <% target_label = Map.get(target_item, "label") || "未命名题目" %>
                                      <%= if target_id != elem_id do %>
                                        <option value={target_id} selected={@logic_target_id == target_id}><%= target_label %></option>
                                      <% end %>
                                    <% end %>
                                  </select>
                                </div>
                              <% end %>

                              <div class="pt-2 flex justify-end">
                                <button
                                  type="button"
                                  phx-click="close_logic_editor"
                                  class="mr-2 bg-white py-2 px-4 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                                >
                                  取消
                                </button>
                                <button
                                  type="submit"
                                  class="py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                                >
                                  保存规则
                                </button>
                              </div>
                            </form>
                          </div>
                        <% end %>

                        <div class="mt-3 border-t pt-3">
                          <%# !!! 关键改动：传递构建好的 form_item 给渲染组件 !!! %>
                          <MyAppWeb.FormLive.ItemRendererComponent.render_item item={form_item} mode={:edit_preview} />
                        </div>
                      </div>
                    <% end %>
                  <% end %>
                </div>
              </div>

            <% "conditions" -> %>
              <!-- 条件逻辑标签页内容 -->
              <div class="form-card">
                <h2 style="font-size: 1.125rem; font-weight: 500; margin-bottom: 1rem;">条件逻辑设置</h2>

                <div class="mb-4 p-4 bg-blue-50 border border-blue-200 rounded-md">
                  <h3 class="text-md font-medium text-blue-800 mb-2">使用说明</h3>
                  <p class="text-sm text-blue-700 mb-2">
                    条件逻辑允许您根据问卷回答创建动态问卷流程。您可以为每个题目添加以下条件：
                  </p>
                  <ul class="list-disc list-inside text-sm text-blue-700 space-y-1 mb-2">
                    <li>跳转逻辑 - 当满足条件时跳到指定题目</li>
                    <li>显示逻辑 - 当满足条件时显示指定题目</li>
                    <li>隐藏逻辑 - 当满足条件时隐藏指定题目</li>
                    <li>结束逻辑 - 当满足条件时结束问卷</li>
                  </ul>
                  <p class="text-sm text-blue-700 mt-2">
                    点击每个题目右侧的<span class="font-semibold">「添加逻辑」</span>或<span class="font-semibold">「编辑逻辑」</span>按钮来设置条件规则。
                  </p>
                </div>

                <!-- 模板结构列表 - 与结构设计标签页相似，但带逻辑按钮 -->
                <!-- 模板结构列表展示 -->
                <div id="logic-structure-list" class="space-y-4">
                  <%= if Enum.empty?(@structure) do %>
                    <div style="text-align: center; padding: 3rem 0;">
                      <div style="margin: 0 auto; height: 3rem; width: 3rem; color: #9ca3af;">
                        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
                        </svg>
                      </div>
                      <h3 style="font-size: 1.125rem; font-weight: 500; color: #1f2937; margin-top: 0.5rem;">模板还没有元素</h3>
                      <p style="margin-top: 0.5rem; font-size: 0.875rem; color: #6b7280;">请先前往「结构设计」标签添加表单元素</p>
                    </div>
                  <% else %>
                    <%= for element <- @structure do %>
                      <%
                        elem_id = Map.get(element, "id", "unknown")
                        # !!! START CHANGE !!!
                        # 优先从 @form_items 中查找数据库记录
                        db_item = Enum.find(@form_items, fn fi -> fi.id == elem_id end)

                        # 如果找到 db_item，则使用数据库数据，否则回退到 structure 数据
                        form_item = if db_item do
                          # 使用来自数据库的 item 数据
                          %{
                            id: db_item.id,
                            type: db_item.type,
                            label: db_item.label,
                            required: db_item.required,
                            description: db_item.description,
                            placeholder: db_item.placeholder,
                            options: db_item.options, # 直接使用数据库预加载的 options
                            min: db_item.min,
                            max: db_item.max,
                            step: db_item.step,
                            max_rating: db_item.max_rating,
                            min_date: db_item.min_date,
                            max_date: db_item.max_date,
                            min_time: db_item.min_time,
                            max_time: db_item.max_time,
                            time_format: db_item.time_format,
                            show_format_hint: db_item.show_format_hint,
                            format_display: db_item.format_display,
                            matrix_rows: db_item.matrix_rows,
                            matrix_columns: db_item.matrix_columns,
                            matrix_type: db_item.matrix_type,
                            image_caption_position: db_item.image_caption_position,
                            selection_type: db_item.selection_type,
                            multiple_files: db_item.multiple_files,
                            max_files: db_item.max_files,
                            max_file_size: db_item.max_file_size,
                            allowed_extensions: db_item.allowed_extensions,
                            region_level: db_item.region_level,
                            default_province: db_item.default_province
                          }
                        else
                          # 回退：使用模板结构中的数据 (记录警告)
                          Logger.warning("FormTemplateEditorLive (conditions tab): Could not find form item with ID #{elem_id} in @form_items. Falling back to template structure data.")
                          elem_type_str = Map.get(element, "type", "text_input")
                          %{
                            id: elem_id,
                            type: safe_to_atom(elem_type_str), # 确保是 atom
                            label: Map.get(element, "label") || "未命名元素",
                            required: Map.get(element, "required", false),
                            description: Map.get(element, "description"),
                            placeholder: Map.get(element, "placeholder"),
                            options: format_options_for_component(Map.get(element, "options", [])), # 回退时格式化
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
                        end

                        # 从构建好的 form_item 中获取显示所需的变量
                        elem_type = to_string(form_item.type)
                        elem_label = form_item.label
                        elem_required = form_item.required
                        elem_description = form_item.description
                        # !!! END CHANGE !!!

                        # 检查是否有逻辑设置
                        has_logic = Map.get(element, "logic") != nil
                        logic = Map.get(element, "logic")
                        logic_type = if has_logic, do: Map.get(logic, "type"), else: nil
                        condition = if has_logic, do: Map.get(logic, "condition"), else: nil
                        condition_op = if condition, do: Map.get(condition, "operator", ""), else: nil
                        condition_value = if condition, do: Map.get(condition, "value", ""), else: nil
                        target_id = if has_logic, do: Map.get(logic, "target_id"), else: nil

                        # 查找目标题目（如果有）
                        target_item = if target_id, do: Enum.find(@structure, fn i -> Map.get(i, "id") == target_id end), else: nil
                        target_label = if target_item, do: Map.get(target_item, "label") || "未命名题目", else: nil

                        # 条件操作符显示文本
                        condition_op_text = case condition_op do
                          "equals" -> "等于"
                          "not_equals" -> "不等于"
                          "contains" -> "包含"
                          _ -> condition_op
                        end

                        # 逻辑类型显示文本
                        logic_type_text = case logic_type do
                          "jump" -> "跳转到"
                          "show" -> "显示"
                          "hide" -> "隐藏"
                          "end" -> "结束问卷"
                          _ -> logic_type
                        end
                      %>
                      <div
                        id={"logic-item-#{elem_id}"}
                        class="p-3 border rounded bg-white shadow-sm form-card"
                      >
                        <div class="flex justify-between items-center">
                          <div class="flex items-center">
                            <div>
                              <div class="flex items-center">
                                <span class="font-medium text-gray-700"><%= elem_label %></span>
                                <%= if elem_required do %>
                                  <span class="ml-2 text-red-500">*</span>
                                <% end %>
                                <%= if has_logic do %>
                                  <span class="ml-2 text-blue-500 text-xs bg-blue-50 px-1 rounded">
                                    <%= case logic_type do %>
                                      <% "jump" -> %>跳转
                                      <% "show" -> %>显示
                                      <% "hide" -> %>隐藏
                                      <% "end" -> %>结束
                                      <% _ -> %>逻辑
                                    <% end %>
                                  </span>
                                <% end %>
                              </div>
                              <div class="text-xs text-gray-500 mt-1">
                                控件类型: <%= display_selected_type(elem_type) %>
                              </div>
                            </div>
                          </div>

                          <div class="flex gap-2">
                            <button
                              type="button"
                              phx-click="open_logic_editor"
                              phx-value-id={elem_id}
                              style="color: #3b82f6; background: none; border: none; cursor: pointer; font-size: 0.875rem; display: flex; align-items: center; gap: 0.25rem;"
                            >
                              <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16V4m0 0L3 8m4-4l4 4m6 0v12m0 0l4-4m-4 4l-4-4" />
                              </svg>
                              <%= if has_logic, do: "编辑逻辑", else: "添加逻辑" %>
                            </button>
                          </div>
                        </div>

                        <%= if elem_description do %>
                          <div class="text-sm text-gray-500 mt-2"><%= elem_description %></div>
                        <% end %>

                        <%= if has_logic do %>
                          <div class="mt-2 text-sm text-gray-600 bg-gray-50 p-2 rounded-md">
                            <p>如果答案<strong><%= condition_op_text %></strong> "<%= condition_value %>"
                            则<strong><%= logic_type_text %></strong> <%= if target_label, do: "「#{target_label}」" %></p>
                          </div>
                        <% end %>

                        <!-- 逻辑编辑面板 - 仅在选中时显示 -->
                        <%= if @editing_logic_item_id == elem_id do %>
                          <div class="mt-3 p-3 border border-blue-200 bg-blue-50 rounded-md">
                            <div class="flex justify-between items-center mb-3">
                              <h3 class="font-medium text-blue-800">设置题目逻辑</h3>
                              <button
                                type="button"
                                phx-click="close_logic_editor"
                                class="text-gray-500 hover:text-gray-800"
                              >
                                <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                                  <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
                                </svg>
                              </button>
                            </div>

                            <form phx-submit="save_logic" class="space-y-3">
                              <div>
                                <label class="block text-sm font-medium text-gray-700 mb-1">如果此题答案为：</label>
                                <div class="flex items-center gap-2">
                                  <select name="logic[condition_operator]" class="block w-1/3 px-3 py-2 bg-white border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm">
                                    <option value="equals" selected={get_in(@logic_condition || %{}, ["operator"]) == "equals"}>等于</option>
                                    <option value="not_equals" selected={get_in(@logic_condition || %{}, ["operator"]) == "not_equals"}>不等于</option>
                                    <option value="contains" selected={get_in(@logic_condition || %{}, ["operator"]) == "contains"}>包含</option>
                                  </select>
                                  <%# !!! CHANGE: Pass the constructed form_item map instead of finding from structure again !!! %>
                                  <.render_condition_value_input item={form_item} condition={@logic_condition} />
                                </div>
                              </div>

                              <div>
                                <label class="block text-sm font-medium text-gray-700 mb-1">执行动作：</label>
                                <div class="flex flex-col gap-2">
                                  <label class="inline-flex items-center">
                                    <input
                                      type="radio"
                                      name="logic[type]"
                                      value="jump"
                                      checked={@logic_type == "jump"}
                                      phx-click="change_logic_type"
                                      phx-value-type="jump"
                                      class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded"
                                    />
                                    <span class="ml-2 text-gray-700">跳转到指定题目</span>
                                  </label>
                                  <label class="inline-flex items-center">
                                    <input
                                      type="radio"
                                      name="logic[type]"
                                      value="show"
                                      checked={@logic_type == "show"}
                                      phx-click="change_logic_type"
                                      phx-value-type="show"
                                      class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded"
                                    />
                                    <span class="ml-2 text-gray-700">显示指定题目</span>
                                  </label>
                                  <label class="inline-flex items-center">
                                    <input
                                      type="radio"
                                      name="logic[type]"
                                      value="hide"
                                      checked={@logic_type == "hide"}
                                      phx-click="change_logic_type"
                                      phx-value-type="hide"
                                      class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded"
                                    />
                                    <span class="ml-2 text-gray-700">隐藏指定题目</span>
                                  </label>
                                  <label class="inline-flex items-center">
                                    <input
                                      type="radio"
                                      name="logic[type]"
                                      value="end"
                                      checked={@logic_type == "end"}
                                      phx-click="change_logic_type"
                                      phx-value-type="end"
                                      class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded"
                                    />
                                    <span class="ml-2 text-gray-700">结束问卷</span>
                                  </label>
                                </div>
                              </div>

                              <%= if @logic_type in ["jump", "show", "hide"] do %>
                                <div>
                                  <label class="block text-sm font-medium text-gray-700 mb-1">选择目标题目：</label>
                                  <select
                                    name="logic[target_id]"
                                    class="block w-full px-3 py-2 bg-white border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm"
                                  >
                                    <option value="">-- 请选择题目 --</option>
                                    <%= for target_item <- @structure do %>
                                      <% target_id = Map.get(target_item, "id") %>
                                      <% target_label = Map.get(target_item, "label") || "未命名题目" %>
                                      <%= if target_id != elem_id do %>
                                        <option value={target_id} selected={@logic_target_id == target_id}><%= target_label %></option>
                                      <% end %>
                                    <% end %>
                                  </select>
                                </div>
                              <% end %>

                              <div class="pt-2 flex justify-end">
                                <button
                                  type="button"
                                  phx-click="close_logic_editor"
                                  class="mr-2 bg-white py-2 px-4 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                                >
                                  取消
                                </button>
                                <button
                                  type="submit"
                                  class="py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                                >
                                  保存规则
                                </button>
                              </div>
                            </form>
                          </div>
                        <% end %>

                        <div class="mt-3 border-t pt-3">
                          <%# !!! 关键改动：传递构建好的 form_item 给渲染组件 !!! %>
                          <MyAppWeb.FormLive.ItemRendererComponent.render_item item={form_item} mode={:edit_preview} />
                        </div>
                      </div>
                    <% end %>
                  <% end %>
                </div>

                <!-- 逻辑编辑面板已移到每个卡片中，这里不再需要重复渲染 -->
              </div>

            <% "decoration" -> %>
              <!-- 页面装饰标签页内容 -->
              <div style="display: flex; max-width: 100%; overflow-hidden;">
                <!-- 左侧装饰元素类型选择栏 -->
                <div style="flex: 0 0 16rem; border-right: 1px solid #e5e7eb; background-color: white; padding: 1rem; overflow-y: auto; height: calc(100vh - 10rem);">
                  <h2 style="font-size: 1.125rem; font-weight: 500; margin-bottom: 1rem;">装饰元素类型</h2>

                  <!-- 分类标签 -->
                  <div style="display: flex; border-bottom: 1px solid #e5e7eb; margin-bottom: 1rem;">
                    <button
                      phx-click="change_decoration_category"
                      phx-value-category="content"
                      data-category="content"
                      style={"padding: 0.5rem 0.75rem; border: none; background: none; font-size: 0.875rem; font-weight: 500; cursor: pointer; border-bottom: 2px solid #{if @decoration_category == :content, do: "#4f46e5", else: "transparent"}; color: #{if @decoration_category == :content, do: "#4f46e5", else: "#6b7280"}; display: flex; align-items: center; gap: 0.375rem;"}
                    >
                      <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.25rem; height: 1.25rem;">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h7" />
                      </svg>
                      内容
                    </button>
                    <button
                      phx-click="change_decoration_category"
                      phx-value-category="visual"
                      data-category="visual"
                      style={"padding: 0.5rem 0.75rem; border: none; background: none; font-size: 0.875rem; font-weight: 500; cursor: pointer; border-bottom: 2px solid #{if @decoration_category == :visual, do: "#4f46e5", else: "transparent"}; color: #{if @decoration_category == :visual, do: "#4f46e5", else: "#6b7280"}; display: flex; align-items: center; gap: 0.375rem;"}
                    >
                      <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.25rem; height: 1.25rem;">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                      </svg>
                      视觉
                    </button>
                    <button
                      phx-click="change_decoration_category"
                      phx-value-category="layout"
                      data-category="layout"
                      style={"padding: 0.5rem 0.75rem; border: none; background: none; font-size: 0.875rem; font-weight: 500; cursor: pointer; border-bottom: 2px solid #{if @decoration_category == :layout, do: "#4f46e5", else: "transparent"}; color: #{if @decoration_category == :layout, do: "#4f46e5", else: "#6b7280"}; display: flex; align-items: center; gap: 0.375rem;"}
                    >
                      <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.25rem; height: 1.25rem;">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 5a1 1 0 011-1h14a1 1 0 011 1v2a1 1 0 01-1 1H5a1 1 0 01-1-1V5zM4 13a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H5a1 1 0 01-1-1v-6zM16 13a1 1 0 011-1h2a1 1 0 011 1v6a1 1 0 01-1 1h-2a1 1 0 01-1-1v-6z" />
                      </svg>
                      布局
                    </button>
                  </div>

                  <!-- 装饰元素类型选择 -->
                  <%= if @decoration_category == :content do %>
                    <div style="margin-bottom: 1rem;">
                      <h3 style="font-size: 1rem; font-weight: 500; margin-bottom: 0.5rem; color: #4b5563;">内容元素</h3>
                      <div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 0.5rem;">
                        <button
                          type="button"
                          phx-click="decoration_type_changed"
                          phx-value-type="title"
                          style={"display: flex; flex-direction: column; align-items: center; padding: 0.75rem; border: 1px solid #{if @decoration_type == "title", do: "#4f46e5", else: "#e5e7eb"}; border-radius: 0.375rem; background-color: #{if @decoration_type == "title", do: "#f5f3ff", else: "white"}; cursor: pointer; text-align: center; color: #{if @decoration_type == "title", do: "#4f46e5", else: "#1f2937"};"}
                        >
                          <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.5rem; height: 1.5rem; margin-bottom: 0.25rem;">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 5h14M5 12h14M5 19h9" />
                          </svg>
                          <div style="font-size: 0.75rem; white-space: nowrap;">标题</div>
                        </button>

                        <button
                          type="button"
                          phx-click="decoration_type_changed"
                          phx-value-type="paragraph"
                          style={"display: flex; flex-direction: column; align-items: center; padding: 0.75rem; border: 1px solid #{if @decoration_type == "paragraph", do: "#4f46e5", else: "#e5e7eb"}; border-radius: 0.375rem; background-color: #{if @decoration_type == "paragraph", do: "#f5f3ff", else: "white"}; cursor: pointer; text-align: center; color: #{if @decoration_type == "paragraph", do: "#4f46e5", else: "#1f2937"};"}
                        >
                          <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.5rem; height: 1.5rem; margin-bottom: 0.25rem;">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 10h16M4 14h16M4 18h16" />
                          </svg>
                          <div style="font-size: 0.75rem; white-space: nowrap;">段落</div>
                        </button>

                        <button
                          type="button"
                          phx-click="decoration_type_changed"
                          phx-value-type="section"
                          style={"display: flex; flex-direction: column; align-items: center; padding: 0.75rem; border: 1px solid #{if @decoration_type == "section", do: "#4f46e5", else: "#e5e7eb"}; border-radius: 0.375rem; background-color: #{if @decoration_type == "section", do: "#f5f3ff", else: "white"}; cursor: pointer; text-align: center; color: #{if @decoration_type == "section", do: "#4f46e5", else: "#1f2937"};"}
                        >
                          <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.5rem; height: 1.5rem; margin-bottom: 0.25rem;">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18 12H6" />
                          </svg>
                          <div style="font-size: 0.75rem; white-space: nowrap;">章节分隔</div>
                        </button>

                        <button
                          type="button"
                          phx-click="decoration_type_changed"
                          phx-value-type="explanation"
                          style={"display: flex; flex-direction: column; align-items: center; padding: 0.75rem; border: 1px solid #{if @decoration_type == "explanation", do: "#4f46e5", else: "#e5e7eb"}; border-radius: 0.375rem; background-color: #{if @decoration_type == "explanation", do: "#f5f3ff", else: "white"}; cursor: pointer; text-align: center; color: #{if @decoration_type == "explanation", do: "#4f46e5", else: "#1f2937"};"}
                        >
                          <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.5rem; height: 1.5rem; margin-bottom: 0.25rem;">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                          </svg>
                          <div style="font-size: 0.75rem; white-space: nowrap;">解释框</div>
                        </button>
                      </div>
                    </div>
                  <% end %>

                  <%= if @decoration_category == :visual do %>
                    <div style="margin-bottom: 1rem;">
                      <h3 style="font-size: 1rem; font-weight: 500; margin-bottom: 0.5rem; color: #4b5563;">视觉元素</h3>
                      <div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 0.5rem;">
                        <button
                          type="button"
                          phx-click="decoration_type_changed"
                          phx-value-type="header_image"
                          style={"display: flex; flex-direction: column; align-items: center; padding: 0.75rem; border: 1px solid #{if @decoration_type == "header_image", do: "#4f46e5", else: "#e5e7eb"}; border-radius: 0.375rem; background-color: #{if @decoration_type == "header_image", do: "#f5f3ff", else: "white"}; cursor: pointer; text-align: center; color: #{if @decoration_type == "header_image", do: "#4f46e5", else: "#1f2937"};"}
                        >
                          <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.5rem; height: 1.5rem; margin-bottom: 0.25rem;">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                          </svg>
                          <div style="font-size: 0.75rem; white-space: nowrap;">题图</div>
                        </button>

                        <button
                          type="button"
                          phx-click="decoration_type_changed"
                          phx-value-type="inline_image"
                          style={"display: flex; flex-direction: column; align-items: center; padding: 0.75rem; border: 1px solid #{if @decoration_type == "inline_image", do: "#4f46e5", else: "#e5e7eb"}; border-radius: 0.375rem; background-color: #{if @decoration_type == "inline_image", do: "#f5f3ff", else: "white"}; cursor: pointer; text-align: center; color: #{if @decoration_type == "inline_image", do: "#4f46e5", else: "#1f2937"};"}
                        >
                          <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.5rem; height: 1.5rem; margin-bottom: 0.25rem;">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                          </svg>
                          <div style="font-size: 0.75rem; white-space: nowrap;">中间插图</div>
                        </button>
                      </div>
                    </div>
                  <% end %>

                  <%= if @decoration_category == :layout do %>
                    <div style="margin-bottom: 1rem;">
                      <h3 style="font-size: 1rem; font-weight: 500; margin-bottom: 0.5rem; color: #4b5563;">布局元素</h3>
                      <div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 0.5rem;">
                        <button
                          type="button"
                          phx-click="decoration_type_changed"
                          phx-value-type="spacer"
                          style={"display: flex; flex-direction: column; align-items: center; padding: 0.75rem; border: 1px solid #{if @decoration_type == "spacer", do: "#4f46e5", else: "#e5e7eb"}; border-radius: 0.375rem; background-color: #{if @decoration_type == "spacer", do: "#f5f3ff", else: "white"}; cursor: pointer; text-align: center; color: #{if @decoration_type == "spacer", do: "#4f46e5", else: "#1f2937"};"}
                        >
                          <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.5rem; height: 1.5rem; margin-bottom: 0.25rem;">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 11v8m4-16v16m4-11v11" />
                          </svg>
                          <div style="font-size: 0.75rem; white-space: nowrap;">空间</div>
                        </button>
                      </div>
                    </div>
                  <% end %>

                  <!-- 添加装饰元素按钮 -->
                  <div style="margin-top: 1rem;">
                    <button
                      type="button"
                      id="add-decoration-element-button"
                      phx-click="add_decoration_element"
                      disabled={is_nil(@decoration_type)}
                      style={"width: 100%; padding: 0.75rem; border: none; border-radius: 0.375rem; background-color: #{if is_nil(@decoration_type), do: "#d1d5db", else: "#4f46e5"}; color: white; font-weight: 500; cursor: #{if is_nil(@decoration_type), do: "not-allowed", else: "pointer"}; display: flex; justify-content: center; align-items: center; gap: 0.5rem;"}
                    >
                      <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="width: 1.25rem; height: 1.25rem;">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
                      </svg>
                      添加装饰元素
                    </button>
                  </div>
                </div>

                <!-- 右侧内容区域 -->
                <div style="flex: 1; padding: 1.5rem; overflow-y: auto; height: calc(100vh - 10rem);">
                  <div class="form-card">
                    <h2 style="font-size: 1.125rem; font-weight: 500; margin-bottom: 1rem;">页面装饰元素</h2>

                    <div id="decoration-list" phx-hook="DecorationSortable" class="space-y-4">
                      <%= if Enum.empty?(@decoration) do %>
                        <div style="text-align: center; padding: 3rem 0;">
                          <div style="margin: 0 auto; height: 3rem; width: 3rem; color: #9ca3af;">
                            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 21a4 4 0 01-4-4V5a2 2 0 012-2h4a2 2 0 012 2v12a4 4 0 01-4 4zm0 0h12a2 2 0 002-2v-4a2 2 0 00-2-2h-2.343M11 7.343l1.657-1.657a2 2 0 012.828 0l2.829 2.829a2 2 0 010 2.828l-8.486 8.485M7 17h.01" />
                            </svg>
                          </div>
                          <h3 style="font-size: 1.125rem; font-weight: 500; color: #1f2937; margin-top: 0.5rem;">暂无装饰元素</h3>
                          <p style="margin-top: 0.5rem; font-size: 0.875rem; color: #6b7280;">从左侧选择装饰元素类型并点击"添加装饰元素"按钮</p>
                        </div>
                      <% else %>
                        <%= for element <- @decoration do %>
                          <%
                            elem_id = element["id"] || element[:id]
                            elem_type = element["type"] || element[:type]
                            elem_title = case elem_type do
                              "title" -> element["title"] || element[:title] || "未命名标题"
                              "paragraph" -> truncate(element["content"] || element[:content] || "", 30)
                              "section" -> element["title"] || element[:title] || "章节分隔"
                              "explanation" -> element["content"] || element[:content] || "解释框"
                              "header_image" -> "题图"
                              "inline_image" -> element["caption"] || element[:caption] || "插图"
                              "spacer" -> "空间"
                              _ -> "未知元素"
                            end
                          %>
                          <div
                            id={"decoration-#{elem_id}"}
                            data-id={elem_id}
                            class="p-3 border rounded bg-white shadow-sm form-card"
                          >
                            <div class="flex justify-between items-center">
                              <div class="flex items-center">
                                <span class="drag-handle text-gray-400 hover:text-gray-600 mr-3 cursor-move text-xl">⠿</span>
                                <div>
                                  <div class="flex items-center">
                                    <span class="font-medium text-gray-700"><%= elem_title %></span>
                                  </div>
                                  <div class="text-xs text-gray-500 mt-1">
                                    元素类型: <%= display_decoration_type(elem_type) %>
                                  </div>
                                </div>
                              </div>

                              <div class="flex gap-2">
                                <button
                                  type="button"
                                  phx-click="edit_decoration_element"
                                  phx-value-id={elem_id}
                                  style="color: #3b82f6; background: none; border: none; cursor: pointer;"
                                >
                                  编辑
                                </button>
                                <button
                                  type="button"
                                  phx-click="delete_decoration_element"
                                  phx-value-id={elem_id}
                                  style="color: #ef4444; background: none; border: none; cursor: pointer;"
                                >
                                  删除
                                </button>
                              </div>
                            </div>

                            <!-- 预览区域 -->
                            <div class="mt-3 border-t pt-3">
                              <.render_decoration_preview element={element} />
                            </div>

                            <!-- 编辑面板 - 仅在选中时显示 -->
                            <%= if @editing_decoration_id == elem_id do %>
                              <div class="mt-3 p-3 border border-blue-200 bg-blue-50 rounded-md">
                                <div class="flex justify-between items-center mb-3">
                                  <h3 class="font-medium text-blue-800">编辑装饰元素</h3>
                                  <button
                                    type="button"
                                    phx-click="close_decoration_editor"
                                    class="text-gray-500 hover:text-gray-800"
                                  >
                                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                                      <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
                                    </svg>
                                  </button>
                                </div>

                                <%# 使用组件调用语法 - 修正：传递需要的 assigns %>
                                <.render_decoration_editor
                                  element={@current_decoration}
                                  uploads={@uploads[@current_upload_config_name]}
                                  upload_config_name={@current_upload_config_name}
                                />
                              </div>
                            <% end %>
                          </div>
                        <% end %>
                      <% end %>
                    </div>
                  </div>
                </div>
              </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Keep this function for now as it directly manipulates the structure assign
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

  # --- Add upload event handlers ---

  @impl true
  def handle_event("cancel_decoration_upload", %{"ref" => ref, "config_name" => config_name_str}, socket) do
    config_name = String.to_atom(config_name_str)
    {:noreply, cancel_upload(socket, config_name, ref)}
  end


  # --- Helper Functions ---

  defp ensure_list(nil), do: []
  defp ensure_list(list) when is_list(list), do: list
  defp ensure_list(_), do: []

  defp find_decoration_and_index(decorations, id) do
    Enum.find_index(decorations, fn decoration ->
      (decoration["id"] || decoration[:id]) |> to_string() == id
    end)
    |> case do
      nil -> nil
      index -> {Enum.at(decorations, index), index}
    end
  end

  defp stringify_keys(map) when is_map(map) do
    for {key, val} <- map, into: %{}, do: {to_string(key), val}
  end

  defp is_uploaded_image?(src) when is_binary(src) do
    String.starts_with?(src, "/uploads/") # Match helper function
  end
  defp is_uploaded_image?(_), do: false

  # Consume upload helper (returns new path or nil)
  defp consume_decoration_upload(socket, upload_config, template_id, original_decoration) do
     uploaded_files =
       consume_uploaded_entries(socket, upload_config, fn %{path: temp_path}, entry ->
         ext = Path.extname(entry.client_name)
         filename = "#{Ecto.UUID.generate()}#{ext}"
         dest_dir = Path.join([:code.priv_dir(:my_app), "static", "uploads"])
         dest_path = Path.join(dest_dir, filename)
         upload_path = "/uploads/#{filename}" # Relative path for web access

         # Ensure directory exists
         File.mkdir_p!(dest_dir)

         # Copy file
         case File.cp(temp_path, dest_path) do
           :ok ->
             # Save file metadata (adjust association as needed)
             file_attrs = %{
               original_filename: entry.client_name,
               filename: filename,
               path: upload_path, # Store the web-accessible path
               content_type: entry.client_type,
               size: entry.client_size
             }

             case Upload.save_uploaded_file(template_id, nil, file_attrs) do # Assuming form_item_id can be nil
               {:ok, uploaded_file} ->
                 # --- Delete old file if replacing ---
                 old_image_url = original_decoration["image_url"] || original_decoration[:image_url]
                 if is_uploaded_image?(old_image_url) do
                   Task.start(fn ->
                      case Upload.delete_uploaded_file(template_id, old_image_url) do # Use the correct function
                        {:ok, _} -> Logger.info("Deleted old decoration image: #{old_image_url}")
                        {:error, reason} -> Logger.error("Failed deleting old decoration image #{old_image_url}: #{inspect(reason)}")
                      end
                   end)
                 end
                 # --- End Delete old file ---
                 {:ok, uploaded_file.path} # Return the web path

               {:error, changeset} ->
                 Logger.error("Failed to save uploaded file record: #{inspect(changeset)}")
                 {:error, "数据库记录保存失败"}
             end

           {:error, reason} ->
             Logger.error("Failed to copy uploaded file: #{inspect(reason)}")
             {:error, "文件复制失败: #{reason}"}
         end
       end)

     # Return the first successful upload path, or nil
     case uploaded_files do
       [{:ok, path} | _] -> path
       _ -> nil
     end
   end

  @impl true
  def handle_event("close_decoration_editor", _params, socket) do
    {:noreply,
      socket
      |> assign(:editing_decoration_id, nil)
      |> assign(:current_decoration, nil)
      |> assign(:current_upload_config_name, nil) # Clear upload config name
    }
  end
end
