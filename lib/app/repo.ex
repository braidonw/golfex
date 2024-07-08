defmodule App.Repo do
  use Ecto.Repo,
    otp_app: :app,
    adapter: Ecto.Adapters.SQLite3

  def fetch(query, id) do
    case Repo.get(query, id) do
      nil -> {:error, :not_found}
      result -> {:ok, result}
    end
  end
end
