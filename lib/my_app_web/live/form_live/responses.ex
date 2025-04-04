defmodule MyAppWeb.FormLive.Responses do
  use MyAppWeb, :live_view

  alias MyApp.Forms
  alias MyApp.Responses
  
  # 嵌入EEx模板文件
  @external_resource _index_path = "lib/my_app_web/live/form_live/responses/index.html.heex"
  @external_resource _show_path = "lib/my_app_web/live/form_live/responses/show.html.heex"

  # 直接定义内嵌模板以避免视图渲染问题
  @impl true
  def render(%{live_action: :show} = assigns) do
    ~H"""
    <div class="container mx-auto p-6">
      <div class="flex justify-between items-center mb-6">
        <div>
          <h1 class="text-2xl font-bold"><%= @form.title %> - 响应详情</h1>
          <div class="text-sm text-gray-500">
            提交于: <%= format_datetime(@response.submitted_at) %>
          </div>
        </div>
        
        <div class="flex gap-2">
          <button
            phx-click="back_to_responses"
            class="px-4 py-2 border border-gray-300 text-gray-700 rounded-md hover:bg-gray-100 transition"
          >
            返回回复列表
          </button>
        </div>
      </div>
      
      <div class="bg-white rounded-lg shadow-lg overflow-hidden">
        <div class="px-6 py-4 border-b border-gray-200">
          <h2 class="text-lg font-medium">回复者信息</h2>
          <div class="mt-2 grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <div class="text-sm text-gray-500">姓名</div>
              <div class="font-medium"><%= get_respondent_name(@response) %></div>
            </div>
            <div>
              <div class="text-sm text-gray-500">邮箱</div>
              <div class="font-medium"><%= get_respondent_email(@response) %></div>
            </div>
          </div>
        </div>
        
        <div class="px-6 py-4">
          <h2 class="text-lg font-medium mb-4">回复内容</h2>
          
          <div class="space-y-6">
            <%= for answer <- @response.answers do %>
              <% item = Map.get(@items_map, answer.form_item_id) %>
              <%= if item do %>
                <div class="border border-gray-200 rounded-lg p-4 answer-item">
                  <div class="font-medium mb-2 question">
                    <%= item.label %>
                    <%= if item.required do %>
                      <span class="text-red-500">*</span>
                    <% end %>
                  </div>
                  
                  <div class="bg-gray-50 p-3 rounded mt-2">
                    <%= case item.type do %>
                      <% :text_input -> %>
                        <div class="text-gray-800 answer"><%= answer.value %></div>
                      
                      <% :radio -> %>
                        <% selected_option = Enum.find(item.options || [], fn opt -> opt.value == answer.value end) %>
                        <%= if selected_option do %>
                          <div class="text-gray-800 answer">
                            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-indigo-100 text-indigo-800">
                              <%= selected_option.label %>
                            </span>
                            <span class="text-gray-500 text-xs ml-2">(值: <%= answer.value %>)</span>
                          </div>
                        <% else %>
                          <div class="text-gray-800 answer"><%= answer.value %></div>
                        <% end %>
                    <% end %>
                  </div>
                </div>
              <% end %>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def render(assigns) do
    # 直接使用内嵌模板
    ~H"""
    <div class="container mx-auto p-6">
      <div class="flex justify-between items-center mb-6">
        <div>
          <h1 class="text-2xl font-bold">表单响应</h1>
          <h2 class="text-xl"><%= @form.title %></h2>
          <div class="text-sm text-gray-500">共有 <%= length(@responses) %> 条回复</div>
        </div>
        
        <div class="flex gap-2">
          <a 
            href={~p"/forms/#{@form.id}"}
            class="px-4 py-2 bg-gray-200 text-gray-800 rounded-md hover:bg-gray-300 transition"
          >
            查看表单
          </a>
          
          <a 
            href={~p"/forms"}
            class="px-4 py-2 border border-gray-300 text-gray-700 rounded-md hover:bg-gray-100 transition"
          >
            返回列表
          </a>
        </div>
      </div>
      
      <%= if Enum.empty?(@responses) do %>
        <div class="bg-white rounded-lg shadow-lg p-8 text-center">
          <div class="bg-blue-100 text-blue-700 rounded-full p-4 w-16 h-16 mx-auto mb-4 flex items-center justify-center">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-8 w-8" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
            </svg>
          </div>
          <h2 class="text-xl font-medium mb-2">暂无回复</h2>
          <p class="text-gray-600 mb-6">表单尚未收到任何回复</p>
          
          <%= if @form.status == :draft do %>
            <div class="bg-yellow-50 border border-yellow-200 rounded-md p-4 mt-4 max-w-md mx-auto">
              <div class="flex">
                <div class="text-yellow-600 mr-3">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                  </svg>
                </div>
                <div>
                  <p class="text-yellow-700 font-medium">表单为草稿状态</p>
                  <p class="text-yellow-600 text-sm mt-1">请发布表单后才能收到回复</p>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      <% else %>
        <div class="bg-white rounded-lg shadow-lg overflow-hidden">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  提交者
                </th>
                <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  提交时间
                </th>
                <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  操作
                </th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <%= for response <- @responses do %>
                <tr class="response-row" id={"response-#{response.id}"}>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <div class="text-sm font-medium text-gray-900">
                      <%= get_respondent_name(response) %>
                    </div>
                    <div class="text-sm text-gray-500">
                      <%= get_respondent_email(response) %>
                    </div>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    <%= format_datetime(response.submitted_at) %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm font-medium space-x-2">
                    <a
                      href={~p"/forms/#{@form.id}/responses/#{response.id}"}
                      class="text-indigo-600 hover:text-indigo-900"
                    >
                      查看详情
                    </a>
                    <button
                      phx-click="delete_response"
                      phx-value-id={response.id}
                      id={"delete-response-#{response.id}"}
                      data-confirm="确定要删除此回复吗？此操作不可撤销。"
                      class="text-red-600 hover:text-red-900"
                    >
                      删除
                    </button>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      <% end %>
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