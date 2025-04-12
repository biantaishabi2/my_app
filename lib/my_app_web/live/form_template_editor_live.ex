defmodule MyAppWeb.FormTemplateEditorLive do
  use MyAppWeb, :live_view
  require Logger

  alias MyApp.FormTemplates
  alias MyApp.FormTemplates.FormTemplate

  @impl true
  def mount(_params, _session, socket) do
    # 检查用户是否已登录
    if socket.assigns[:current_user] do
      form_templates = FormTemplates.list_templates()

      # 对于登录用户，显示模板列表
      {:ok,
       socket
       |> assign(:form_templates, form_templates)
       |> assign(:current_page, :list)
       |> assign(:selected_template, nil)
       |> assign(:editing_template, false)
       |> assign(:delete_template_id, nil)
       |> assign(:loading_templates, false)
       |> assign(:adding_item, false)
       |> assign(:editing_item, nil)
       |> assign(:creating_form, false)
       |> assign(:selected_preview_mode, "PC")
       |> assign(:showDecorationEditor, false)
       |> assign(:decoration_type, nil)
       |> allow_upload(:template_preview,
         accept: ~w(.jpg .jpeg .png),
         max_entries: 1,
         max_file_size: 5_000_000
       )}
    else
      # 对于未登录用户，重定向到登录页面
      {:ok,
       socket
       |> put_flash(:error, "请先登录")
       |> redirect(to: ~p"/users/log_in")}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    # 处理URL参数
    case socket.assigns[:current_page] do
      :list ->
        {:noreply, socket}

      :new ->
        # 检查是否有template_id参数
        case params["template_id"] do
          nil ->
            # 没有模板ID，创建新的空模板
            {:noreply, initialize_new_template(socket)}

          template_id ->
            # 尝试加载现有模板
            case FormTemplates.get_template(template_id) do
              nil ->
                # 模板不存在，创建新的空模板
                {:noreply,
                 socket
                 |> put_flash(:error, "模板不存在")
                 |> initialize_new_template()}

              template ->
                # 找到模板，加载它进行编辑
                {:noreply,
                 socket
                 |> assign(:selected_template, template)
                 |> assign(:editing_template, true)
                 |> assign(:current_structure, template.structure || %{})}
            end
        end

      :edit ->
        # 编辑现有模板
        template_id = params["id"]

        if template_id do
          case FormTemplates.get_template(template_id) do
            nil ->
              {:noreply,
               socket
               |> put_flash(:error, "模板不存在")
               |> assign(:current_page, :list)}

            template ->
              temp_structure = template.structure || %{}

              {:noreply,
               socket
               |> assign(:selected_template, template)
               |> assign(:editing_template, true)
               |> assign(:current_structure, temp_structure)}
          end
        else
          {:noreply, socket}
        end

      _ ->
        {:noreply, socket}
    end
  end

  # 初始化新模板
  defp initialize_new_template(socket) do
    # 创建一个空的模板结构
    empty_structure = %{
      "title" => "新建表单模板",
      "version" => "1.0",
      "pages" => [
        %{
          "id" => Ecto.UUID.generate(),
          "title" => "第一页",
          "items" => []
        }
      ]
    }

    socket
    |> assign(:selected_template, %FormTemplate{})
    |> assign(:editing_template, false)
    |> assign(:current_structure, empty_structure)
  end

  # 处理模板列表页面事件
  @impl true
  def handle_event("new_template", _params, socket) do
    {:noreply,
     socket
     |> assign(:current_page, :new)}
  end

  @impl true
  def handle_event("edit_template", %{"id" => _id}, socket) do
    {:noreply,
     socket
     |> assign(:current_page, :edit)}
  end

  @impl true
  def handle_event("view_template", %{"id" => id}, socket) do
    case FormTemplates.get_template(id) do
      nil ->
        {:noreply, put_flash(socket, :error, "模板不存在")}

      template ->
        {:noreply,
         socket
         |> assign(:selected_template, template)
         |> assign(:current_page, :view)}
    end
  end

  @impl true
  def handle_event("back_to_list", _params, socket) do
    {:noreply,
     socket
     |> assign(:current_page, :list)}
  end

  @impl true
  def handle_event("delete_template", %{"id" => id}, socket) do
    {:noreply, assign(socket, :delete_template_id, id)}
  end

  @impl true
  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, :delete_template_id, nil)}
  end

  @impl true
  def handle_event("confirm_delete", _params, socket) do
    template_id = socket.assigns.delete_template_id

    case FormTemplates.delete_template(template_id) do
      {:ok, _} ->
        # 更新模板列表
        updated_templates = FormTemplates.list_templates()

        {:noreply,
         socket
         |> assign(:form_templates, updated_templates)
         |> assign(:delete_template_id, nil)
         |> put_flash(:info, "模板已删除")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(:delete_template_id, nil)
         |> put_flash(:error, "删除模板失败")}
    end
  end

  # 创建新表单模板
  @impl true
  def handle_event("create_form_from_template", %{"id" => template_id}, socket) do
    # 检查模板是否存在
    case FormTemplates.get_template(template_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "模板不存在")}

      template ->
        {:noreply,
         socket
         |> assign(:selected_template, template)
         |> assign(:creating_form, true)}
    end
  end

  @impl true
  def handle_event("cancel_form_creation", _params, socket) do
    {:noreply, assign(socket, :creating_form, false)}
  end

  @impl true
  def handle_event("submit_form_creation", %{"form" => form_params}, socket) do
    template = socket.assigns.selected_template
    _current_user = socket.assigns.current_user

    # 从模板结构创建表单
    case FormTemplates.create_form_from_template(template, form_params) do
      {:ok, form} ->
        # 重定向到新创建的表单编辑页面
        {:noreply,
         socket
         |> put_flash(:info, "已根据模板创建新表单")
         |> redirect(to: ~p"/forms/#{form.id}/edit")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(:creating_form, false)
         |> put_flash(:error, "创建表单失败，请检查输入")}
    end
  end

  @impl true
  def handle_event("save_template", %{"template" => template_params}, socket) do
    current_structure = socket.assigns.current_structure
    user = socket.assigns.current_user

    # 为模板结构添加修改时间戳
    updated_structure =
      Map.put(current_structure, "last_modified", DateTime.utc_now() |> DateTime.to_iso8601())

    # 更新标题
    updated_structure = Map.put(updated_structure, "title", template_params["title"])

    # 合并装饰元素数据
    updated_structure =
      if socket.assigns[:decoration_elements] do
        Map.put(updated_structure, "decoration", socket.assigns.decoration_elements)
      else
        updated_structure
      end

    full_params =
      template_params
      |> Map.put("structure", updated_structure)
      |> Map.put("user_id", user.id)

    # 处理预览图片上传（如果有）
    uploaded_files =
      consume_uploaded_entries(socket, :template_preview, fn %{path: path}, entry ->
        # 存储预览图片
        filename = "#{Ecto.UUID.generate()}#{Path.extname(entry.client_name)}"
        dest = Path.join([:code.priv_dir(:my_app), "static", "templates", filename])
        File.cp!(path, dest)
        {:ok, "/templates/#{filename}"}
      end)

    # 如果有上传文件，添加到params
    full_params =
      if Enum.any?(uploaded_files) do
        Map.put(full_params, "preview_image", List.first(uploaded_files))
      else
        full_params
      end

    if socket.assigns.editing_template do
      # 更新现有模板
      template = socket.assigns.selected_template

      case FormTemplates.update_template(template, full_params) do
        {:ok, updated_template} ->
          # 更新模板列表
          updated_templates = FormTemplates.list_templates()

          {:noreply,
           socket
           |> assign(:form_templates, updated_templates)
           |> assign(:selected_template, updated_template)
           |> assign(:current_page, :list)
           |> put_flash(:info, "模板已更新")}

        {:error, %Ecto.Changeset{} = changeset} ->
          error_msg = inspect(changeset.errors)

          {:noreply,
           socket
           |> put_flash(:error, "模板更新失败: #{error_msg}")}
      end
    else
      # 创建新模板
      case FormTemplates.create_template(full_params) do
        {:ok, new_template} ->
          # 更新模板列表
          updated_templates = FormTemplates.list_templates()

          {:noreply,
           socket
           |> assign(:form_templates, updated_templates)
           |> assign(:selected_template, new_template)
           |> assign(:current_page, :list)
           |> put_flash(:info, "模板已创建")}

        {:error, %Ecto.Changeset{} = changeset} ->
          error_msg = inspect(changeset.errors)

          {:noreply,
           socket
           |> put_flash(:error, "模板创建失败: #{error_msg}")}
      end
    end
  end

  @impl true
  def handle_event("toggle_preview_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :selected_preview_mode, mode)}
  end

  @impl true
  def handle_event("add_item", _params, socket) do
    {:noreply,
     socket
     |> assign(:adding_item, true)
     |> assign(:editing_item, nil)}
  end

  @impl true
  def handle_event("cancel_add_item", _params, socket) do
    {:noreply,
     socket
     |> assign(:adding_item, false)
     |> assign(:editing_item, nil)}
  end

  @impl true
  def handle_event("edit_item", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    current_structure = socket.assigns.current_structure
    items = get_in(current_structure, ["pages", 0, "items"]) || []

    item =
      if index >= 0 && index < length(items) do
        Enum.at(items, index)
      else
        nil
      end

    if item do
      {:noreply,
       socket
       |> assign(:adding_item, false)
       |> assign(:editing_item, %{index: index, item: item})}
    else
      {:noreply, put_flash(socket, :error, "表单项不存在")}
    end
  end

  @impl true
  def handle_event("cancel_edit_item", _params, socket) do
    {:noreply,
     socket
     |> assign(:adding_item, false)
     |> assign(:editing_item, nil)}
  end

  @impl true
  def handle_event("add_item_to_template", %{"item" => item_params}, socket) do
    current_structure = socket.assigns.current_structure
    items = get_in(current_structure, ["pages", 0, "items"]) || []

    # 创建新的表单项
    new_item = %{
      "id" => Ecto.UUID.generate(),
      "type" => item_params["type"],
      "label" => item_params["label"],
      "required" => item_params["required"] == "true",
      "options" => process_options_from_params(item_params),
      "placeholder" => item_params["placeholder"],
      "help_text" => item_params["help_text"]
    }

    # 添加到items列表
    updated_items = items ++ [new_item]

    # 更新结构
    updated_structure =
      put_in(current_structure, ["pages", 0, "items"], updated_items)
      |> Map.put("last_modified", DateTime.utc_now() |> DateTime.to_iso8601())

    {:noreply,
     socket
     |> assign(:current_structure, updated_structure)
     |> assign(:adding_item, false)
     |> put_flash(:info, "表单项已添加")}
  end

  @impl true
  def handle_event("update_template_item", %{"item" => item_params, "index" => index_str}, socket) do
    index = String.to_integer(index_str)
    current_structure = socket.assigns.current_structure
    items = get_in(current_structure, ["pages", 0, "items"]) || []

    if index >= 0 && index < length(items) do
      # 获取现有项目
      existing_item = Enum.at(items, index)

      # 更新项目
      updated_item = %{
        "id" => existing_item["id"],
        "type" => item_params["type"],
        "label" => item_params["label"],
        "required" => item_params["required"] == "true",
        "options" => process_options_from_params(item_params),
        "placeholder" => item_params["placeholder"],
        "help_text" => item_params["help_text"]
      }

      # 替换项目
      updated_items = List.replace_at(items, index, updated_item)

      # 更新结构
      updated_structure =
        put_in(current_structure, ["pages", 0, "items"], updated_items)
        |> Map.put("last_modified", DateTime.utc_now() |> DateTime.to_iso8601())

      {:noreply,
       socket
       |> assign(:current_structure, updated_structure)
       |> assign(:editing_item, nil)
       |> put_flash(:info, "表单项已更新")}
    else
      {:noreply, put_flash(socket, :error, "表单项不存在")}
    end
  end

  @impl true
  def handle_event("delete_item", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    current_structure = socket.assigns.current_structure
    items = get_in(current_structure, ["pages", 0, "items"]) || []

    if index >= 0 && index < length(items) do
      # 删除项目
      updated_items = List.delete_at(items, index)

      # 更新结构
      updated_structure =
        put_in(current_structure, ["pages", 0, "items"], updated_items)
        |> Map.put("last_modified", DateTime.utc_now() |> DateTime.to_iso8601())

      {:noreply,
       socket
       |> assign(:current_structure, updated_structure)
       |> put_flash(:info, "表单项已删除")}
    else
      {:noreply, put_flash(socket, :error, "表单项不存在")}
    end
  end

  @impl true
  def handle_event("reorder_items", %{"positions" => positions}, socket) do
    current_structure = socket.assigns.current_structure
    items = get_in(current_structure, ["pages", 0, "items"]) || []

    # 解析位置为整数索引
    positions =
      Enum.map(positions, fn pos_string ->
        case Integer.parse(pos_string) do
          {pos, _} -> pos
          :error -> nil
        end
      end)
      |> Enum.filter(&(&1 != nil))

    # 只有在位置有效时才重排序
    if length(positions) == length(items) && Enum.all?(positions, &(&1 >= 0 && &1 < length(items))) do
      # 根据新位置重排序项目
      updated_items = Enum.map(positions, &Enum.at(items, &1))

      # 更新结构
      updated_structure =
        put_in(current_structure, ["pages", 0, "items"], updated_items)
        |> Map.put("last_modified", DateTime.utc_now() |> DateTime.to_iso8601())

      {:noreply, assign(socket, :current_structure, updated_structure)}
    else
      {:noreply, put_flash(socket, :error, "重排序失败，请刷新页面重试")}
    end
  end

  # 处理选项参数
  defp process_options_from_params(item_params) do
    type = item_params["type"]

    # 只有特定类型的控件需要处理选项
    if type in ["radio", "checkbox", "dropdown"] do
      # 选项值
      options_str = item_params["options"] || ""

      # 按行分割
      String.split(options_str, "\n")
      |> Enum.map(&String.trim/1)
      |> Enum.filter(&(&1 != ""))
      |> Enum.map(fn option ->
        %{"id" => Ecto.UUID.generate(), "label" => option, "value" => option}
      end)
    else
      []
    end
  end

  # 装饰元素相关事件处理
  @impl true
  def handle_event("edit_decoration", %{"id" => id}, socket) do
    current_decoration = socket.assigns[:decoration_elements] || []
    element = Enum.find(current_decoration, &(&1["id"] == id))

    if element do
      {:noreply,
       socket
       |> assign(:showDecorationEditor, true)
       |> assign(:editing_decoration_id, id)
       |> assign(:decoration_type, element["type"])}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_decoration", params, socket) do
    id = socket.assigns.editing_decoration_id
    type = socket.assigns.decoration_type

    # 更新元素
    current_decoration = socket.assigns[:decoration_elements] || []
    updated_decoration =
      Enum.map(current_decoration, fn element ->
        if element["id"] == id do
          update_decoration_element(element, type, params)
        else
          element
        end
      end)

    # 将装饰元素更新到结构中
    current_structure = socket.assigns.current_structure
    updated_structure = Map.put(current_structure, "decoration", updated_decoration)

    {:noreply,
     socket
     |> assign(:decoration_elements, updated_decoration)
     |> assign(:current_structure, updated_structure)
     |> assign(:showDecorationEditor, false)
     |> assign(:editing_decoration_id, nil)
     |> assign(:decoration_type, nil)}
  end

  @impl true
  def handle_event("close_decoration_editor", _params, socket) do
    {:noreply,
     socket
     |> assign(:showDecorationEditor, false)
     |> assign(:editing_decoration_id, nil)
     |> assign(:decoration_type, nil)}
  end

  @impl true
  def handle_event("delete_decoration", %{"id" => id}, socket) do
    # 删除元素
    current_decoration = socket.assigns[:decoration_elements] || []
    updated_decoration = Enum.reject(current_decoration, &(&1["id"] == id))

    # 将装饰元素更新到结构中
    current_structure = socket.assigns.current_structure
    updated_structure = Map.put(current_structure, "decoration", updated_decoration)

    {:noreply,
     socket
     |> assign(:decoration_elements, updated_decoration)
     |> assign(:current_structure, updated_structure)}
  end

  @impl true
  def handle_event("add_decoration", %{"type" => type}, socket) do
    # 创建装饰元素基本属性
    element = %{
      "id" => Ecto.UUID.generate(),
      "type" => type,
      "position" => %{
        "top" => "100px",
        "left" => "50px"
      },
      "style" => %{
        "width" => "200px",
        "height" => "auto",
        "zIndex" => "10"
      }
    }

    # 根据类型添加额外属性
    element =
      case type do
        "text" ->
          Map.merge(element, %{
            "content" => "文本内容",
            "style" => Map.merge(element["style"], %{
              "fontSize" => "16px",
              "color" => "#333333",
              "fontWeight" => "normal"
            })
          })

        "image" ->
          Map.merge(element, %{
            "src" => "/images/default.png",
            "style" => Map.merge(element["style"], %{
              "width" => "200px",
              "height" => "auto"
            })
          })

        "shape" ->
          Map.merge(element, %{
            "shape" => "rectangle",
            "style" => Map.merge(element["style"], %{
              "width" => "100px",
              "height" => "100px",
              "backgroundColor" => "#e0e0e0",
              "borderRadius" => "0"
            })
          })

        "line" ->
          Map.merge(element, %{
            "direction" => "horizontal",
            "style" => Map.merge(element["style"], %{
              "width" => "200px",
              "height" => "2px",
              "backgroundColor" => "#000000"
            })
          })

        "space" ->
          Map.merge(element, %{
            "style" => Map.merge(element["style"], %{
              "width" => "100%",
              "height" => "50px",
              "clear" => "both"
            })
          })

        _ ->
          element
      end

    # 添加到装饰元素列表
    current_decoration = socket.assigns[:decoration_elements] || []
    updated_decoration = current_decoration ++ [element]

    # 将装饰元素更新到结构中
    current_structure = socket.assigns.current_structure
    updated_structure = Map.put(current_structure, "decoration", updated_decoration)

    {:noreply,
     socket
     |> assign(:decoration_elements, updated_decoration)
     |> assign(:current_structure, updated_structure)}
  end

  @impl true
  def handle_event("save_decoration_position", params, socket) do
    id = params["id"]
    top = params["top"]
    left = params["left"]

    # 更新元素位置
    current_decoration = socket.assigns[:decoration_elements] || []
    updated_decoration =
      Enum.map(current_decoration, fn element ->
        if element["id"] == id do
          put_in(element, ["position"], %{
            "top" => "#{top}px",
            "left" => "#{left}px"
          })
        else
          element
        end
      end)

    # 将装饰元素更新到结构中
    current_structure = socket.assigns.current_structure
    updated_structure = Map.put(current_structure, "decoration", updated_decoration)

    {:noreply,
     socket
     |> assign(:decoration_elements, updated_decoration)
     |> assign(:current_structure, updated_structure)}
  end

  # 更新装饰元素
  defp update_decoration_element(element, type, params) do
    case type do
      "text" ->
        element
        |> put_in(["content"], params["content"])
        |> update_in(["style"], fn style ->
          style
          |> Map.put("fontSize", "#{params["font_size"]}px")
          |> Map.put("color", params["color"])
          |> Map.put("fontWeight", if(params["bold"] == "true", do: "bold", else: "normal"))
          |> Map.put("width", "#{params["width"]}px")
        end)

      "image" ->
        element
        |> put_in(["src"], params["src"])
        |> update_in(["style"], fn style ->
          style
          |> Map.put("width", "#{params["width"]}px")
        end)

      "shape" ->
        element
        |> put_in(["shape"], params["shape"])
        |> update_in(["style"], fn style ->
          style
          |> Map.put("width", "#{params["width"]}px")
          |> Map.put("height", "#{params["height"]}px")
          |> Map.put("backgroundColor", params["background_color"])
          |> Map.put(
            "borderRadius",
            if(params["shape"] == "circle", do: "50%", else: "#{params["border_radius"]}px")
          )
        end)

      "line" ->
        element
        |> put_in(["direction"], params["direction"])
        |> update_in(["style"], fn style ->
          style
          |> Map.put("width", if(params["direction"] == "horizontal", do: "#{params["length"]}px", else: "2px"))
          |> Map.put("height", if(params["direction"] == "vertical", do: "#{params["length"]}px", else: "2px"))
          |> Map.put("backgroundColor", params["color"])
        end)

      "space" ->
        element
        |> update_in(["style"], fn style ->
          style
          |> Map.put("height", "#{params["height"]}px")
        end)

      _ ->
        element
    end
  end

end