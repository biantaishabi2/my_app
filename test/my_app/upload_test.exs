defmodule MyApp.UploadTest do
  use MyApp.DataCase, async: true
  
  alias MyApp.Upload
  alias MyApp.Upload.UploadedFile
  import MyApp.AccountsFixtures
  import MyApp.FormsFixtures
  
  describe "uploaded_files" do
    @valid_attrs %{
      original_filename: "test.jpg",
      filename: "abc123.jpg",
      path: "/uploads/form_id/field_id/abc123.jpg",
      size: 1024,
      content_type: "image/jpeg"
    }
    @invalid_attrs %{original_filename: nil, filename: nil, path: nil, size: nil, content_type: nil}
    
    setup do
      user = user_fixture()
      form = form_fixture(%{user_id: user.id})
      form_item = form_item_fixture(form, %{type: :file_upload})
      
      %{
        user: user,
        form: form,
        form_item: form_item
      }
    end
    
    test "save_uploaded_file/4 with valid data creates a file record", %{form: form, form_item: form_item} do
      assert {:ok, %UploadedFile{} = file} = Upload.save_uploaded_file(
        form.id,
        form_item.id,
        @valid_attrs
      )
      
      assert file.original_filename == @valid_attrs.original_filename
      assert file.filename == @valid_attrs.filename
      assert file.path == @valid_attrs.path
      assert file.size == @valid_attrs.size
      assert file.content_type == @valid_attrs.content_type
      assert file.form_id == form.id
      assert file.form_item_id == form_item.id
      assert is_nil(file.response_id)
    end
    
    test "save_uploaded_file/4 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Upload.save_uploaded_file("form_id", "item_id", @invalid_attrs)
    end
    
    test "get_files_for_form_item/2 returns files for a form item", %{form: form, form_item: form_item} do
      # Create a file for our form item
      {:ok, file1} = Upload.save_uploaded_file(form.id, form_item.id, @valid_attrs)
      
      # Also create a file for a different form item
      other_form_item = form_item_fixture(form, %{type: :file_upload})
      {:ok, _file2} = Upload.save_uploaded_file(form.id, other_form_item.id, %{@valid_attrs | filename: "xyz789.jpg"})
      
      # Check that we only get the file for our form item
      files = Upload.get_files_for_form_item(form.id, form_item.id)
      assert length(files) == 1
      assert hd(files).id == file1.id
    end
    
    test "get_files_for_form/1 returns files grouped by form item", %{form: form, form_item: form_item} do
      # Create two files for one form item
      {:ok, file1} = Upload.save_uploaded_file(form.id, form_item.id, @valid_attrs)
      {:ok, file2} = Upload.save_uploaded_file(form.id, form_item.id, %{@valid_attrs | filename: "def456.jpg"})
      
      # Create one file for another form item
      other_form_item = form_item_fixture(form, %{type: :file_upload})
      {:ok, file3} = Upload.save_uploaded_file(form.id, other_form_item.id, %{@valid_attrs | filename: "xyz789.jpg"})
      
      # Check that they're properly grouped
      files_by_item = Upload.get_files_for_form(form.id)
      
      # We should have two form items with files
      assert map_size(files_by_item) == 2
      
      # The first form item should have two files
      assert length(files_by_item[form_item.id]) == 2
      file_ids = Enum.map(files_by_item[form_item.id], & &1.id) |> Enum.sort()
      expected_ids = [file1.id, file2.id] |> Enum.sort()
      assert file_ids == expected_ids
      
      # The second form item should have one file
      assert length(files_by_item[other_form_item.id]) == 1
      assert hd(files_by_item[other_form_item.id]).id == file3.id
    end
    
    test "associate_files_with_response/3 associates files with a response", %{form: form, form_item: form_item} do
      # Create two files
      {:ok, _file1} = Upload.save_uploaded_file(form.id, form_item.id, @valid_attrs)
      {:ok, _file2} = Upload.save_uploaded_file(form.id, form_item.id, %{@valid_attrs | filename: "def456.jpg"})
      
      # Create a mock response and get its ID
      now = DateTime.utc_now()
      {:ok, response} = MyApp.Repo.insert(%MyApp.Responses.Response{
        form_id: form.id,
        submitted_at: now,
        respondent_info: %{},
        inserted_at: now,
        updated_at: now
      })
      response_id = response.id
      
      # Associate the files with the response
      {count, nil} = Upload.associate_files_with_response(form.id, form_item.id, response_id)
      assert count == 2
      
      # Verify the association
      files = Upload.get_files_for_response(response_id)
      assert map_size(files) == 1  # one form item
      assert length(files[form_item.id]) == 2  # two files for that item
      
      # Verify all files have the response ID
      for file <- files[form_item.id] do
        assert file.response_id == response_id
      end
    end
    
    test "delete_file/1 removes a file", %{form: form, form_item: form_item} do
      # Create a test file in a temporary location
      temp_dir = Path.join([:code.priv_dir(:my_app), "static", "temp"])
      File.mkdir_p!(temp_dir)
      temp_file = Path.join(temp_dir, "test_delete.txt")
      File.write!(temp_file, "test content")
      
      # Create a file record pointing to the test file
      attrs = %{@valid_attrs | path: "/temp/test_delete.txt"}
      {:ok, file} = Upload.save_uploaded_file(form.id, form_item.id, attrs)
      
      # Delete the file
      assert {:ok, %UploadedFile{}} = Upload.delete_file(file.id)
      
      # Verify the file is gone from the database
      assert Repo.get(UploadedFile, file.id) == nil
      
      # Verify the physical file is gone (this might fail if the implementation doesn't delete the file)
      refute File.exists?(temp_file)
    end
  end
end