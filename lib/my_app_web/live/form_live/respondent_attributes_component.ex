defmodule MyAppWeb.FormLive.RespondentAttributesComponent do
  use MyAppWeb, :live_component

  alias MyApp.Forms
  
  @impl true
  def update(assigns, socket) do
    socket = 
      socket
      |> assign(assigns)
      |> assign_new(:respondent_attributes, fn -> assigns.form.respondent_attributes || [] end)
      |> assign_new(:editing_attribute, fn -> false end)
      |> assign_new(:current_attribute, fn -> nil end)
      |> assign_new(:current_attribute_index, fn -> nil end)
      |> assign_new(:templates, fn -> Forms.get_respondent_attribute_templates() end)
    
    {:ok, socket}
  end
  
  @impl true
  def handle_event("edit_attribute", %{"index" => index}, socket) do
    index = String.to_integer(index)
    attributes = socket.assigns.respondent_attributes
    
    if index >= 0 and index < length(attributes) do
      attribute = Enum.at(attributes, index)
      
      # 确保选项字段被初始化为列表
      attribute = ensure_options_list(attribute)
      
      {:noreply, 
       socket
       |> assign(:editing_attribute, true)
       |> assign(:current_attribute, attribute)
       |> assign(:current_attribute_index, index)}
    else
      {:noreply, socket}
    end
  end
  
  @impl true
  def handle_event("add_attribute", _params, socket) do
    # 创建新的空属性
    new_attribute = %{
      id: "",
      label: "",
      type: "text",
      required: false,
      description: "",
      options: []
    }
    
    {:noreply, 
     socket
     |> assign(:editing_attribute, true)
     |> assign(:current_attribute, new_attribute)
     |> assign(:current_attribute_index, nil)}
  end
  
  @impl true
  def handle_event("add_template_attribute", %{"template" => template_id}, socket) do
    templates = socket.assigns.templates
    
    if Map.has_key?(templates, template_id) do
      template = templates[template_id]
      
      # 确保模板属性有options字段
      template = ensure_options_list(template)
      
      {:noreply, 
       socket
       |> assign(:editing_attribute, true)
       |> assign(:current_attribute, template)
       |> assign(:current_attribute_index, nil)}
    else
      {:noreply, socket}
    end
  end
  
  @impl true
  def handle_event("remove_attribute", %{"index" => index}, socket) do
    index = String.to_integer(index)
    attributes = socket.assigns.respondent_attributes
    
    if index >= 0 and index < length(attributes) do
      updated_attributes = List.delete_at(attributes, index)
      
      # 保存更新后的属性列表
      save_attributes(socket, updated_attributes)
      
      {:noreply, 
       socket
       |> assign(:respondent_attributes, updated_attributes)}
    else
      {:noreply, socket}
    end
  end
  
  @impl true
  def handle_event("cancel_attribute_form", _params, socket) do
    {:noreply, 
     socket
     |> assign(:editing_attribute, false)
     |> assign(:current_attribute, nil)
     |> assign(:current_attribute_index, nil)}
  end
  
  @impl true
  def handle_event("attribute_type_changed", %{"value" => type}, socket) do
    current_attribute = socket.assigns.current_attribute
    
    # 更新属性类型并根据需要重置选项
    updated_attribute = 
      if type == "select" do
        # 如果切换到选择类型，确保有选项列表
        Map.put(current_attribute, :type, type)
        |> ensure_options_list()
      else
        # 其他类型不需要选项
        Map.put(current_attribute, :type, type)
      end
    
    {:noreply, assign(socket, :current_attribute, updated_attribute)}
  end
  
  @impl true
  def handle_event("add_option", _params, socket) do
    current_attribute = socket.assigns.current_attribute
    
    # 确保选项列表存在
    options = current_attribute.options || []
    
    # 创建新选项
    next_idx = length(options)
    option_letter = <<65 + next_idx::utf8>> # A=65, B=66, ...
    
    new_option = %{
      label: "选项#{option_letter}",
      value: "option_#{String.downcase(option_letter)}"
    }
    
    # 添加到选项列表
    updated_options = options ++ [new_option]
    updated_attribute = Map.put(current_attribute, :options, updated_options)
    
    {:noreply, assign(socket, :current_attribute, updated_attribute)}
  end
  
  @impl true
  def handle_event("remove_option", %{"index" => index}, socket) do
    index = String.to_integer(index)
    current_attribute = socket.assigns.current_attribute
    options = current_attribute.options || []
    
    if index >= 0 and index < length(options) do
      updated_options = List.delete_at(options, index)
      updated_attribute = Map.put(current_attribute, :options, updated_options)
      
      {:noreply, assign(socket, :current_attribute, updated_attribute)}
    else
      {:noreply, socket}
    end
  end
  
  @impl true
  def handle_event("update_attribute", %{"attribute" => attribute_params, "attribute_index" => index}, socket) when index != "" do
    index = String.to_integer(index)
    attributes = socket.assigns.respondent_attributes
    
    if index >= 0 and index < length(attributes) do
      # 处理属性参数
      processed_attribute = process_attribute_params(attribute_params)
      
      # 更新指定索引的属性
      updated_attributes = List.replace_at(attributes, index, processed_attribute)
      
      # 保存更新后的属性列表
      save_attributes(socket, updated_attributes)
      
      {:noreply, 
       socket
       |> assign(:respondent_attributes, updated_attributes)
       |> assign(:editing_attribute, false)
       |> assign(:current_attribute, nil)
       |> assign(:current_attribute_index, nil)
       |> put_flash(:info, "属性已更新")}
    else
      {:noreply, socket}
    end
  end
  
  @impl true
  def handle_event("create_attribute", %{"attribute" => attribute_params}, socket) do
    # 处理属性参数
    processed_attribute = process_attribute_params(attribute_params)
    
    # 添加到属性列表
    updated_attributes = socket.assigns.respondent_attributes ++ [processed_attribute]
    
    # 保存更新后的属性列表
    save_attributes(socket, updated_attributes)
    
    {:noreply, 
     socket
     |> assign(:respondent_attributes, updated_attributes)
     |> assign(:editing_attribute, false)
     |> assign(:current_attribute, nil)
     |> assign(:current_attribute_index, nil)
     |> put_flash(:info, "新属性已添加")}
  end
  
  # 确保属性有options字段并且是列表
  defp ensure_options_list(attribute) do
    options = Map.get(attribute, :options) || Map.get(attribute, "options") || []
    Map.put(attribute, :options, options)
  end
  
  # 处理属性参数
  defp process_attribute_params(params) do
    # 标准化键为atom
    params = 
      params
      |> Enum.map(fn {k, v} -> 
        {String.to_atom(k), v} 
      end)
      |> Map.new()
    
    # 处理required字段
    params = 
      case params[:required] do
        "true" -> Map.put(params, :required, true)
        "on" -> Map.put(params, :required, true)
        _ -> Map.put(params, :required, false)
      end
    
    # 处理options字段
    params = 
      if params[:type] == "select" do
        options = process_options_params(params)
        Map.put(params, :options, options)
      else
        params
      end
    
    params
  end
  
  # 处理选项参数
  defp process_options_params(params) do
    options_params = Map.get(params, :options, %{})
    
    options_params
    |> Enum.map(fn {idx, option} -> 
      %{
        label: option["label"] || "",
        value: option["value"] || ""
      }
    end)
    |> Enum.sort_by(fn {idx, _} -> idx end)
    |> Enum.map(fn {_, option} -> option end)
  end
  
  # 保存属性到表单
  defp save_attributes(socket, attributes) do
    form = socket.assigns.form
    
    # 调用Forms上下文函数更新表单的回答者属性
    case Forms.update_respondent_attributes(form, attributes) do
      {:ok, updated_form} ->
        send(self(), {:respondent_attributes_updated, updated_form})
      {:error, _changeset} ->
        send(self(), {:respondent_attributes_error, "无法保存回答者属性"})
    end
  end
  
  # 辅助函数：美化类型名称
  defp humanize_attribute_type("text"), do: "文本"
  defp humanize_attribute_type("email"), do: "邮箱"
  defp humanize_attribute_type("phone"), do: "电话"
  defp humanize_attribute_type("select"), do: "下拉选择"
  defp humanize_attribute_type("date"), do: "日期"
  defp humanize_attribute_type(type) when is_binary(type), do: type
  defp humanize_attribute_type(_), do: "未知类型"
end