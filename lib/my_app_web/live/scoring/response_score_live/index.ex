defmodule MyAppWeb.Scoring.ResponseScoreLive.Index do
  use MyAppWeb, :live_view

  alias MyApp.Scoring
  alias MyApp.Responses
  alias MyAppWeb.Scoring.Components.ScoreDisplayComponent
  
  # 使用辅助函数模块
  import MyAppWeb.Scoring.Helpers, only: [format_datetime: 1, get_respondent_name: 1]

  @impl true
  def mount(%{"form_id" => form_id}, _session, socket) do
    form = Scoring.get_form(form_id)
    # 获取表单所有响应
    responses = Responses.list_responses_for_form(form_id)
    # 获取表单得分配置
    form_score_config = Scoring.get_form_score_config(form_id)
    # 获取评分结果
    response_scores = Scoring.get_response_scores_for_form(form_id)
    
    # 构建响应ID到评分的映射
    scores_map = Map.new(response_scores, fn score -> {score.response_id, score} end)

    {:ok,
     socket
     |> assign(:form, form)
     |> assign(:form_id, form_id)
     |> assign(:responses, responses)
     |> assign(:scores_map, scores_map)
     |> assign(:form_score_config, form_score_config)
     |> assign(:page_title, "评分结果 - #{form.title}")}
  end
  
  @impl true
  def handle_event("score_response", %{"id" => response_id}, socket) do
    # 手动触发单个响应的评分计算
    case Scoring.score_response(response_id) do
      {:ok, response_score} ->
        # 更新评分映射
        scores_map = Map.put(socket.assigns.scores_map, response_id, response_score)
        {:noreply, 
         socket
         |> assign(:scores_map, scores_map)
         |> put_flash(:info, "响应评分完成")}
         
      {:error, :already_scored} ->
        {:noreply, put_flash(socket, :error, "该响应已有评分")}
        
      {:error, :score_rule_not_found} ->
        {:noreply, put_flash(socket, :error, "未找到激活的评分规则")}
        
      {:error, :form_score_config_not_found} ->
        {:noreply, put_flash(socket, :error, "未找到表单评分配置")}
        
      {:error, :auto_score_disabled} ->
        {:noreply, put_flash(socket, :error, "自动评分功能已禁用")}
        
      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "评分失败")}
    end
  end
  
  @impl true
  def handle_event("go_to_config", _, socket) do
    {:noreply, push_navigate(socket, to: ~p"/forms/#{socket.assigns.form_id}/scoring/config")}
  end
  
  @impl true
  def handle_event("go_to_rules", _, socket) do
    {:noreply, push_navigate(socket, to: ~p"/forms/#{socket.assigns.form_id}/scoring/rules")}
  end
  
  @impl true
  def handle_event("view_response_score", %{"id" => response_id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/responses/#{response_id}/scoring/result")}
  end
end