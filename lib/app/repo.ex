defmodule App.Repo do
  use Ecto.Repo,
    otp_app: :app,
    adapter: Ecto.Adapters.SQLite3

  def fetch(query, id) do
    case __MODULE__.get(query, id) do
      nil -> {:error, :not_found}
      result -> {:ok, result}
    end
  end

  def fetch_by(query, clauses, opts \\ []) do
    case __MODULE__.get_by(query, clauses, opts) do
      nil -> {:error, :not_found}
      result -> {:ok, result}
    end
  end

  def fetch_one(query) do
    case __MODULE__.one(query) do
      nil -> {:error, :not_found}
      result -> {:ok, result}
    end
  end
end
