defmodule ThesisPhoenixLiveviewWeb.UploadControllerTest do
  use ThesisPhoenixLiveviewWeb.ConnCase, async: false

  alias ThesisPhoenixLiveview.Repo
  alias ThesisPhoenixLiveview.Uploads
  alias ThesisPhoenixLiveview.Uploads.Upload

  setup do
    clean_uploads_dir()
    clean_source_uploads_dir()

    on_exit(fn ->
      clean_uploads_dir()
      clean_source_uploads_dir()
    end)

    :ok
  end

  describe "POST /api/uploads" do
    test "stores a valid png file on disk and in the database", %{conn: conn} do
      conn = post_upload(conn, "pixel.png", "image/png", png_bytes())
      body = json_response(conn, 201)

      assert body["message"] == "Upload successful"
      assert body["file"]["originalName"] == "pixel.png"
      assert body["file"]["mimeType"] == "image/png"
      assert body["file"]["size"] == byte_size(png_bytes())
      assert is_binary(body["file"]["createdAt"])
      assert String.ends_with?(body["file"]["fileName"], ".png")
      assert body["file"]["url"] == "/uploads/#{body["file"]["fileName"]}"

      [uploaded_file] = Repo.all(Upload)
      assert uploaded_file.original_name == "pixel.png"
      assert uploaded_file.file_name == body["file"]["fileName"]

      assert uploaded_file_names() == [body["file"]["fileName"]]
    end

    test "rejects requests without a file", %{conn: conn} do
      conn = post(conn, ~p"/api/uploads", %{})
      body = json_response(conn, 400)

      assert body["message"] == "No file was uploaded"
      assert Repo.aggregate(Upload, :count) == 0
      assert uploaded_file_names() == []
    end

    test "rejects files whose content is not png", %{conn: conn} do
      conn = post_upload(conn, "notes.txt", "text/plain", "hello")
      body = json_response(conn, 415)

      assert body["message"] == "Only png files allowed"
      assert Repo.aggregate(Upload, :count) == 0
      assert uploaded_file_names() == []
    end

    test "rejects files larger than 20MB", %{conn: conn} do
      conn = post_upload(conn, "large.png", "image/png", oversized_png_bytes())
      body = json_response(conn, 413)

      assert body["message"] == "File is too large"
      assert Repo.aggregate(Upload, :count) == 0
      assert uploaded_file_names() == []
    end
  end

  defp post_upload(conn, file_name, content_type, contents) do
    path = write_source_upload(contents)
    upload = %Plug.Upload{path: path, filename: file_name, content_type: content_type}

    post(conn, ~p"/api/uploads", %{"file" => upload})
  end

  defp write_source_upload(contents) do
    path = Path.join(source_uploads_dir(), "#{System.unique_integer([:positive])}.upload")
    File.write!(path, contents)
    path
  end

  defp clean_uploads_dir do
    dir = uploads_dir()

    unless String.ends_with?(Path.basename(dir), "test-uploads") do
      raise "Refusing to clean non-test uploads dir: #{dir}"
    end

    File.rm_rf!(dir)
    File.mkdir_p!(dir)
  end

  defp clean_source_uploads_dir do
    File.rm_rf!(source_uploads_dir())
    File.mkdir_p!(source_uploads_dir())
  end

  defp uploaded_file_names do
    uploads_dir()
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".png"))
  end

  defp source_uploads_dir do
    Path.join(System.tmp_dir!(), "thesis_phoenix_liveview_upload_controller_test")
  end

  defp uploads_dir do
    Application.fetch_env!(:thesis_phoenix_liveview, :uploads_dir)
  end

  defp png_bytes do
    Base.decode64!(
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII="
    )
  end

  defp oversized_png_bytes do
    png_bytes = png_bytes()
    padding_size = Uploads.max_file_size() + 1 - byte_size(png_bytes)

    IO.iodata_to_binary([png_bytes, :binary.copy(<<1>>, padding_size)])
  end
end
