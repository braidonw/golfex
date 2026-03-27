defmodule Golfex.Repo.Migrations.CreateClubs do
  use Ecto.Migration

  def change do
    create table(:clubs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :base_url, :string, null: false

      timestamps(type: :utc_datetime)
    end
  end
end
