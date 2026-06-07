defmodule ThesisPhoenixLiveviewWeb.UploadController do
  use ThesisPhoenixLiveviewWeb, :controller

  alias ThesisPhoenixLiveview.Uploads

  def create(conn, %{"file" => %Plug.Upload{} = upload}) do
    case File.stat(upload.path) do
      {:ok, %{size: size}} ->
        create_uploaded_file(conn, upload, size)

      {:error, _reason} ->
        upload_failed(conn)
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{message: Uploads.no_file_message()})
  end

  defp create_uploaded_file(conn, upload, size) do
    attrs = %{
      path: upload.path,
      original_name: upload.filename,
      size: size
    }

    case Uploads.create_uploaded_file(attrs) do
      {:ok, uploaded_file, message} ->
        conn
        |> put_status(:created)
        |> json(%{message: message, file: uploaded_file_json(uploaded_file)})

      {:error, message} ->
        upload_error(conn, message)
    end
  end

  defp uploaded_file_json(uploaded_file) do
    %{
      id: uploaded_file.id,
      originalName: uploaded_file.original_name,
      fileName: uploaded_file.file_name,
      mimeType: uploaded_file.mime_type,
      size: uploaded_file.size,
      createdAt: uploaded_file.created_at,
      url: ~p"/uploads/#{uploaded_file.file_name}"
    }
  end

  defp upload_error(conn, message) do
    cond do
      message == Uploads.invalid_type_message() ->
        conn
        |> put_status(:unsupported_media_type)
        |> json(%{message: message})

      message == Uploads.too_large_message() ->
        conn
        |> put_status(413)
        |> json(%{message: "File is too large"})

      true ->
        upload_failed(conn)
    end
  end

  defp upload_failed(conn) do
    conn
    |> put_status(:internal_server_error)
    |> json(%{message: Uploads.failed_message()})
  end
end
