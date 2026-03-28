defmodule Golfex.Repo.Migrations.MakeMiclubRowIdNullable do
  use Ecto.Migration

  def change do
    alter table(:scheduled_bookings) do
      modify :miclub_row_id, :integer, null: true, from: {:integer, null: false}
    end
  end
end
