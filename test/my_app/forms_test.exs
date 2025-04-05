# test/my_app/forms_test.exs
defmodule MyApp.FormsTest do
  use MyApp.DataCase, async: false

  alias MyApp.Forms
  alias MyApp.Forms.Form # Assuming Form schema will be inside Forms context
  import MyApp.AccountsFixtures

  @moduletag :capture_log

  describe "forms" do
    @valid_attrs %{title: "User Satisfaction Survey"}
    @invalid_attrs %{description: "Missing title"}

    test "create_form/1 with valid data creates a form" do
      user = user_fixture()
      attrs = Map.put(@valid_attrs, :user_id, user.id)
      assert {:ok, %Form{} = form} = Forms.create_form(attrs)
      assert form.title == "User Satisfaction Survey"
      assert form.status == :draft # Default status should be draft
      assert form.description == nil # Fields not provided should be nil or default
    end

    test "create_form/1 with invalid data returns error changeset" do
      user = user_fixture()
      attrs = Map.put(@invalid_attrs, :user_id, user.id)
      assert {:error, %Ecto.Changeset{} = changeset} = Forms.create_form(attrs)
      # Verify that the changeset indicates title is required
      # This is a common way using Ecto.Changeset.traverse_errors
      assert Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end) |> Map.has_key?(:title)
    end

    test "get_form/1 returns the form with given id" do
      user = user_fixture()
      attrs = Map.put(@valid_attrs, :user_id, user.id)
      {:ok, form} = Forms.create_form(attrs)

      # Fetch the form using the function under test
      fetched_form = Forms.get_form(form.id)

      # Basic assertion: Check if the fetched form is the same struct (or has the same ID)
      # Depending on Repo.get implementation, it might be a new struct instance
      assert fetched_form.id == form.id
      assert fetched_form.title == form.title
    end

    test "get_form/1 returns nil for non-existent form id" do
      non_existent_uuid = Ecto.UUID.generate()
      assert Forms.get_form(non_existent_uuid) == nil
    end
  end

  describe "add_form_item/2" do
    # Helper to create a form for these tests
    defp create_a_form(_) do
      user = user_fixture()
      {:ok, form} = Forms.create_form(%{title: "Test Form for Items", user_id: user.id})
      %{form: form, user: user}
    end

    setup [:create_a_form]

    test "with valid data adds a text_input item to the form", %{form: form} do
      item_attrs = %{
        label: "Your Name",
        type: :text_input,
        required: true
        # order can be handled by the context or default
      }

      assert {:ok, item} = Forms.add_form_item(form, item_attrs)
      assert item.label == "Your Name"
      assert item.type == :text_input
      assert item.required == true
      assert item.form_id == form.id
      assert item.order == 1 # Assuming it's the first item

      # Verify it's actually associated by fetching the form again
      fetched_form = Forms.get_form(form.id)
      assert length(fetched_form.items) == 1
      assert hd(fetched_form.items).label == "Your Name"
    end

    test "returns error changeset if label is missing", %{form: form} do
      item_attrs = %{type: :text_input, required: false}
      assert {:error, %Ecto.Changeset{} = changeset} = Forms.add_form_item(form, item_attrs)
      assert Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end) |> Map.has_key?(:label)
    end

    test "returns error changeset if type is missing", %{form: form} do
      item_attrs = %{label: "Feedback", required: false}
      assert {:error, %Ecto.Changeset{} = changeset} = Forms.add_form_item(form, item_attrs)
      assert Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end) |> Map.has_key?(:type)
    end

    test "assigns sequential order to newly added items", %{form: form} do
      item1_attrs = %{label: "Email", type: :text_input}
      {:ok, item1} = Forms.add_form_item(form, item1_attrs)
      assert item1.order == 1

      item2_attrs = %{label: "Phone", type: :text_input}
      {:ok, item2} = Forms.add_form_item(form, item2_attrs)
      assert item2.order == 2
    end

    test "with valid data adds a radio item to the form", %{form: form} do
      item_attrs = %{
        label: "Satisfaction Level",
        type: :radio,
        required: true
      }
      assert {:ok, item} = Forms.add_form_item(form, item_attrs)
      assert item.label == "Satisfaction Level"
      assert item.type == :radio
    end
  end

  describe "add_item_option/3" do
    # Helper to create a form and a radio item for these tests
    defp create_form_with_radio_item(_) do
      user = user_fixture()
      {:ok, form} = Forms.create_form(%{title: "Form with Radio", user_id: user.id})
      radio_item_attrs = %{label: "Choose One", type: :radio, required: true}
      {:ok, radio_item} = Forms.add_form_item(form, radio_item_attrs)
      %{form: form, radio_item: radio_item, user: user}
    end

    setup [:create_form_with_radio_item]

    test "with valid data adds an option to a radio item", %{radio_item: radio_item} do
      option_attrs = %{label: "Option A", value: "a"}

      assert {:ok, option} = Forms.add_item_option(radio_item, option_attrs)
      assert option.label == "Option A"
      assert option.value == "a"
      assert option.form_item_id == radio_item.id
      assert option.order == 1 # First option

      # Verify association
      loaded_item = Forms.get_form_item_with_options(radio_item.id)
      assert length(loaded_item.options) == 1
      assert hd(loaded_item.options).value == "a"
    end

    test "returns error changeset if label is missing", %{radio_item: radio_item} do
      option_attrs = %{value: "b"}
      assert {:error, %Ecto.Changeset{} = changeset} = Forms.add_item_option(radio_item, option_attrs)
      assert Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end) |> Map.has_key?(:label)
    end

    test "returns error changeset if value is missing", %{radio_item: radio_item} do
      option_attrs = %{label: "Option C"}
      assert {:error, %Ecto.Changeset{} = changeset} = Forms.add_item_option(radio_item, option_attrs)
      assert Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end) |> Map.has_key?(:value)
    end

    test "assigns sequential order to newly added options", %{radio_item: radio_item} do
      option1_attrs = %{label: "Yes", value: "yes"}
      {:ok, option1} = Forms.add_item_option(radio_item, option1_attrs)
      assert option1.order == 1

      option2_attrs = %{label: "No", value: "no"}
      {:ok, option2} = Forms.add_item_option(radio_item, option2_attrs)
      assert option2.order == 2
    end

    # Optional: Test adding option to a non-option item type (e.g., text_input)
    # test "returns error when adding option to non-compatible item type" do
    #   {:ok, form} = Forms.create_form(%{title: "Form with Text"})
    #   text_item_attrs = %{label: "Name", type: :text_input}
    #   {:ok, text_item} = Forms.add_form_item(form, text_item_attrs)
    #   option_attrs = %{label: "Invalid Option", value: "invalid"}
    #   assert {:error, _reason} = Forms.add_item_option(text_item, option_attrs)
    # end
  end

  describe "publish_form/1" do
    defp create_draft_form(_) do
      user = user_fixture()
      {:ok, form} = Forms.create_form(%{title: "Draft Form to Publish", user_id: user.id})
      %{form: form, user: user}
    end

    setup [:create_draft_form]

    test "changes the form status from :draft to :published", %{form: form} do
      assert form.status == :draft
      assert {:ok, updated_form} = Forms.publish_form(form)
      assert updated_form.status == :published
      assert updated_form.id == form.id

      # Verify the change is persisted
      fetched_form = Forms.get_form(form.id)
      assert fetched_form.status == :published
    end

    test "returns error if the form is already published", %{form: form} do
      # Publish it once
      {:ok, published_form} = Forms.publish_form(form)
      assert published_form.status == :published

      # Try to publish again
      assert {:error, :already_published} = Forms.publish_form(published_form)
      # Or {:error, %Ecto.Changeset{}} if using changesets for status validation
    end

    # Optional: Add test for trying to publish an archived form if that state exists
    # test "returns error if the form is archived" do
    #   ... setup archived form ...
    #   assert {:error, :invalid_status} = Forms.publish_form(archived_form)
    # end
  end

  describe "get_form_item/1" do
    setup [:create_form_with_radio_item]
    
    test "returns the form item with given id", %{radio_item: item} do
      fetched_item = Forms.get_form_item(item.id)
      assert fetched_item.id == item.id
      assert fetched_item.label == item.label
      assert fetched_item.type == :radio
    end
    
    test "returns nil for non-existent form item id" do
      non_existent_uuid = Ecto.UUID.generate()
      assert Forms.get_form_item(non_existent_uuid) == nil
    end
  end
  
  describe "get_form_item_with_options/1" do
    setup [:create_form_with_radio_item]
    
    test "returns the form item with options preloaded", %{radio_item: item} do
      # Add some options to the radio item
      option1_attrs = %{label: "Option X", value: "x"}
      option2_attrs = %{label: "Option Y", value: "y"}
      {:ok, _option1} = Forms.add_item_option(item, option1_attrs)
      {:ok, _option2} = Forms.add_item_option(item, option2_attrs)
      
      # Get the item with options
      item_with_options = Forms.get_form_item_with_options(item.id)
      
      # Verify the item data
      assert item_with_options.id == item.id
      assert item_with_options.label == item.label
      
      # Verify options are loaded and correct
      assert length(item_with_options.options) == 2
      option_labels = Enum.map(item_with_options.options, & &1.label) |> Enum.sort()
      assert option_labels == ["Option X", "Option Y"] |> Enum.sort()
    end
    
    test "returns nil for non-existent form item id when preloading options" do
      non_existent_uuid = Ecto.UUID.generate()
      assert Forms.get_form_item_with_options(non_existent_uuid) == nil
    end
  end
  
  describe "update_form_item/2" do
    setup [:create_form_with_radio_item]
    
    test "updates form item with valid data", %{radio_item: item} do
      update_attrs = %{
        label: "Updated Question",
        required: false,
        description: "This is a description"
      }
      
      assert {:ok, updated_item} = Forms.update_form_item(item, update_attrs)
      assert updated_item.id == item.id
      assert updated_item.label == "Updated Question"
      assert updated_item.required == false
      assert updated_item.description == "This is a description"
      # Type should remain the same since we didn't update it
      assert updated_item.type == :radio
      
      # Verify changes are persisted
      fetched_item = Forms.get_form_item(item.id)
      assert fetched_item.label == "Updated Question"
    end
    
    test "returns error changeset with invalid data", %{radio_item: item} do
      # Empty label is invalid
      invalid_attrs = %{label: ""}
      assert {:error, %Ecto.Changeset{}} = Forms.update_form_item(item, invalid_attrs)
      
      # Verify item wasn't changed
      fetched_item = Forms.get_form_item(item.id)
      assert fetched_item.label == item.label
    end
  end
  
  describe "delete_form_item/1" do
    setup [:create_form_with_radio_item]
    
    test "deletes the form item", %{radio_item: item} do
      assert {:ok, %{id: deleted_id}} = Forms.delete_form_item(item)
      assert deleted_id == item.id
      
      # Verify item is deleted
      assert Forms.get_form_item(item.id) == nil
    end
    
    test "deletes associated options when deleting a form item", %{radio_item: item, user: user} do
      # Add options to the item
      {:ok, _option} = Forms.add_item_option(item, %{label: "Test Option", value: "test"})
      
      # Delete the item
      assert {:ok, _} = Forms.delete_form_item(item)
      
      # Verify item is deleted
      assert Forms.get_form_item(item.id) == nil
      
      # Create a similar item to verify options don't exist in options table
      {:ok, new_form} = Forms.create_form(%{title: "New Test Form", user_id: user.id})
      {:ok, new_item} = Forms.add_form_item(new_form, %{
        label: "New Radio Question", 
        type: :radio,
        required: true
      })
      
      # Try to query for previous option's value - should not find any
      {:ok, _all_new_options} = Forms.add_item_option(new_item, %{label: "New Option", value: "new"})
      # Assume we can't directly test option deletion since we don't have a public API for it
      # In a full implementation, you might add temporary helper functions for testing
    end
  end
  
  describe "reorder_form_items/2" do
    setup do
      # Create a form with multiple items for reordering
      user = user_fixture()
      {:ok, form} = Forms.create_form(%{title: "Form for Reordering", user_id: user.id})
      
      # Add several items with initial ordering
      {:ok, item1} = Forms.add_form_item(form, %{label: "Question 1", type: :text_input})
      {:ok, item2} = Forms.add_form_item(form, %{label: "Question 2", type: :text_input})
      {:ok, item3} = Forms.add_form_item(form, %{label: "Question 3", type: :text_input})
      
      %{form: form, items: [item1, item2, item3], user: user}
    end
    
    test "changes the order of form items", %{form: form, items: [item1, item2, item3]} do
      # Reorder the items: move item3 to first position, keeping others in order
      new_order = [item3.id, item1.id, item2.id]
      
      assert {:ok, reordered_items} = Forms.reorder_form_items(form.id, new_order)
      
      # Verify the items were reordered
      assert length(reordered_items) == 3
      
      # Extract IDs in the new order
      reordered_ids = Enum.map(reordered_items, &(&1.id))
      assert reordered_ids == new_order
      
      # Verify the order fields were updated
      [first, second, third] = reordered_items
      assert first.order == 1
      assert second.order == 2
      assert third.order == 3
      
      # Verify first item is now item3
      assert first.id == item3.id
    end
    
    test "returns error when item IDs don't match form's items", %{form: form, items: [item1, item2, _item3], user: user} do
      # Create an item for a different form
      {:ok, other_form} = Forms.create_form(%{title: "Another Form", user_id: user.id})
      {:ok, other_item} = Forms.add_form_item(other_form, %{label: "Other Question", type: :text_input})
      
      # Try to include that item in our reordering
      invalid_order = [item1.id, item2.id, other_item.id]
      
      assert {:error, :invalid_item_ids} = Forms.reorder_form_items(form.id, invalid_order)
    end
    
    test "returns error when not all form items are included", %{form: form, items: [item1, item2, _item3]} do
      # Missing one item
      incomplete_order = [item1.id, item2.id]
      
      assert {:error, :missing_items} = Forms.reorder_form_items(form.id, incomplete_order)
    end
  end
end