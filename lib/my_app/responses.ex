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
    # Check if all required items have answers
    missing_required = Enum.filter(form.items, fn item -> 
      item.required && !Map.has_key?(answers_map, item.id)
    end)

    if length(missing_required) > 0 do
      {:error, :validation_failed}
    else
      # Validate radio answers
      invalid_radio = Enum.find(form.items, fn item ->
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
    |> Repo.preload(:answers)
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
    Response
    |> where([r], r.form_id == ^form_id)
    |> Repo.all()
    |> Repo.preload(:answers)
  end
end 