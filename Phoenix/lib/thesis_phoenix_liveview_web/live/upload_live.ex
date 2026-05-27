defmodule ThesisPhoenixLiveviewWeb.UploadLive do
  use ThesisPhoenixLiveviewWeb, :live_view

  alias ThesisPhoenixLiveview.Uploads

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:message, nil)
      |> assign(:message_status, nil)
      |> allow_upload(:file,
        accept: :any,
        max_entries: 1,
        max_file_size: Uploads.max_file_size()
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("upload", _params, socket) do
    case upload_error_message(socket) do
      nil -> consume_file(socket)
      message -> {:noreply, assign_message(socket, message, :error)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="page">
      <form id="upload-form" class="upload-form" phx-change="validate" phx-submit="upload">
        <label id="file-button" class="file-button" for={@uploads.file.ref}>
          Choose file
        </label>

        <.live_file_input upload={@uploads.file} class="file-input" />

        <p id="file-name" class="file-name">{selected_file_name(@uploads.file)}</p>

        <button id="upload-button" class="upload-button" type="submit">
          Upload file
        </button>

        <p :if={@message} id="upload-message" class={["message", @message_status]}>
          {@message}
        </p>
      </form>
    </main>
    """
  end

  defp consume_file(socket) do
    results =
      consume_uploaded_entries(socket, :file, fn %{path: path}, entry ->
        result =
          Uploads.create_uploaded_file(%{
            path: path,
            original_name: entry.client_name,
            size: entry.client_size
          })

        {:ok, result}
      end)

    case results do
      [{:ok, _upload, message}] -> {:noreply, assign_message(socket, message, :success)}
      [{:error, message}] -> {:noreply, assign_message(socket, message, :error)}
      [] -> {:noreply, assign_message(socket, Uploads.no_file_message(), :error)}
    end
  end

  defp upload_error_message(socket) do
    upload = socket.assigns.uploads.file
    entry_errors = Enum.flat_map(upload.entries, &upload_errors(upload, &1))

    (upload_errors(upload) ++ entry_errors)
    |> List.first()
    |> case do
      nil -> nil
      error -> Uploads.upload_error_message(error)
    end
  end

  defp selected_file_name(upload) do
    case upload.entries do
      [entry | _entries] -> entry.client_name
      [] -> "no file chosen"
    end
  end

  defp assign_message(socket, message, status) do
    assign(socket, message: message, message_status: to_string(status))
  end
end
