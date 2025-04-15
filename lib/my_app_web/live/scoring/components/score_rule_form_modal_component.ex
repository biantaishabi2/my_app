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

  # 处理来自编辑器组件的规则更新
  @impl true
  def update(%{rules: rules} = _assigns, socket) do
    # 这里我们只接收并更新rules
    IO.puts("接收到规则更新 - 规则项数量: #{length(rules["items"] || [])}")
    {:ok, assign(socket, :rules, rules)}
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
    # 从socket获取当前编辑器组件的规则
    # 这比从隐藏字段获取更可靠
    current_rules = socket.assigns.rules || %{"items" => []}

    # 输出调试信息，帮助确认规则数据是否正确获取
    IO.puts("保存规则 - 规则项数量: #{length(current_rules["items"] || [])}")
    IO.inspect(current_rules, label: "当前规则数据")

    # 使用字符串键，避免混合键类型错误
    score_rule_params = Map.merge(score_rule_params, %{
      "rules" => current_rules,
      "user_id" => socket.assigns.current_user.id
    })

    # 不需要再次转换键，确保所有键都是字符串类型
    save_score_rule(socket, socket.assigns.action, score_rule_params)
  end

  @impl true
  def handle_event("update_rules", %{"rules" => rules}, socket) do
    {:noreply, assign(socket, :rules, rules)}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply, push_navigate(socket, to: socket.assigns.return_to)}
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
