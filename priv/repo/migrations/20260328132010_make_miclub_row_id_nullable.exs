defmodule Golfex.Repo.Migrations.MakeMiclubRowIdNullable do
  use Ecto.Migration

  # miclub_row_id is already nullable in the original migration,
  # so this is a no-op for fresh databases. Kept for migration history.
  def change do
  end
end
