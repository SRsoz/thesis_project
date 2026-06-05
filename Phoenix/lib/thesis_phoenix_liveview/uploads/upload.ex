defmodule ThesisPhoenixLiveview.Uploads.Upload do
  use Ecto.Schema
  import Ecto.Changeset

  @max_file_size 20 * 1024 * 1024

  schema "phoenix" do
    field :original_name, :string
    field :file_name, :string
    field :mime_type, :string
    field :size, :integer
    field :created_at, :utc_datetime
  end

  def max_file_size, do: @max_file_size

  def changeset(upload, attrs) do
    upload
    |> cast(attrs, [:original_name, :file_name, :mime_type, :size])
    |> validate_required([:original_name, :file_name, :mime_type, :size])
    |> validate_inclusion(:mime_type, ["image/png"],
      message: "Only png files allowed"
    )
    |> validate_number(:size,
      greater_than: 0,
      less_than_or_equal_to: @max_file_size,
      message: "Only 20MB files allowed"
    )
  end
end
