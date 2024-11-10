defmodule App.Repo.Migrations.MiclubCookies do
  use Ecto.Migration

  def change do
    create table(:mi_club_cookies) do
      add :cookie, :string, null: false
      add :expires_at, :utc_datetime, null: false
      add :club_id, references(:miclub_clubs), null: false

      timestamps()
    end
  end
end
