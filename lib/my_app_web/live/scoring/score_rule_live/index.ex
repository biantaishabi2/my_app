defmodule MyAppWeb.Scoring.ScoreRuleLive.Index do
  use MyAppWeb, :live_view

  alias MyApp.Scoring
  alias MyApp.Scoring.ScoreRule
  alias MyAppWeb.Scoring.Components.RuleListItemComponent
  alias MyAppWeb.Scoring.Components.ScoreRuleFormModalComponent

  @impl true
  def mount(%{"form_id" => form_id}, _session, socket) do
    form = Scoring.get_form(form_id)
    score_rules = Scoring.get_score_rules_for_form(form_id)

    {:ok,
     socket
     |> assign(:form, form)
     |> assign(:form_id, form_id)
     |> assign(:score_rules, score_rules)
     |> assign(:page_title, "评分规则 - #{form.title}")
     |> assign(:show_modal, false)
     |> assign(:modal_action, nil)
     |> assign(:selected_rule, nil)
     |> assign(:delete_rule_id, nil)}
  end

  @impl true
  def handle_event("delete_rule", %{"id" => rule_id}, socket) do
    # 仅保存规则ID，等待确认
    {:noreply, assign(socket, delete_rule_id: rule_id)}
  end

  @impl true
  def handle_event("confirm", %{"confirm_value" => %{"id" => rule_id}}, socket) do
    # 执行删除操作
    case get_rule_by_id(rule_id, socket.assigns.score_rules) do
      nil ->
        {:noreply, put_flash(socket, :error, "找不到评分规则")}

      rule ->
        case Scoring.delete_score_rule(rule, socket.assigns.current_user) do
          {:ok, _} ->
            score_rules = Scoring.get_score_rules_for_form(socket.assigns.form_id)
            {:noreply,
             socket
             |> assign(:score_rules, score_rules)
             |> put_flash(:info, "评分规则已删除")}

          {:error, :unauthorized} ->
            {:noreply, put_flash(socket, :error, "您没有权限删除此评分规则")}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "删除评分规则失败")}
        end
    end
  end

  @impl true
  def handle_event("cancel_confirm", _, socket) do
    {:noreply, assign(socket, delete_rule_id: nil)}
  end

  @impl true
  def handle_event("edit_rule", %{"id" => rule_id}, socket) do
    # 获取规则并打开模态窗
    case Scoring.get_score_rule(rule_id) do
      {:ok, rule} ->
        # 编辑时保留原有的max_score值，不自动重置为表单配置的total_score
        {:noreply,
         socket
         |> assign(:selected_rule, rule)
         |> assign(:modal_action, :edit)
         |> assign(:show_modal, true)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "找不到评分规则")}
    end
  end

  @impl true
  def handle_event("new_rule", _, socket) do
    # 获取表单评分配置的总分
    form_score_config = Scoring.get_form_score_config(socket.assigns.form_id)
    total_score = if form_score_config, do: form_score_config.total_score, else: 100

    # 创建新规则，打开模态窗，并传递表单总分
    {:noreply,
     socket
     |> assign(:selected_rule, %ScoreRule{form_id: socket.assigns.form_id, max_score: total_score})
     |> assign(:modal_action, :new)
     |> assign(:show_modal, true)}
  end

  @impl true
  def handle_event("close_modal", _, socket) do
    {:noreply, assign(socket, show_modal: false)}
  end

  @impl true
  def handle_info({:rule_created, _score_rule}, socket) do
    {:noreply,
     socket
     |> assign(:show_modal, false)
     |> assign(:score_rules, Scoring.get_score_rules_for_form(socket.assigns.form_id))
     |> put_flash(:info, "评分规则已创建")}
  end

  @impl true
  def handle_info({:rule_updated, _score_rule}, socket) do
    {:noreply,
     socket
     |> assign(:show_modal, false)
     |> assign(:score_rules, Scoring.get_score_rules_for_form(socket.assigns.form_id))
     |> put_flash(:info, "评分规则已更新")}
  end

  # 辅助函数，根据ID查找规则
  defp get_rule_by_id(rule_id, rules) do
    Enum.find(rules, fn rule -> rule.id == rule_id end)
  end
end
