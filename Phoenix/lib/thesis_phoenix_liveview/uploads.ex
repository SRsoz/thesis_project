defmodule ThesisPhoenixLiveview.Uploads do
  alias ThesisPhoenixLiveview.Repo
  alias ThesisPhoenixLiveview.Uploads.Upload

  @success_message "Upload successful"
  @failed_message "Upload failed"
  @no_file_message "No file was uploaded"
  @invalid_type_message "Only png and jpeg files allowed"
  @too_large_message "Only 20MB files allowed"
  @max_file_size Upload.max_file_size()

  def create_upload(attrs) do
    %Upload{}
    |> Upload.changeset(attrs)
    |> Repo.insert()
  end

  def max_file_size, do: Upload.max_file_size()

  def no_file_message, do: @no_file_message

  def upload_error_message(:too_large), do: @too_large_message
  def upload_error_message(:not_accepted), do: @invalid_type_message
  def upload_error_message(:too_many_files), do: @failed_message
  def upload_error_message(_error), do: @failed_message

  def create_uploaded_file(%{path: path, original_name: original_name, size: size}) do
    with :ok <- validate_file_size(size),
         {:ok, mime_type} <- detected_mime_type(path),
         {:ok, file_name, destination} <- copy_upload(path, mime_type),
         {:ok, upload} <-
           create_upload_record(
             %{
               original_name: original_name,
               file_name: file_name,
               mime_type: mime_type,
               size: size
             },
             destination
           ) do
      {:ok, upload, @success_message}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset_message(changeset)}

      {:error, %Ecto.Changeset{} = changeset, destination} ->
        cleanup_failed_upload(changeset, destination)

      {:error, message} when is_binary(message) ->
        {:error, message}

      _error ->
        {:error, @failed_message}
    end
  end

  defp validate_file_size(size) when is_integer(size) and size <= @max_file_size and size > 0 do
    :ok
  end

  defp validate_file_size(_size), do: {:error, @too_large_message}

  defp detected_mime_type(path) do
    case File.read(path) do
      {:ok, <<137, 80, 78, 71, 13, 10, 26, 10, _rest::binary>>} -> {:ok, "image/png"}
      {:ok, <<255, 216, 255, _rest::binary>>} -> {:ok, "image/jpeg"}
      {:ok, _contents} -> {:error, @invalid_type_message}
      {:error, _reason} -> {:error, @failed_message}
    end
  end

  defp copy_upload(path, mime_type) do
    uploads_dir = Path.expand("priv/static/uploads")
    File.mkdir_p!(uploads_dir)

    file_name = "#{Ecto.UUID.generate()}.#{extension_for(mime_type)}"
    destination = Path.join(uploads_dir, file_name)

    case File.cp(path, destination) do
      :ok -> {:ok, file_name, destination}
      {:error, _reason} -> {:error, @failed_message}
    end
  end

  defp create_upload_record(attrs, destination) do
    case create_upload(attrs) do
      {:ok, upload} -> {:ok, upload}
      {:error, %Ecto.Changeset{} = changeset} -> {:error, changeset, destination}
    end
  end

  defp cleanup_failed_upload(changeset, destination) do
    File.rm(destination)
    {:error, changeset_message(changeset)}
  end

  defp extension_for("image/jpeg"), do: "jpg"
  defp extension_for("image/png"), do: "png"

  defp changeset_message(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {message, _opts} -> message end)
    |> Map.values()
    |> List.flatten()
    |> List.first()
    |> case do
      nil -> @failed_message
      message -> message
    end
  end
end
