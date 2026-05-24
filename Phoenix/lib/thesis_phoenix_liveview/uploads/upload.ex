defmodule ThesisPhoenixLiveview.Uploads.Upload do
  use Ecto.Schema
  import Ecto.Changeset

  schema "phoenix" do
    field :original_name, :string
    field :file_name, :string
    field :mime_type, :string
    field :size, :integer
    field :created_at, :utc_datetime
  end

  def changeset(upload, attrs) do
    upload
    |> cast(attrs, [:original_name, :file_name, :mime_type, :size])
    |> validate_required([:original_name, :file_name, :mime_type, :size])
    |> validate_inclusion(:mime_type, ["image/jpeg", "image/png"])
    |> validate_number(:size, greater_than: 0, less_than_or_equal_to: 20 * 1024 * 1024)
  end
end
