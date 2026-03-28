defmodule Golfex.MiClub.SessionStore do
  use GenServer

  @table :miclub_sessions
  @ttl_ms :timer.minutes(30)

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Returns an authenticated `{req, jar}` for the given user_club, either from
  cache or by performing a fresh login.
  """
  def get_or_login(user_club) do
    key = {user_club.user_id, user_club.club_id}

    case lookup(key) do
      {:ok, req, jar} ->
        {:ok, req, jar}

      :miss ->
        with {:ok, req, jar} <- do_login(user_club) do
          insert(key, req, jar)
          {:ok, req, jar}
        end
    end
  end

  @doc """
  Invalidates the cached session for a user/club pair.
  """
  def invalidate(user_id, club_id) do
    :ets.delete(@table, {user_id, club_id})
    :ok
  end

  # Server callbacks

  @impl true
  def init(_) do
    table = :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
    {:ok, table}
  end

  # Private

  defp lookup(key) do
    case :ets.lookup(@table, key) do
      [{^key, req, jar, inserted_at}] ->
        if System.monotonic_time(:millisecond) - inserted_at < @ttl_ms do
          {:ok, req, jar}
        else
          :ets.delete(@table, key)
          :miss
        end

      [] ->
        :miss
    end
  end

  defp insert(key, req, jar) do
    :ets.insert(@table, {key, req, jar, System.monotonic_time(:millisecond)})
  end

  defp do_login(user_club) do
    Golfex.MiClub.Client.login(
      user_club.club.base_url,
      user_club.username,
      user_club.password
    )
  end
end
