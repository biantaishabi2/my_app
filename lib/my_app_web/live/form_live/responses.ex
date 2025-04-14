defmodule MyAppWeb.FormLive.Responses do
  use MyAppWeb, :live_view
  # 使用alias而不是import，因为我们只在模板中使用JS模块
  alias Phoenix.LiveView.JS
  import Ecto.Query

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
          <h1 class="text-2xl font-bold">{@form.title} - 响应详情</h1>
          <div class="text-sm text-gray-500">
            提交于: {format_datetime(@response.submitted_at)}
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
              <div class="font-medium">{get_respondent_name(@response)}</div>
            </div>
            <div>
              <div class="text-sm text-gray-500">邮箱</div>
              <div class="font-medium">{get_respondent_email(@response)}</div>
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
                    {item.label}
                    <%= if item.required do %>
                      <span class="text-red-500">*</span>
                    <% end %>
                  </div>

                  <div class="bg-gray-50 p-3 rounded mt-2">
                    <%= case item.type do %>
                      <% :text_input -> %>
                        <div class="text-gray-800 answer">{answer.value}</div>
                      <% :radio -> %>
                        <% selected_option =
                          Enum.find(item.options || [], fn opt -> opt.value == answer.value end) %>
                        <%= if selected_option do %>
                          <div class="text-gray-800 answer">
                            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-indigo-100 text-indigo-800">
                              {selected_option.label}
                            </span>
                            <span class="text-gray-500 text-xs ml-2">(值: {answer.value})</span>
                          </div>
                        <% else %>
                          <div class="text-gray-800 answer">{answer.value}</div>
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
          <h2 class="text-xl">{@form.title}</h2>
          <div class="text-sm text-gray-500">共有 {length(@responses)} 条回复</div>
        </div>

        <div class="flex gap-2">
          <div class="relative" phx-click-away={JS.remove_class("flex", to: "#export-dropdown")} phx-click-away={JS.add_class("hidden", to: "#export-dropdown")}>
            <button 
              phx-click={JS.add_class("flex", to: "#export-dropdown") |> JS.remove_class("hidden", to: "#export-dropdown")}
              class="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 transition flex items-center"
            >
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
              </svg>
              导出数据
            </button>
            <div id="export-dropdown" class="absolute hidden flex-col top-full right-0 mt-1 bg-white border border-gray-200 rounded-md shadow-lg z-10 min-w-[200px]">
              <button phx-click="export_responses" phx-value-include-scores="true" class="px-4 py-2 text-left hover:bg-gray-100 transition">
                导出所有回复和评分
              </button>
              <button phx-click="export_responses" phx-value-include-scores="false" class="px-4 py-2 text-left hover:bg-gray-100 transition">
                仅导出回复数据
              </button>
              <button phx-click="export_statistics" class="px-4 py-2 text-left hover:bg-gray-100 transition">
                导出统计数据
              </button>
            </div>
          </div>
          
          <div class="relative" phx-click-away={JS.remove_class("flex", to: "#scoring-dropdown")} phx-click-away={JS.add_class("hidden", to: "#scoring-dropdown")}>
            <button 
              phx-click={JS.add_class("flex", to: "#scoring-dropdown") |> JS.remove_class("hidden", to: "#scoring-dropdown")}
              class="px-4 py-2 bg-purple-600 text-white rounded-md hover:bg-purple-700 transition flex items-center"
            >
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 3.055A9.001 9.001 0 1020.945 13H11V3.055z" />
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20.488 9H15V3.512A9.025 9.025 0 0120.488 9z" />
              </svg>
              评分系统
            </button>
            <div id="scoring-dropdown" class="absolute hidden flex-col top-full right-0 mt-1 bg-white border border-gray-200 rounded-md shadow-lg z-10 min-w-[180px]">
              <a href={~p"/forms/#{@form.id}/scoring/config"} class="px-4 py-2 text-left hover:bg-gray-100 transition">
                评分配置
              </a>
              <a href={~p"/forms/#{@form.id}/scoring/rules"} class="px-4 py-2 text-left hover:bg-gray-100 transition">
                评分规则管理
              </a>
              <a href={~p"/forms/#{@form.id}/scoring/results"} class="px-4 py-2 text-left hover:bg-gray-100 transition">
                评分结果统计
              </a>
            </div>
          </div>
          
          <a
            href={~p"/forms/#{@form.id}/statistics"}
            class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition flex items-center"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-5 w-5 mr-1"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"
              />
            </svg>
            按属性分组统计
          </a>

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
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-8 w-8"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"
              />
            </svg>
          </div>
          <h2 class="text-xl font-medium mb-2">暂无回复</h2>
          <p class="text-gray-600 mb-6">表单尚未收到任何回复</p>

          <%= if @form.status == :draft do %>
            <div class="bg-yellow-50 border border-yellow-200 rounded-md p-4 mt-4 max-w-md mx-auto">
              <div class="flex">
                <div class="text-yellow-600 mr-3">
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-6 w-6"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
                    />
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
                <th
                  scope="col"
                  class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
                >
                  提交者
                </th>
                <th
                  scope="col"
                  class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
                >
                  提交时间
                </th>
                <th
                  scope="col"
                  class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
                >
                  评分状态
                </th>
                <th
                  scope="col"
                  class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
                >
                  操作
                </th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <%= for response <- @responses do %>
                <tr class="response-row" id={"response-#{response.id}"}>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <div class="text-sm font-medium text-gray-900">
                      {get_respondent_name(response)}
                    </div>
                    <div class="text-sm text-gray-500">
                      {get_respondent_email(response)}
                    </div>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {format_datetime(response.submitted_at)}
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    <%= if Map.get(response, :score) do %>
                      <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                        已评分
                      </span>
                    <% else %>
                      <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                        未评分
                      </span>
                    <% end %>
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
        # 重定向到表单列表页面
        {:ok,
         socket
         |> put_flash(:error, "表单不存在")
         |> push_navigate(to: ~p"/forms")}

      form ->
        if form.user_id == current_user.id do
          # 获取响应并加载评分数据
          responses = 
            Responses.list_responses_for_form(form_id)
            |> load_response_scores()

          {:ok,
           socket
           |> assign(:page_title, "#{form.title} - 表单回复")
           |> assign(:form, form)
           |> assign(:responses, responses)
           |> assign(:current_response, nil)
           |> assign(:live_action, :index)}
        else
          # 重定向到表单列表页面并显示错误消息
          {:ok,
           socket
           |> put_flash(:error, "您没有权限查看此表单的回复")
           |> push_navigate(to: ~p"/forms")}
        end
    end
  end

  # 显示单个回复
  def mount(%{"form_id" => form_id, "id" => response_id}, _session, socket) do
    current_user = socket.assigns.current_user

    case Forms.get_form(form_id) do
      nil ->
        # 重定向到表单列表页面
        {:ok,
         socket
         |> put_flash(:error, "表单不存在")
         |> push_navigate(to: ~p"/forms")}

      form ->
        if form.user_id == current_user.id do
          case Responses.get_response(response_id) do
            nil ->
              # 重定向到响应列表页面
              {:ok,
               socket
               |> put_flash(:error, "回复不存在")
               |> push_navigate(to: ~p"/forms/#{form_id}/responses")}

            response ->
              if response.form_id == form.id do
                items_map = build_items_map(form.items)

                {:ok,
                 socket
                 |> assign(:page_title, "查看回复详情")
                 |> assign(:form, form)
                 |> assign(:response, response)
                 |> assign(:items_map, items_map)
                 |> assign(:live_action, :show)}
              else
                # 重定向到响应列表页面
                {:ok,
                 socket
                 |> put_flash(:error, "回复与表单不匹配")
                 |> push_navigate(to: ~p"/forms/#{form_id}/responses")}
              end
          end
        else
          # 重定向到表单列表页面并显示错误消息
          {:ok,
           socket
           |> put_flash(:error, "您没有权限查看此表单的回复")
           |> push_navigate(to: ~p"/forms")}
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
           |> put_flash(:info, "回复已删除")}

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
  
  @impl true
  def handle_event("export_responses", %{"include-scores" => include_scores}, socket) do
    form_id = socket.assigns.form.id
    
    # 转换参数为布尔值
    include_scores_bool = include_scores == "true"
    
    # 导出响应数据
    case Responses.export_responses(form_id, %{include_scores: include_scores_bool}) do
      {:ok, csv_data} ->
        filename = if include_scores_bool, 
          do: "responses_with_scores_#{form_id}.csv", 
          else: "responses_#{form_id}.csv"
          
        {:noreply,
         socket
         |> put_flash(:info, "导出成功")
         |> push_event("download", %{
           filename: filename,
           content: csv_data
         })}
         
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "导出失败: #{reason}")}
    end
  end
  
  @impl true
  def handle_event("export_statistics", _params, socket) do
    form_id = socket.assigns.form.id
    
    # 导出统计数据
    case Responses.export_statistics(form_id) do
      {:ok, csv_data} ->
        {:noreply,
         socket
         |> put_flash(:info, "导出成功")
         |> push_event("download", %{
           filename: "statistics_#{form_id}.csv",
           content: csv_data
         })}
         
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "导出失败: #{reason}")}
    end
  end

  # 辅助函数

  # 构建表单项映射，以便于查找和显示
  defp build_items_map(items) do
    Enum.reduce(items, %{}, fn item, acc ->
      Map.put(acc, item.id, item)
    end)
  end
  
  # 加载响应的评分数据
  defp load_response_scores(responses) do
    # 构建响应ID到响应的映射，以便后续高效更新
    responses_map = Map.new(responses, fn r -> {r.id, r} end)
    response_ids = Map.keys(responses_map)
    
    if Enum.empty?(response_ids) do
      responses
    else
      # 查询所有相关响应的评分数据
      scores_query = 
        from rs in MyApp.Scoring.ResponseScore,
        where: rs.response_id in ^response_ids
      
      scores = MyApp.Repo.all(scores_query)
      
      # 将评分数据添加到对应的响应中
      updated_responses_map = 
        Enum.reduce(scores, responses_map, fn score, acc ->
          response = Map.get(acc, score.response_id)
          if response do
            updated_response = Map.put(response, :score, score)
            Map.put(acc, score.response_id, updated_response)
          else
            acc
          end
        end)
      
      # 返回更新后的响应列表，保持原顺序
      Enum.map(responses, fn r -> Map.get(updated_responses_map, r.id) end)
    end
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
