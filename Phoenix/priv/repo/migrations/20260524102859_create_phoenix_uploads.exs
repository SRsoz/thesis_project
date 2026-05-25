defmodule ThesisPhoenixLiveview.Repo.Migrations.CreatePhoenixUploads do
  use Ecto.Migration

  def change do
    create table(:phoenix) do
      add :original_name, :string, null: false
      add :file_name, :string, null: false
      add :mime_type, :string, null: false
      add :size, :integer, null: false
      add :created_at, :utc_datetime, null: false, default: fragment("CURRENT_TIMESTAMP")
    end

    create unique_index(:phoenix, [:file_name])
  end
end
