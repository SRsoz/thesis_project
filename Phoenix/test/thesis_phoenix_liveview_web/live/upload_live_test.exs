defmodule ThesisPhoenixLiveviewWeb.UploadLiveTest do
  use ThesisPhoenixLiveviewWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias ThesisPhoenixLiveview.Repo
  alias ThesisPhoenixLiveview.Uploads.Upload

  setup do
    clean_uploads_dir()

    on_exit(fn ->
      clean_uploads_dir()
    end)

    :ok
  end

  test "uploads a valid png file through LiveView", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    upload =
      file_input(view, "#upload-form", :file, [
        %{name: "pixel.png", content: png_bytes(), type: "image/png"}
      ])

    render_upload(upload, "pixel.png")
    view |> form("#upload-form", %{}) |> render_submit()

    assert has_element?(view, "#upload-message.success", "Upload successful")

    [uploaded_file] = Repo.all(Upload)
    assert uploaded_file.original_name == "pixel.png"
    assert uploaded_file.mime_type == "image/png"
    assert uploaded_file.size == byte_size(png_bytes())
    assert String.ends_with?(uploaded_file.file_name, ".png")
    assert File.exists?(Path.join(uploads_dir(), uploaded_file.file_name))
  end

  test "rejects invalid file contents through LiveView", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    upload =
      file_input(view, "#upload-form", :file, [
        %{name: "fake.png", content: "hello", type: "image/png"}
      ])

    render_upload(upload, "fake.png")
    view |> form("#upload-form", %{}) |> render_submit()

    assert has_element?(view, "#upload-message.error", "Only png files allowed")
    assert Repo.aggregate(Upload, :count) == 0
    assert uploaded_file_names() == []
  end

  test "rejects submit without a file", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view |> form("#upload-form", %{}) |> render_submit()

    assert has_element?(view, "#upload-message.error", "No file was uploaded")
    assert Repo.aggregate(Upload, :count) == 0
    assert uploaded_file_names() == []
  end

  defp clean_uploads_dir do
    dir = uploads_dir()

    unless String.ends_with?(Path.basename(dir), "test-uploads") do
      raise "Refusing to clean non-test uploads dir: #{dir}"
    end

    File.rm_rf!(dir)
    File.mkdir_p!(dir)
  end

  defp uploaded_file_names do
    uploads_dir()
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".png"))
  end

  defp uploads_dir do
    Application.fetch_env!(:thesis_phoenix_liveview, :uploads_dir)
  end

  defp png_bytes do
    Base.decode64!(
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII="
    )
  end
end
