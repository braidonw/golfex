defmodule Golfex.Repo.Migrations.CreateUserClubs do
  use Ecto.Migration

  def change do
    create table(:user_clubs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :club_id, references(:clubs, type: :binary_id, on_delete: :delete_all), null: false
      add :member_id, :binary, null: false
      add :username, :binary, null: false
      add :password, :binary, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_clubs, [:user_id, :club_id])
    create index(:user_clubs, [:user_id])
    create index(:user_clubs, [:club_id])
  end
end
