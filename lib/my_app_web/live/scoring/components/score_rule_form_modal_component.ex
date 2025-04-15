defmodule MyAppWeb.Scoring.Components.ScoreRuleFormModalComponent do
  use MyAppWeb, :live_component

  alias MyApp.Scoring
  alias MyAppWeb.Scoring.Components.ScoreRuleEditorComponent

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:rules, %{"items" => []})}
  end

  @impl true
  def update(%{score_rule: score_rule} = assigns, socket) do
    changeset = Scoring.change_score_rule(score_rule)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)
     |> assign(:rules, score_rule.rules || %{"items" => []})}
  end

  @impl true
  def handle_event("validate", %{"score_rule" => score_rule_params}, socket) do
    changeset =
      socket.assigns.score_rule
      |> Scoring.change_score_rule(score_rule_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"score_rule" => score_rule_params}, socket) do
    # 在保存时，从编辑器组件中获取的规则数据已经在socket.assigns.rules中
    # 确保使用正确的规则数据结构
    rules = socket.assigns.rules

    # 合并规则数据和用户ID
    score_rule_params = Map.merge(score_rule_params, %{
      "rules" => rules,
      "user_id" => socket.assigns.current_user.id
    })

    # 将所有键转换为字符串类型
    score_rule_params = for {k, v} <- score_rule_params, into: %{} do
      {to_string(k), v}
    end

    save_score_rule(socket, socket.assigns.action, score_rule_params)
  end

  @impl true
  def handle_event("update_rules", %{"rules" => rules}, socket) do
    {:noreply, assign(socket, :rules, rules)}
  end

  defp save_score_rule(socket, :edit, score_rule_params) do
    case Scoring.update_score_rule(socket.assigns.score_rule, score_rule_params, socket.assigns.current_user) do
      {:ok, _score_rule} ->
        {:noreply,
         socket
         |> put_flash(:info, "评分规则更新成功")
         |> push_navigate(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}

      {:error, :unauthorized} ->
        {:noreply,
         socket
         |> put_flash(:error, "您没有权限编辑此规则")
         |> push_navigate(to: socket.assigns.return_to)}
    end
  end

  defp save_score_rule(socket, :new, score_rule_params) do
    case Scoring.create_score_rule(score_rule_params, socket.assigns.current_user) do
      {:ok, _score_rule} ->
        {:noreply,
         socket
         |> put_flash(:info, "评分规则创建成功")
         |> push_navigate(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}

      {:error, :unauthorized} ->
        {:noreply,
         socket
         |> put_flash(:error, "您没有权限创建规则")
         |> push_navigate(to: socket.assigns.return_to)}
    end
  end

  # 移除接收规则编辑器组件传来的规则更新
end
