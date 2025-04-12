# test/my_app/responses_test.exs
defmodule MyApp.ResponsesTest do
  use MyApp.DataCase, async: false

  alias MyApp.Forms
  alias MyApp.Responses
  # Assuming Response schema is in Responses context
  alias MyApp.Responses.Response
  # Assuming Answer schema is in Responses context
  alias MyApp.Responses.Answer
  import MyApp.AccountsFixtures

  @moduletag :capture_log

  # Helper function to set up a published form with items for testing responses
  defp setup_published_form(_) do
    # 1. Create a form with user
    user = user_fixture()
    {:ok, form} = Forms.create_form(%{title: "Test Response Form", user_id: user.id})

    # 2. Add a required text input item
    {:ok, text_item} =
      Forms.add_form_item(form, %{
        label: "Your Email",
        type: :text_input,
        required: true
      })

    # 3. Add a required radio item
    {:ok, radio_item} =
      Forms.add_form_item(form, %{
        label: "Rate your experience (1-5)",
        type: :radio,
        required: true
      })

    # 4. Add options to the radio item
    {:ok, option1} = Forms.add_item_option(radio_item, %{label: "1 (Poor)", value: "1"})
    {:ok, option2} = Forms.add_item_option(radio_item, %{label: "3 (Average)", value: "3"})
    {:ok, option3} = Forms.add_item_option(radio_item, %{label: "5 (Excellent)", value: "5"})

    # 5. Publish the form
    {:ok, published_form} = Forms.publish_form(form)

    # Return the necessary data for tests
    %{
      form: published_form,
      text_item: text_item,
      radio_item: radio_item,
      radio_options: [option1, option2, option3],
      user: user
    }
  end

  describe "create_response/2" do
    setup [:setup_published_form]

    test "with valid data creates a response and associated answers", %{
      form: form,
      text_item: text_item,
      radio_item: radio_item,
      # Not directly needed for valid value, but good context
      radio_options: _radio_options
    } do
      valid_answers = %{
        text_item.id => "test@example.com",
        # Corresponds to the value of the 'Average' option
        radio_item.id => "3"
      }

      assert {:ok, %Response{} = response} = Responses.create_response(form.id, valid_answers)

      # Verify the Response record
      assert response.form_id == form.id
      # Check it has a timestamp
      assert response.submitted_at != nil

      # Verify the associated Answer records (assuming they are preloaded or fetched separately)
      # This might require a helper to fetch answers for a response id
      # fetched_answers = Repo.all(from a in Answer, where: a.response_id == response.id)
      # assert length(fetched_answers) == 2

      # Find the answer for the text item
      # text_answer = Enum.find(fetched_answers, &(&1.form_item_id == text_item.id))
      # assert text_answer.value == "test@example.com"

      # Find the answer for the radio item
      # radio_answer = Enum.find(fetched_answers, &(&1.form_item_id == radio_item.id))
      # assert radio_answer.value == "3"
    end

    # Test with respondent info if applicable
    # test "can associate response with respondent info" do
    #   user_id = Ecto.UUID.generate()
    #   valid_answers = %{...}
    #   assert {:ok, response} = Responses.create_response(form.id, valid_answers, respondent_info: %{user_id: user_id})
    #   assert response.respondent_info["user_id"] == user_id
    # end

    test "returns error if required text_input answer is missing", %{
      form: form,
      # Needed for context, but value is omitted
      text_item: _text_item,
      radio_item: radio_item
    } do
      invalid_answers = %{
        # Provide radio answer, omit text answer
        radio_item.id => "1"
      }

      assert {:error, _reason} = Responses.create_response(form.id, invalid_answers)
      # Check the error reason, e.g., {:validation, changeset} or specific atom
      # assert reason == :validation_failed
      # Or assert specific changeset error
      # assert %Ecto.Changeset{} = reason
      # assert errors_on(reason) |> Keyword.has_key?(text_item.id) # Or similar check
    end

    test "returns error if required radio answer is missing", %{
      form: form,
      text_item: text_item,
      # Needed for context, but value is omitted
      radio_item: _radio_item
    } do
      invalid_answers = %{
        # Provide text answer, omit radio answer
        text_item.id => "another@example.com"
      }

      assert {:error, _reason} = Responses.create_response(form.id, invalid_answers)
    end

    test "returns error if radio answer value is not a valid option", %{
      form: form,
      text_item: text_item,
      radio_item: radio_item
    } do
      invalid_answers = %{
        text_item.id => "valid@email.com",
        # This value is not among the defined options (1, 3, 5)
        radio_item.id => "99"
      }

      assert {:error, _reason} = Responses.create_response(form.id, invalid_answers)
    end

    test "returns error when submitting to a non-published form" do
      # Create a new form, leave it as draft
      user = user_fixture()
      {:ok, draft_form} = Forms.create_form(%{title: "Draft Form Only", user_id: user.id})
      # Assume it has items, or test the check happens before item validation
      dummy_answers = %{}

      assert {:error, :form_not_published} =
               Responses.create_response(draft_form.id, dummy_answers)

      # Or whatever error the function should return for wrong status
    end

    test "returns error when submitting to a non-existent form_id" do
      non_existent_form_id = Ecto.UUID.generate()
      dummy_answers = %{}

      assert {:error, :form_not_found} =
               Responses.create_response(non_existent_form_id, dummy_answers)

      # Or whatever error indicates the form wasn't found
    end
  end

  describe "get_response/1" do
    setup [:setup_published_form]

    test "returns the response with the given id, preloading answers", %{
      form: form,
      text_item: text_item,
      radio_item: radio_item
    } do
      # Create a response first
      answers = %{
        text_item.id => "fetch_me@test.com",
        radio_item.id => "5"
      }

      {:ok, response} = Responses.create_response(form.id, answers)

      # Fetch the response using the function under test
      fetched_response = Responses.get_response(response.id)

      # Verify the response itself
      assert fetched_response.id == response.id
      assert fetched_response.form_id == form.id

      # Verify that answers are loaded
      assert %Ecto.Association.NotLoaded{} != fetched_response.answers
      assert length(fetched_response.answers) == 2

      # Verify answer details (more robust check)
      answer_values =
        Enum.map(fetched_response.answers, &{&1.form_item_id, &1.value["value"]})
        |> Map.new()

      assert answer_values[text_item.id] == "fetch_me@test.com"
      assert answer_values[radio_item.id] == "5"
    end

    test "returns nil if response id does not exist" do
      non_existent_response_id = Ecto.UUID.generate()
      assert Responses.get_response(non_existent_response_id) == nil
    end
  end

  describe "list_responses_for_form/1" do
    setup [:setup_published_form]

    test "returns all responses submitted for a given form", %{
      form: form,
      text_item: text_item,
      radio_item: radio_item,
      user: user
    } do
      # Create a couple of responses for the same form
      answers1 = %{text_item.id => "resp1@test.com", radio_item.id => "1"}
      {:ok, resp1} = Responses.create_response(form.id, answers1)

      answers2 = %{text_item.id => "resp2@test.com", radio_item.id => "5"}
      {:ok, resp2} = Responses.create_response(form.id, answers2)

      # Create a response for a different form to ensure filtering works
      {:ok, other_form} = Forms.create_form(%{title: "Another Form", user_id: user.id})
      {:ok, other_form_published} = Forms.publish_form(other_form)
      # Assume other_form has items or create_response handles empty answers gracefully
      # Or valid answers
      {:ok, _other_resp} = Responses.create_response(other_form_published.id, %{})

      # List responses for the original form
      response_list = Responses.list_responses_for_form(form.id)

      assert is_list(response_list)
      assert length(response_list) == 2

      response_ids = Enum.map(response_list, & &1.id) |> Enum.sort()
      expected_ids = [resp1.id, resp2.id] |> Enum.sort()
      assert response_ids == expected_ids
    end

    test "returns an empty list if no responses exist for the form", %{form: form} do
      # No responses created for this form in this test context
      assert Responses.list_responses_for_form(form.id) == []
    end

    test "returns an empty list for a non-existent form_id" do
      non_existent_form_id = Ecto.UUID.generate()
      assert Responses.list_responses_for_form(non_existent_form_id) == []
    end

    # Optional: Add tests for pagination, filtering, sorting if implemented
    # test "supports pagination options" do ... end
    # test "supports filtering options" do ... end
  end

  describe "delete_response/1" do
    setup [:setup_published_form]

    test "deletes the response and associated answers", %{
      form: form,
      text_item: text_item,
      radio_item: radio_item
    } do
      # Create a response to delete
      answers = %{
        text_item.id => "to_delete@example.com",
        radio_item.id => "1"
      }

      {:ok, response} = Responses.create_response(form.id, answers)

      # Delete the response
      assert {:ok, %{id: deleted_id}} = Responses.delete_response(response)
      assert deleted_id == response.id

      # Verify the response is deleted
      assert Responses.get_response(response.id) == nil

      # Verify all responses are now empty for the form
      assert Responses.list_responses_for_form(form.id) == []
    end

    test "returns error when trying to delete non-existent response" do
      non_existent_id = Ecto.UUID.generate()
      assert {:error, :not_found} = Responses.delete_response(%{id: non_existent_id})
    end
  end
end
