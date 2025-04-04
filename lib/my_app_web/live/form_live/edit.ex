defmodule MyAppWeb.FormLive.Edit do
  use MyAppWeb, :live_view

  alias MyApp.Forms
  alias MyApp.Forms.FormItem
  
  import MyAppWeb.FormComponents
  import Phoenix.LiveView, only: [redirect: 2, put_flash: 3, push_navigate: 2]

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    current_user = socket.assigns.current_user
    
    case Forms.get_form_with_items(id) do
      nil ->
        {:ok, 
          socket
          |> put_flash(:error, "表单不存在")
          |> push_navigate(to: ~p"/forms")
        }
        
      form ->
        if form.user_id == current_user.id do
          {:ok, 
            socket
            |> assign(:page_title, "编辑表单")
            |> assign(:form, form)
            |> assign(:form_changeset, Forms.change_form(form))
            |> assign(:editing_form_info, true)
            |> assign(:form_items, form.items)
            |> assign(:current_item, nil)
            |> assign(:editing_item, false)
            |> assign(:item_options, [])
            |> assign(:item_type, nil)
            |> assign(:delete_item_id, nil)
            |> assign(:show_publish_confirm, false)
          }
        else
          {:ok,
            socket
            |> put_flash(:error, "您没有权限编辑此表单")
            |> redirect(to: "/forms")
          }
        end
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, _params) do
    socket
    |> assign(:page_title, "编辑表单 - #{socket.assigns.form.title}")
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
  def handle_event("save_form_info", params, socket) do
    form_params = params["form"] || %{}
    form = socket.assigns.form
    
    # 使用表单参数的值更新表单
    case Forms.update_form(form, form_params) do
      {:ok, updated_form} ->
        # 强制重新加载，确保所有字段都已更新
        updated_form = Forms.get_form(updated_form.id)
        
        {:noreply, 
          socket
          |> assign(:form, updated_form)
          |> assign(:editing_form_info, false)
          |> put_flash(:info, "表单信息已更新")
        }
        
      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, 
          socket
          |> assign(:form_changeset, changeset)
          |> put_flash(:error, "表单更新失败")
        }
    end
  end

  @impl true
  def handle_event("add_item", _params, socket) do
    {:noreply, 
      socket
      |> assign(:current_item, %FormItem{type: :text_input, required: false})
      |> assign(:item_options, [])
      |> assign(:item_type, "text_input")
      |> assign(:editing_item, true)
    }
  end

  @impl true
  def handle_event("edit_item", %{"id" => id}, socket) do
    item = Enum.find(socket.assigns.form_items, fn item -> item.id == id end)
    
    if item do
      options = case item.options do
        nil -> []
        opts -> opts
      end
      
      {:noreply, 
        socket
        |> assign(:current_item, item)
        |> assign(:item_options, options)
        |> assign(:item_type, to_string(item.type))
        |> assign(:editing_item, true)
      }
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
      |> assign(:item_options, [])
    }
  end

  @impl true
  def handle_event("type_changed", %{"item" => %{"type" => type}}, socket) do
    {:noreply, assign(socket, :item_type, type)}
  end

  @impl true
  def handle_event("type_changed", %{"type" => type}, socket) do
    {:noreply, assign(socket, :item_type, type)}
  end

  @impl true
  def handle_event("form_change", _params, socket) do
    # 仅用于处理表单变化，不需要更新状态
    {:noreply, socket}
  end

  @impl true
  def handle_event("add_option", _params, socket) do
    current_options = socket.assigns.item_options
    new_option = %{id: Ecto.UUID.generate(), label: "", value: ""}
    
    {:noreply, assign(socket, :item_options, current_options ++ [new_option])}
  end

  @impl true
  def handle_event("remove_option", %{"index" => index}, socket) do
    index = String.to_integer(index)
    current_options = socket.assigns.item_options
    updated_options = List.delete_at(current_options, index)
    
    {:noreply, assign(socket, :item_options, updated_options)}
  end

  @impl true
  def handle_event("save_item", params, socket) do
    # 处理表单提交或无参数的情况
    item_params = params["item"] || %{}
    form = socket.assigns.form
    current_item = socket.assigns.current_item
    
    # 处理选项数据
    item_params = process_item_params(item_params)
    
    if current_item.id do
      # 更新现有表单项 - 确保只有字符串键
      clean_params = 
        Map.new(item_params, fn
          # 原子键转字符串
          {k, v} when is_atom(k) -> {to_string(k), v}
          # 保留字符串键
          {k, v} -> {k, v} 
        end)
        
      case Forms.update_form_item(current_item, clean_params) do
        {:ok, updated_item} ->
          # 如果是单选按钮类型，还需要处理选项
          updated_item = 
            if updated_item.type == :radio do
              process_options(updated_item, item_params)
            else
              updated_item
            end
          
          # 更新表单项列表
          updated_items = Enum.map(socket.assigns.form_items, fn item ->
            if item.id == updated_item.id, do: updated_item, else: item
          end)
          
          {:noreply, 
            socket
            |> assign(:form_items, updated_items)
            |> assign(:current_item, nil)
            |> assign(:editing_item, false)
            |> assign(:item_options, [])
            |> put_flash(:info, "表单项已更新")
          }
          
        {:error, changeset} ->
          {:noreply, put_flash(socket, :error, "表单项更新失败: #{inspect(changeset.errors)}")}
      end
    else
      # 添加新表单项
      # 准备参数 - 确保只有字符串键
      clean_params = 
        Map.new(item_params, fn
          # 原子键转字符串
          {k, v} when is_atom(k) -> {to_string(k), v}
          # 保留字符串键
          {k, v} -> {k, v} 
        end)
        
      case Forms.add_form_item(form, clean_params) do
        {:ok, new_item} ->
          # 如果是单选按钮类型，还需要添加选项
          _updated_item = 
            if new_item.type == :radio do
              process_options(new_item, item_params)
            else
              new_item
            end
          
          # 重新加载表单项
          updated_form = Forms.get_form_with_items(form.id)
          
          {:noreply, 
            socket
            |> assign(:form, updated_form)
            |> assign(:form_items, updated_form.items)
            |> assign(:current_item, nil)
            |> assign(:editing_item, false)
            |> assign(:item_options, [])
            |> put_flash(:info, "表单项已添加")
          }
          
        {:error, changeset} ->
          {:noreply, put_flash(socket, :error, "表单项添加失败: #{inspect(changeset.errors)}")}
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
          updated_form = Forms.get_form_with_items(form_id)
          
          # 避免schema关联的懒加载问题，直接从表单中获取完整项目列表
          {:noreply, 
            socket
            |> assign(:form, updated_form)
            |> assign(:form_items, updated_form.items)
            |> assign(:delete_item_id, nil)
            |> put_flash(:info, "表单项已删除")
          }
          
        {:error, _} ->
          {:noreply, 
            socket
            |> assign(:delete_item_id, nil)
            |> put_flash(:error, "表单项删除失败")
          }
      end
    else
      {:noreply, 
        socket
        |> assign(:delete_item_id, nil)
        |> put_flash(:error, "表单项不存在")
      }
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
        updated_form = Forms.get_form_with_items(form_id)
        
        {:noreply, 
          socket
          |> assign(:form, updated_form)
          |> assign(:form_items, updated_form.items)
        }
        
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "表单项排序失败: #{inspect(reason)}")}
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
          |> put_flash(:info, "表单已发布")
        }
        
      {:error, :already_published} ->
        {:noreply, 
          socket
          |> assign(:show_publish_confirm, false)
          |> put_flash(:info, "表单已经是发布状态")
        }
        
      {:error, reason} ->
        {:noreply, 
          socket
          |> assign(:show_publish_confirm, false)
          |> put_flash(:error, "表单发布失败: #{inspect(reason)}")
        }
    end
  end
  
  @impl true
  def handle_event("cancel_publish", _params, socket) do
    {:noreply, assign(socket, :show_publish_confirm, false)}
  end

  # 辅助函数

  # 处理表单项参数
  defp process_item_params(params) do
    # 确保所有键都是字符串
    params = 
      params
      |> Enum.map(fn {k, v} -> {to_string(k), v} end)
      |> Map.new()
      
    # 类型转换
    params = case params["type"] do
      "text_input" -> Map.put(params, "type", :text_input)
      "radio" -> Map.put(params, "type", :radio)
      _ -> params
    end
    
    # 必填项处理
    params = case params["required"] do
      "true" -> Map.put(params, "required", true)
      nil -> Map.put(params, "required", false)
      _ -> params
    end
    
    params
  end

  # 处理选项
  defp process_options(item, params) do
    case params["options"] do
      nil -> item
      options when is_map(options) ->
        options_list = Map.values(options)
        
        Enum.reduce(options_list, item, fn option, updated_item ->
          case Forms.add_item_option(updated_item, option) do
            {:ok, _} -> Forms.get_form_item_with_options(updated_item.id)
            _ -> updated_item
          end
        end)
    end
  end
end