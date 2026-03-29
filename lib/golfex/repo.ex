defmodule Golfex.Repo do
  use Ecto.Repo,
    otp_app: :golfex,
    adapter: Ecto.Adapters.SQLite3
end
