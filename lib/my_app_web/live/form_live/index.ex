defmodule MyAppWeb.FormLive.Index do
  use MyAppWeb, :live_view

  alias MyApp.Forms
  alias MyApp.Forms.Form
  
  # 开发时调试辅助函数
  def debug(socket, message) do
    if Application.get_env(:my_app, :env) == :dev do
      IO.puts("[DEBUG] #{message}")
    end
    socket
  end

  @impl true
  def mount(_params, _session, socket) do
    # 加载用户创建的所有表单
    IO.puts("[DEBUG] 挂载表单索引页面")
    current_user = socket.assigns.current_user
    forms = Forms.list_forms(current_user.id)

    socket = debug(socket, "表单数量: #{length(forms)}")
    socket = debug(socket, "当前用户: #{current_user.email}")

    {:ok, assign(socket,
      forms: forms,
      page_title: "我的表单",
      form_changeset: Forms.change_form(%Form{}),
      form_values: %{},
      form_errors: %{},
      show_new_form: false,
      editing_form_id: nil
    )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "我的表单")
    |> assign(:form, nil)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    current_user = socket.assigns.current_user
    form = Forms.get_form(id)
    
    if form && form.user_id == current_user.id do
      socket
      |> assign(:page_title, "编辑表单")
      |> assign(:form, form)
      |> assign(:editing_form_id, form.id)
    else
      socket
      |> put_flash(:error, "表单不存在或您无权编辑")
      |> push_navigate(to: ~p"/forms")
    end
  end

  # 所有 handle_event 函数，按名称和参数数量分组
  @impl true
  def handle_event("cancel_new_form", _params, socket) do
    IO.puts("===> 取消新表单事件被触发")
    {:noreply, 
      socket
      |> assign(:show_new_form, false)
      |> assign(:form_values, %{})
      |> assign(:form_errors, %{})
    }
  end

  @impl true
  def handle_event("delete_form", %{"id" => id}, socket) do
    current_user = socket.assigns.current_user
    form = Forms.get_form(id)
    
    if form && form.user_id == current_user.id do
      case Forms.delete_form(form) do
        {:ok, _} ->
          {:noreply,
            socket
            |> put_flash(:info, "表单已删除")
            |> assign(:forms, Forms.list_forms(current_user.id))
          }
        
        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "删除失败: #{inspect(reason)}")}
      end
    else
      {:noreply, put_flash(socket, :error, "表单不存在或您无权删除")}
    end
  end

  @impl true
  def handle_event("edit_form", %{"id" => id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/forms/#{id}/edit")}
  end

  @impl true
  def handle_event("new_form", _params, socket) do
    IO.puts("===> 新表单事件被触发")
    {:noreply, 
      socket
      |> assign(:show_new_form, true)
      |> assign(:form_changeset, Forms.change_form(%Form{}))
      |> assign(:form_values, %{})
      |> assign(:form_errors, %{})
    }
  end

  @impl true 
  def handle_event("publish_form", %{"id" => id}, socket) do
    current_user = socket.assigns.current_user
    form = Forms.get_form(id)
    
    if form && form.user_id == current_user.id do
      case Forms.publish_form(form) do
        {:ok, _updated_form} ->
          {:noreply,
            socket
            |> put_flash(:info, "表单已发布")
            |> assign(:forms, Forms.list_forms(current_user.id))
          }
        
        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "发布失败: #{inspect(reason)}")}
      end
    else
      {:noreply, put_flash(socket, :error, "表单不存在或您无权发布")}
    end
  end

  @impl true
  def handle_event("save_form", %{"form" => form_params}, socket) do
    IO.puts("===> 保存表单事件被触发")
    current_user = socket.assigns.current_user
    
    # 添加用户ID到表单参数
    form_params_with_user = Map.put(form_params, "user_id", current_user.id)
    IO.inspect(form_params_with_user, label: "表单参数")
    
    # 创建 changeset 并验证
    changeset = %Form{} |> Forms.change_form(form_params_with_user)
    
    if changeset.valid? do
      case Forms.create_form(form_params_with_user) do
        {:ok, form} ->
          IO.puts("===> 表单创建成功: #{form.id}")
          IO.inspect(form, label: "创建的表单")
          {:noreply,
            socket
            |> put_flash(:info, "表单创建成功")
            |> assign(:forms, Forms.list_forms(current_user.id))
            |> assign(:form_values, %{})
            |> assign(:form_errors, %{})
            |> assign(:show_new_form, false)
            |> push_navigate(to: ~p"/forms/#{form.id}/edit")
          }
        
        {:error, %Ecto.Changeset{} = error_changeset} ->
          IO.puts("===> 表单创建失败")
          errors = format_errors(error_changeset)
          IO.inspect(errors, label: "错误")
          {:noreply, 
            socket
            |> assign(form_changeset: error_changeset)
            |> assign(form_values: form_params)
            |> assign(form_errors: errors)
          }
      end
    else
      # 验证失败，显示错误
      changeset = %{changeset | action: :insert}
      errors = format_errors(changeset)
      IO.puts("===> 表单验证失败")
      IO.inspect(errors, label: "验证错误")
      
      {:noreply, 
        socket
        |> assign(form_changeset: changeset)
        |> assign(form_values: form_params)
        |> assign(form_errors: errors)
      }
    end
  end

  @impl true
  def handle_event("validate_form", %{"form" => form_params}, socket) do
    IO.puts("===> 验证表单事件被触发")
    changeset =
      %Form{}
      |> Forms.change_form(form_params)
      |> Map.put(:action, :validate)
    
    # 收集错误信息
    errors = format_errors(changeset)
    IO.inspect(errors, label: "Validation errors")
    
    {:noreply, socket 
      |> assign(form_changeset: changeset)
      |> assign(form_values: form_params)
      |> assign(form_errors: errors)}
  end

  @impl true
  def handle_event("view_responses", %{"id" => id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/forms/#{id}/responses")}
  end
  
  # 辅助函数：将 Ecto 错误格式化为简单的键值对并翻译错误消息
  defp format_errors(changeset) do
    errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      message = Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
      
      # 翻译常见错误消息
      case message do
        "can't be blank" -> "不能为空"
        _ -> message
      end
    end)
    
    errors
  end
end