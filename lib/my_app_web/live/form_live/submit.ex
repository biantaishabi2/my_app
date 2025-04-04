defmodule MyAppWeb.FormLive.Submit do
  use MyAppWeb, :live_view

  alias MyApp.Forms
  alias MyApp.Responses

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Forms.get_form_with_items(id) do
      nil ->
        {:ok, 
          socket
          |> put_flash(:error, "表单不存在")
          |> push_navigate(to: ~p"/forms")
        }
      
      form ->
        if form.status != :published do
          {:ok, 
            socket
            |> put_flash(:error, "表单未发布，无法填写")
            |> push_navigate(to: ~p"/forms")
          }
        else
          items_map = build_items_map(form.items)
          
          {:ok, 
            socket
            |> assign(:page_title, "填写表单 - #{form.title}")
            |> assign(:form, form)
            |> assign(:items_map, items_map)
            |> assign(:form_state, %{})
            |> assign(:errors, %{})
            |> assign(:submitted, false)
          }
        end
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", params, socket) do
    _form = socket.assigns.form
    items_map = socket.assigns.items_map
    
    # 提取表单数据，处理不同的参数格式
    form_data = cond do
      # 处理标准表单验证
      Map.has_key?(params, "form") -> 
        params["form"]
        
      # 处理单个字段变更（处理测试中的单个字段更新）
      Map.has_key?(params, "value") && Map.has_key?(params, "answer") ->
        item_id = params["answer"] |> Map.keys() |> List.first()
        value = params["value"]
        Map.put(socket.assigns.form_state || %{}, item_id, value)
        
      # 默认情况
      true -> 
        socket.assigns.form_state || %{}
    end
    
    # 执行基本验证（必填项）
    errors = validate_form_data(form_data, items_map)
    
    {:noreply, 
      socket
      |> assign(:form_state, form_data)
      |> assign(:errors, errors)
    }
  end

  @impl true
  def handle_event("submit_form", params, socket) do
    form_data = params["form"] || {}
    form = socket.assigns.form
    items_map = socket.assigns.items_map
    
    # 执行验证
    errors = validate_form_data(form_data, items_map)
    
    if Enum.empty?(errors) do
      # 准备响应数据
      current_user = socket.assigns.current_user
      respondent_info = %{
        "user_id" => current_user.id,
        "name" => current_user.name || current_user.email,
        "email" => current_user.email
      }
      
      case Responses.create_response(form.id, %{
        answers: form_data,
        respondent_info: respondent_info
      }) do
        {:ok, _response} ->
          {:noreply, 
            socket
            |> assign(:submitted, true)
            |> put_flash(:info, "表单提交成功")
          }
          
        {:error, reason} ->
          {:noreply, 
            socket
            |> put_flash(:error, "表单提交失败: #{inspect(reason)}")
          }
      end
    else
      {:noreply, 
        socket
        |> assign(:form_state, form_data)
        |> assign(:errors, errors)
      }
    end
  end

  # 辅助函数

  # 构建表单项映射，以便于验证和显示
  defp build_items_map(items) do
    Enum.reduce(items, %{}, fn item, acc ->
      Map.put(acc, item.id, item)
    end)
  end

  # 验证表单数据
  defp validate_form_data(form_data, items_map) do
    Enum.reduce(items_map, %{}, fn {id, item}, errors ->
      if item.required && (is_nil(form_data[id]) || form_data[id] == "") do
        Map.put(errors, id, "此字段为必填项")
      else
        errors
      end
    end)
  end
end