# test/my_app/response_delete_test.exs
defmodule MyApp.ResponseDeleteTest do
  use MyApp.DataCase, async: false

  alias MyApp.Forms
  alias MyApp.Responses
  alias MyApp.Responses.Response

  import MyApp.AccountsFixtures

  # Helper function to set up a published form with items for testing responses
  defp setup_published_form(_) do
    # 创建一个测试用户
    user = user_fixture()

    # 1. Create a form
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
      user: user,
      form: published_form,
      text_item: text_item,
      radio_item: radio_item,
      radio_options: [option1, option2, option3]
    }
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
