defmodule MyAppWeb.FormLive.Responses do
  import Ecto.Query
  use MyAppWeb, :live_view

  alias MyApp.Forms
  alias MyApp.Responses
  
  @impl true
  def mount(%{"id" => form_id}, _session, socket) do
    current_user = socket.assigns.current_user
    
    case Forms.get_form(form_id) do
      nil ->
        {:ok, 
          socket
          |> put_flash(:error, "表单不存在")
          |> push_navigate(to: ~p"/forms")
        }
        
      form ->
        if form.user_id == current_user.id do
          responses = Responses.list_responses_for_form(form_id)
          
          {:ok, 
            socket
            |> assign(:page_title, "#{form.title} - 表单回复")
            |> assign(:form, form)
            |> assign(:responses, responses)
            |> assign(:current_response, nil)
          }
        else
          {:ok, 
            socket
            |> put_flash(:error, "您没有权限查看此表单的回复")
            |> push_navigate(to: ~p"/forms")
          }
        end
    end
  end

  # 显示单个回复
  def mount(%{"form_id" => form_id, "id" => response_id}, _session, socket) do
    current_user = socket.assigns.current_user
    
    case Forms.get_form_with_items(form_id) do
      nil ->
        {:ok, 
          socket
          |> put_flash(:error, "表单不存在")
          |> push_navigate(to: ~p"/forms")
        }
        
      form ->
        if form.user_id == current_user.id do
          case Responses.get_response(response_id) do
            nil ->
              {:ok,
                socket
                |> put_flash(:error, "回复不存在")
                |> push_navigate(to: ~p"/forms/#{form_id}/responses")
              }
              
            response ->
              if response.form_id == form.id do
                items_map = build_items_map(form.items)
                
                {:ok,
                  socket
                  |> assign(:page_title, "查看回复详情")
                  |> assign(:form, form)
                  |> assign(:response, response)
                  |> assign(:items_map, items_map)
                }
              else
                {:ok,
                  socket
                  |> put_flash(:error, "回复与表单不匹配")
                  |> push_navigate(to: ~p"/forms/#{form_id}/responses")
                }
              end
          end
        else
          {:ok, 
            socket
            |> put_flash(:error, "您没有权限查看此表单的回复")
            |> push_navigate(to: ~p"/forms")
          }
        end
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "#{socket.assigns.form.title} - 表单回复")
  end

  defp apply_action(socket, :show, _params) do
    socket
    |> assign(:page_title, "查看回复详情")
  end

  @impl true
  def handle_event("view_response", %{"id" => id}, socket) do
    form = socket.assigns.form
    {:noreply, push_navigate(socket, to: ~p"/forms/#{form.id}/responses/#{id}")}
  end

  @impl true
  def handle_event("delete_response", %{"id" => id}, socket) do
    response = Responses.get_response(id)
    
    if response do
      case Responses.delete_response(response) do
        {:ok, _} ->
          form_id = socket.assigns.form.id
          updated_responses = Responses.list_responses_for_form(form_id)
          
          {:noreply,
            socket
            |> assign(:responses, updated_responses)
            |> put_flash(:info, "回复已删除")
          }
          
        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "删除回复失败")}
      end
    else
      {:noreply, put_flash(socket, :error, "回复不存在")}
    end
  end

  @impl true
  def handle_event("back_to_responses", _params, socket) do
    form = socket.assigns.form
    {:noreply, push_navigate(socket, to: ~p"/forms/#{form.id}/responses")}
  end

  # 辅助函数

  # 构建表单项映射，以便于查找和显示
  defp build_items_map(items) do
    Enum.reduce(items, %{}, fn item, acc ->
      Map.put(acc, item.id, item)
    end)
  end
  
  # 获取回复者姓名
  def get_respondent_name(response) do
    case response.respondent_info do
      %{"name" => name} when is_binary(name) and name != "" -> name
      %{"user_id" => _} -> "匿名用户"
      _ -> "未知用户"
    end
  end
  
  # 获取回复者邮箱
  def get_respondent_email(response) do
    case response.respondent_info do
      %{"email" => email} when is_binary(email) and email != "" -> email
      _ -> ""
    end
  end
  
  # 格式化日期时间
  def format_datetime(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
  end
end