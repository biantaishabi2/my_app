defmodule MyAppWeb.FormLive.Index do
  use MyAppWeb, :live_view

  alias MyApp.Forms
  alias MyApp.Forms.Form

  @impl true
  def mount(_params, _session, socket) do
    # 加载用户创建的所有表单
    current_user = socket.assigns.current_user
    forms = Forms.list_forms(current_user.id)

    {:ok, assign(socket,
      forms: forms,
      page_title: "我的表单",
      form_changeset: Forms.change_form(%Form{}),
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

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "创建新表单")
    |> assign(:form, %Form{})
    |> assign(:show_new_form, true)
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
      |> push_redirect(to: ~p"/forms")
    end
  end

  @impl true
  def handle_event("new_form", _params, socket) do
    {:noreply, 
      socket
      |> assign(:show_new_form, true)
      |> assign(:form_changeset, Forms.change_form(%Form{}))
    }
  end

  @impl true
  def handle_event("save_form", %{"form" => form_params}, socket) do
    current_user = socket.assigns.current_user
    
    # 添加用户ID到表单参数
    form_params_with_user = Map.put(form_params, "user_id", current_user.id)
    
    case Forms.create_form(form_params_with_user) do
      {:ok, form} ->
        {:noreply,
          socket
          |> put_flash(:info, "表单创建成功")
          |> assign(:forms, Forms.list_forms(current_user.id))
          |> assign(:show_new_form, false)
          |> push_patch(to: ~p"/forms/#{form.id}/edit")
        }
      
      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form_changeset: changeset)}
    end
  end

  @impl true
  def handle_event("cancel_new_form", _params, socket) do
    {:noreply, assign(socket, show_new_form: false)}
  end

  @impl true
  def handle_event("edit_form", %{"id" => id}, socket) do
    {:noreply, push_patch(socket, to: ~p"/forms/#{id}/edit")}
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
  def handle_event("view_responses", %{"id" => id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/forms/#{id}/responses")}
  end
end