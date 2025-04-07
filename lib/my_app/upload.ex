defmodule MyApp.Upload do
  @moduledoc """
  The Upload context handles file uploads and their association with forms and responses.
  """

  import Ecto.Query, warn: false
  alias MyApp.Repo
  alias MyApp.Upload.UploadedFile

  @doc """
  Saves uploaded file information and creates a record in the database.

  ## Parameters
    - form_id: The ID of the form the file is associated with
    - form_item_id: The ID of the form item (field) the file is associated with
    - file_info: Map containing file metadata (filename, path, size, etc.)
    - response_id: (Optional) The ID of the response this file is associated with

  ## Examples
      iex> save_uploaded_file(form_id, form_item_id, file_info)
      {:ok, %UploadedFile{}}

      iex> save_uploaded_file(form_id, form_item_id, invalid_data)
      {:error, %Ecto.Changeset{}}
  """
  def save_uploaded_file(form_id, form_item_id, file_info, response_id \\ nil) do
    attrs = %{
      form_id: form_id,
      form_item_id: form_item_id,
      response_id: response_id,
      original_filename: file_info.original_filename,
      filename: file_info.filename,
      path: file_info.path,
      size: file_info.size,
      content_type: file_info.content_type
    }

    %UploadedFile{}
    |> UploadedFile.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Get all uploaded files for a specific form item.

  ## Parameters
    - form_id: The ID of the form
    - form_item_id: The ID of the form item (field)

  ## Examples
      iex> get_files_for_form_item(form_id, form_item_id)
      [%UploadedFile{}, ...]
  """
  def get_files_for_form_item(form_id, form_item_id) do
    Repo.all(
      from f in UploadedFile,
      where: f.form_id == ^form_id and f.form_item_id == ^form_item_id and is_nil(f.response_id),
      order_by: [desc: f.inserted_at]
    )
  end

  @doc """
  Get all uploaded files for a specific form.

  ## Parameters
    - form_id: The ID of the form

  ## Examples
      iex> get_files_for_form(form_id)
      %{form_item_id => [%UploadedFile{}, ...], ...}
  """
  def get_files_for_form(form_id) do
    Repo.all(
      from f in UploadedFile,
      where: f.form_id == ^form_id and is_nil(f.response_id),
      order_by: [desc: f.inserted_at]
    )
    |> Enum.group_by(& &1.form_item_id)
  end

  @doc """
  Associate uploaded files with a response.

  ## Parameters
    - form_id: The ID of the form
    - form_item_id: The ID of the form item
    - response_id: The ID of the response

  ## Examples
      iex> associate_files_with_response(form_id, form_item_id, response_id)
      {n, nil}
  """
  def associate_files_with_response(form_id, form_item_id, response_id) do
    Repo.update_all(
      from(f in UploadedFile,
        where: f.form_id == ^form_id and
               f.form_item_id == ^form_item_id and
               is_nil(f.response_id)
      ),
      set: [response_id: response_id, updated_at: DateTime.utc_now()]
    )
  end

  @doc """
  Delete an uploaded file by ID.

  ## Parameters
    - id: The ID of the file to delete

  ## Examples
      iex> delete_file(id)
      {:ok, %UploadedFile{}}

      iex> delete_file(bad_id)
      {:error, :not_found}
  """
  def delete_file(id) do
    case Repo.get(UploadedFile, id) do
      nil ->
        {:error, :not_found}

      file ->
        # Delete the physical file
        file_path = Path.join([:code.priv_dir(:my_app), "static", file.path])
        File.rm(file_path)

        # Delete the database record
        Repo.delete(file)
    end
  end

  @doc """
  Get all uploaded files associated with a response.

  ## Parameters
    - response_id: The ID of the response

  ## Examples
      iex> get_files_for_response(response_id)
      %{form_item_id => [%UploadedFile{}, ...], ...}
  """
  def get_files_for_response(response_id) do
    Repo.all(
      from f in UploadedFile,
      where: f.response_id == ^response_id,
      order_by: [desc: f.inserted_at]
    )
    |> Enum.group_by(& &1.form_item_id)
  end
end