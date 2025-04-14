defmodule MyAppWeb.Scoring.ResponseScoreLive.Show do
  use MyAppWeb, :live_view

  alias MyApp.Scoring
  alias MyApp.Responses
  alias MyAppWeb.Scoring.Components.ScoreDisplayComponent
  
  # 使用辅助函数模块
  import MyAppWeb.Scoring.Helpers, only: [format_datetime: 1, format_answer: 1, format_scoring_method: 1]

  @impl true
  def mount(%{"response_id" => response_id}, _session, socket) do
    case Scoring.get_response_score_for_response(response_id) do
      {:ok, response_score} ->
        # 预加载响应关联的数据
        response = response_score.response |> Responses.preload_response_answers()
        form = response.form
        form_score_config = Scoring.get_form_score_config(form.id)
        
        # 获取评分规则
        {:ok, score_rule} = Scoring.get_score_rule(response_score.score_rule_id)
        
        # 构建题目ID到评分项的映射
        rule_items = score_rule.rules["items"] || []
        rule_items_map = Map.new(rule_items, fn item -> {item["item_id"], item} end)
        
        # 获取题目ID到答案的映射
        answers_map = Map.new(response.answers, fn answer -> {answer.form_item_id, answer} end)
        
        # 评分明细数据
        score_details = response_score.score_details || %{}
        
        {:ok,
         socket
         |> assign(:response, response)
         |> assign(:form, form)
         |> assign(:form_score_config, form_score_config)
         |> assign(:response_score, response_score)
         |> assign(:score_rule, score_rule)
         |> assign(:rule_items_map, rule_items_map)
         |> assign(:answers_map, answers_map)
         |> assign(:score_details, score_details)
         |> assign(:page_title, "评分详情 - #{response.id}")}
         
      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "未找到评分结果")
         |> redirect(to: ~p"/forms")}
    end
  end
  
  @impl true
  def handle_event("go_back", _, socket) do
    form_id = socket.assigns.form.id
    {:noreply, push_navigate(socket, to: ~p"/forms/#{form_id}/scoring/results")}
  end
end