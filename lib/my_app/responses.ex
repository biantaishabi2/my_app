defmodule MyApp.Responses do
  @moduledoc """
  The Responses context.
  """

  import Ecto.Query, warn: false
  alias MyApp.Repo
  alias MyApp.Forms
  alias MyApp.Responses.Response
  alias MyApp.Responses.Answer

  @doc """
  Creates a response with answers for a published form.

  ## Parameters
    - form_id: ID of the form being responded to
    - answers_map: Map of form_item_id => answer value

  ## Examples

      iex> create_response(form_id, %{item1_id => "answer1", item2_id => "answer2"})
      {:ok, %Response{}}

      iex> create_response(form_id, %{})
      {:error, :validation_failed}

      iex> create_response(invalid_id, %{})
      {:error, :form_not_found}

  """
  def create_response(form_id, answers_map) do
    # Get the form and verify it exists
    case Forms.get_form(form_id) do
      nil ->
        {:error, :form_not_found}

      form ->
        # Load form items and their options for validation
        form = Repo.preload(form, [items: :options])

        # Check if form is published
        if form.status != :published do
          {:error, :form_not_published}
        else
          # Validate answers against form items
          validation_result = validate_answers(form, answers_map)

          case validation_result do
            :ok ->
              # Create the response in a transaction
              result = Repo.transaction(fn ->
                # Create response
                now = DateTime.utc_now()
                response_attrs = %{
                  form_id: form_id,
                  submitted_at: now,
                  inserted_at: now,
                  updated_at: now
                }

                case %Response{}
                     |> Response.changeset(response_attrs)
                     |> Repo.insert() do
                  {:ok, response} ->
                    # Create answers for each provided answer
                    answers = 
                      Enum.map(answers_map, fn {item_id, value} ->
                        answer_attrs = %{
                          response_id: response.id,
                          form_item_id: item_id,
                          value: %{"value" => value},
                          inserted_at: now,
                          updated_at: now
                        }

                        case %Answer{}
                             |> Answer.changeset(answer_attrs)
                             |> Repo.insert() do
                          {:ok, answer} -> answer
                          {:error, changeset} -> Repo.rollback(changeset)
                        end
                      end)

                    # Return response with answers
                    %{response | answers: answers}
                    
                  {:error, changeset} ->
                    Repo.rollback(changeset)
                end
              end)
              
              result

            {:error, reason} ->
              {:error, reason}
          end
        end
    end
  end

  # Validate that all required items have answers and all answers are valid
  defp validate_answers(form, answers_map) do
    with :ok <- validate_required_items(form.items, answers_map),
         :ok <- validate_radio_values(form.items, answers_map) do
      :ok
    end
  end
  
  # Validate all required items have answers
  defp validate_required_items(items, answers_map) do
    missing_required = Enum.filter(items, fn item -> 
      item.required && !Map.has_key?(answers_map, item.id)
    end)

    if length(missing_required) > 0 do
      {:error, :validation_failed}
    else
      :ok
    end
  end
  
  # Validate radio answers have valid option values
  defp validate_radio_values(items, answers_map) do
    invalid_radio = Enum.find(items, fn item ->
      if item.type == :radio && Map.has_key?(answers_map, item.id) do
        answer_value = answers_map[item.id]
        valid_values = Enum.map(item.options, & &1.value)
        answer_value not in valid_values
      else
        false
      end
    end)

    if invalid_radio do
      {:error, :validation_failed}
    else
      :ok
    end
  end

  @doc """
  Gets a single response by ID.
  Preloads associated answers.

  Returns nil if the response does not exist.

  ## Examples

      iex> get_response(123)
      %Response{answers: [...]}

      iex> get_response(456)
      nil

  """
  def get_response(id) do
    Response
    |> Repo.get(id)
    |> preload_response_answers()
  end
  
  @doc """
  Preloads answers for a response.
  This is a utility function to standardize preloading across different functions.
  Returns nil if the response is nil.
  
  ## Examples
  
      iex> preload_response_answers(response)
      %Response{answers: [...]}
      
  """
  def preload_response_answers(nil), do: nil
  def preload_response_answers(response) do
    Repo.preload(response, [
      answers: from(a in Answer, order_by: a.inserted_at)
    ])
  end

  @doc """
  Lists all responses for a specific form.

  ## Examples

      iex> list_responses_for_form(form_id)
      [%Response{}, ...]

      iex> list_responses_for_form(non_existent_id)
      []

  """
  def list_responses_for_form(form_id) do
    responses = Response
    |> where([r], r.form_id == ^form_id)
    |> order_by([r], desc: r.submitted_at)
    |> Repo.all()
    
    # 使用批量预加载而不是单独加载每个响应
    Repo.preload(responses, [
      answers: from(a in Answer, order_by: a.inserted_at)
    ])
  end

  @doc """
  Deletes a response and its associated answers.

  Supports both passing a response struct or a map with an ID.
  Returns {:ok, deleted_response} if successful, or
  {:error, :not_found} if the response doesn't exist.

  ## Examples

      iex> delete_response(response)
      {:ok, %Response{}}

      iex> delete_response(%{id: non_existent_id})
      {:error, :not_found}

  """
  def delete_response(%{id: id} = _response) when is_binary(id) do
    case get_response(id) do
      nil -> {:error, :not_found}
      response -> Repo.delete(response)
    end
  end

  def delete_response(%Response{} = response) do
    Repo.delete(response)
  end
end 