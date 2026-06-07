defmodule ThesisPhoenixLiveviewWeb.UploadLive do
  use ThesisPhoenixLiveviewWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <main class="page">
      <form
        id="upload-form"
        class="upload-form"
        action={~p"/api/uploads"}
        method="post"
        enctype="multipart/form-data"
        phx-hook="UploadForm"
        phx-update="ignore"
      >
        <label id="file-button" class="file-button" for="file-input">
          Choose file
        </label>

        <input
          id="file-input"
          class="file-input"
          type="file"
          name="file"
          accept=".png,image/png"
          data-upload-input
        />

        <p id="file-name" class="file-name" data-file-name>no file chosen</p>

        <button id="upload-button" class="upload-button" type="submit" data-upload-submit>
          Upload file
        </button>

        <p id="upload-message" class="message hidden" data-upload-message></p>
      </form>
    </main>
    """
  end
end
