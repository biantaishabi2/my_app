# test/my_app/forms_test.exs
defmodule MyApp.FormsTest do
  use MyApp.DataCase, async: true

  alias MyApp.Forms
  alias MyApp.Forms.Form # Assuming Form schema will be inside Forms context

  @moduletag :capture_log

  describe "forms" do
    @valid_attrs %{title: "User Satisfaction Survey"}
    @invalid_attrs %{description: "Missing title"}

    test "create_form/1 with valid data creates a form" do
      assert {:ok, %Form{} = form} = Forms.create_form(@valid_attrs)
      assert form.title == "User Satisfaction Survey"
      assert form.status == :draft # Default status should be draft
      assert form.description == nil # Fields not provided should be nil or default
    end

    test "create_form/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{} = changeset} = Forms.create_form(@invalid_attrs)
      # Verify that the changeset indicates title is required
      # The exact way to check might depend on your DataCase setup
      # This is a common way using Ecto.Changeset.traverse_errors
      assert Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end) |> Map.has_key?(:title)
    end

    test "get_form/1 returns the form with given id" do
      # We need a way to insert a form first for this test to be independent,
      # or rely on create_form working. Let's assume we insert directly for now.
      # This might require a helper function in your DataCase or test setup.
      # Placeholder: Replace with actual fixture insertion if needed.
      {:ok, form} = Forms.create_form(@valid_attrs)

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
      {:ok, form} = Forms.create_form(%{title: "Test Form for Items"})
      %{form: form}
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
      # This requires get_form to preload items, which might be a later step
      # For now, we trust the returned item's state.
      # fetched_form = Forms.get_form(form.id) |> Repo.preload(:items)
      # assert length(fetched_form.items) == 1
      # assert hd(fetched_form.items).label == "Your Name"
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
      {:ok, form} = Forms.create_form(%{title: "Form with Radio"})
      radio_item_attrs = %{label: "Choose One", type: :radio, required: true}
      {:ok, radio_item} = Forms.add_form_item(form, radio_item_attrs)
      %{form: form, radio_item: radio_item}
    end

    setup [:create_form_with_radio_item]

    test "with valid data adds an option to a radio item", %{radio_item: radio_item} do
      option_attrs = %{label: "Option A", value: "a"}

      assert {:ok, option} = Forms.add_item_option(radio_item, option_attrs)
      assert option.label == "Option A"
      assert option.value == "a"
      assert option.form_item_id == radio_item.id
      assert option.order == 1 # First option

      # Verify association (assuming ItemOption schema exists)
      # loaded_item = Repo.preload(radio_item, :options)
      # assert length(loaded_item.options) == 1
      # assert hd(loaded_item.options).value == "a"
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
      {:ok, form} = Forms.create_form(%{title: "Draft Form to Publish"})
      %{form: form}
    end

    setup [:create_draft_form]

    test "changes the form status from :draft to :published", %{form: form} do
      assert form.status == :draft
      assert {:ok, updated_form} = Forms.publish_form(form)
      assert updated_form.status == :published
      assert updated_form.id == form.id

      # Verify the change is persisted
      # fetched_form = Forms.get_form(form.id)
      # assert fetched_form.status == :published
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
end 