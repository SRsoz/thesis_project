defmodule ThesisPhoenixLiveview.Uploads do
  import Ecto.Query, warn: false

  alias ThesisPhoenixLiveview.Repo
  alias ThesisPhoenixLiveview.Uploads.Upload

  def list_uploads do
    Repo.all(from upload in Upload, order_by: [desc: upload.created_at])
  end

  def create_upload(attrs) do
    %Upload{}
    |> Upload.changeset(attrs)
    |> Repo.insert()
  end
end
