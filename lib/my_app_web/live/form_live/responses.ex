defmodule MyAppWeb.FormLive.Responses do
  use MyAppWeb, :live_view

  alias MyApp.Forms
  alias MyApp.Responses
  alias MyApp.Repo
  
  # 嵌入EEx模板文件
  @external_resource index_path = "lib/my_app_web/live/form_live/responses/index.html.heex"
  @external_resource show_path = "lib/my_app_web/live/form_live/responses/show.html.heex"

  @impl true
  def render(%{live_action: :show} = assigns) do
    ~H"""
    <div class="container mx-auto p-6">
      <h1>表单响应详情</h1>
      <div><%= @response.submitted_at %></div>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto p-6">
      <h1>表单响应列表</h1>
      <div><%= @form.title %></div>
    </div>
    """
  end
  
  @impl true
  def mount(%{"id" => form_id}, _session, socket) do
    current_user = socket.assigns.current_user
    
    case Forms.get_form(form_id) do
      nil ->
        {:error,
          {:redirect, %{to: "/forms", flash: %{"error" => "表单不存在"}}}
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
            |> assign(:live_action, :index)
          }
        else
          {:error,
            {:redirect, %{to: "/forms", flash: %{"error" => "您没有权限查看此表单的回复"}}}
          }
        end
    end
  end

  # 显示单个回复
  def mount(%{"form_id" => form_id, "id" => response_id}, _session, socket) do
    current_user = socket.assigns.current_user
    
    case Forms.get_form_with_items(form_id) do
      nil ->
        {:error,
          {:redirect, %{to: "/forms", flash: %{"error" => "表单不存在"}}}
        }
        
      form ->
        if form.user_id == current_user.id do
          case Responses.get_response(response_id) do
            nil ->
              {:error,
                {:redirect, %{to: "/forms/#{form_id}/responses", flash: %{"error" => "回复不存在"}}}
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
                  |> assign(:live_action, :show)
                }
              else
                {:error,
                  {:redirect, %{to: "/forms/#{form_id}/responses", flash: %{"error" => "回复与表单不匹配"}}}
                }
              end
          end
        else
          {:error,
            {:redirect, %{to: "/forms", flash: %{"error" => "您没有权限查看此表单的回复"}}}
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