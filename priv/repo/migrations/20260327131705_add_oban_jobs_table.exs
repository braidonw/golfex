defmodule Golfex.Repo.Migrations.AddObanJobsTable do
  use Ecto.Migration

  def up, do: Oban.Migration.up(engine: Oban.Engines.Lite)
  def down, do: Oban.Migration.down(engine: Oban.Engines.Lite, version: 1)
end
