defmodule MyAppWeb.Scoring.FormScoreLive.Show do
  use MyAppWeb, :live_view
  
  alias MyApp.Scoring
  alias MyApp.Scoring.FormScore

  @impl true
  def mount(%{"form_id" => form_id}, _session, socket) do
    form = Scoring.get_form(form_id)
    form_score_config = Scoring.get_form_score_config(form_id)

    # 如果没有配置，创建一个默认配置
    form_score = form_score_config || %FormScore{
      form_id: form_id,
      total_score: 100,
      passing_score: 60,
      auto_score: true,
      score_visibility: :public
    }

    form_changeset = FormScore.changeset(form_score, %{})

    {:ok,
     socket
     |> assign(:form, form)
     |> assign(:form_id, form_id)
     |> assign(:form_score, form_score)
     |> assign(:form_changeset, form_changeset)
     |> assign(:page_title, "评分配置 - #{form.title}")
     |> assign(:has_rules, has_active_rules?(form_id))}
  end

  @impl true
  def handle_event("validate", %{"form_score" => form_score_params}, socket) do
    form_changeset =
      socket.assigns.form_score
      |> FormScore.changeset(form_score_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form_changeset, form_changeset)}
  end

  @impl true
  def handle_event("save", %{"form_score" => form_score_params}, socket) do
    case Scoring.setup_form_scoring(socket.assigns.form_id, form_score_params, socket.assigns.current_user) do
      {:ok, form_score} ->
        {:noreply,
         socket
         |> assign(:form_score, form_score)
         |> assign(:form_changeset, FormScore.changeset(form_score, %{}))
         |> put_flash(:info, "评分配置已保存")}

      {:error, %Ecto.Changeset{} = form_changeset} ->
        {:noreply, assign(socket, :form_changeset, form_changeset)}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "您没有权限修改此表单的评分配置")}
    end
  end

  @impl true
  def handle_event("go_to_rules", _, socket) do
    {:noreply, push_navigate(socket, to: ~p"/forms/#{socket.assigns.form_id}/scoring/rules")}
  end

  @impl true
  def handle_event("go_to_results", _, socket) do
    {:noreply, push_navigate(socket, to: ~p"/forms/#{socket.assigns.form_id}/scoring/results")}
  end

  # 检查表单是否有活跃的评分规则
  defp has_active_rules?(form_id) do
    form_id
    |> Scoring.get_score_rules_for_form()
    |> Enum.any?(& &1.is_active)
  end
end