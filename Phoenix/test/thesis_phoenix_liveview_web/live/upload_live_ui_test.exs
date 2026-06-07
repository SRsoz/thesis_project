defmodule ThesisPhoenixLiveviewWeb.UploadLiveUiTest do
  use ThesisPhoenixLiveviewWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  test "renders a LiveView UI wired to the HTTP upload endpoint", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(
             view,
             "#upload-form[phx-hook='UploadForm'][action='/api/uploads'][method='post'][enctype='multipart/form-data']"
           )

    assert has_element?(
             view,
             "input#file-input.file-input[name='file'][type='file'][accept='.png,image/png'][data-upload-input]"
           )

    assert has_element?(view, "label#file-button[for='file-input']", "Choose file")
    assert has_element?(view, "#file-name[data-file-name]", "no file chosen")

    assert has_element?(
             view,
             "button#upload-button[type='submit'][data-upload-submit]",
             "Upload file"
           )

    assert has_element?(view, "#upload-message[data-upload-message]")
    refute has_element?(view, "input[data-phx-upload-ref]")
  end
end
