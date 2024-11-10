defmodule App.MiClub.Auth do
  @moduledoc false
  alias __MODULE__.Query
  alias App.MiClub
  alias App.MiClub.Api
  alias App.MiClub.AuthCookie
  alias App.Repo

  @spec get_or_fetch_cookie(club_id :: integer) :: {:ok, String.t()} | {:error, atom}
  def get_or_fetch_cookie(club_id) do
    case get_active_cookie(club_id) do
      {:ok, cookie} ->
        {:ok, cookie.cookie}

      {:error, :not_found} ->
        with {:ok, club} <- MiClub.fetch_club_by_id(club_id), {:ok, token} <- Api.login(club.slug) do
          expires_at = DateTime.add(DateTime.utc_now(), 10, :minute)
          params = %{cookie: token, expires_at: expires_at, club_id: club_id}

          case set_cookie(params) do
            {:ok, cookie} -> {:ok, cookie.cookie}
            {:error, changeset} -> raise "Failed to set cookie: #{inspect(changeset)}"
          end
        end
    end
  end

  def set_cookie(params) do
    %AuthCookie{}
    |> AuthCookie.changeset(params)
    |> Repo.insert()
  end

  def get_cookie(id) do
    Repo.fetch(AuthCookie, id)
  end

  def get_cookie_by_token(token) do
    Query.cookie_base() |> Query.by_token(token) |> Repo.fetch_one()
  end

  def invalidate_cookie(cookie) do
    params = %{expires_at: DateTime.utc_now()}
    cookie |> AuthCookie.changeset(params) |> Repo.update()
  end

  def get_active_cookie(club_id) do
    Query.cookie_base()
    |> Query.for_club(club_id)
    |> Query.valid_only()
    |> Query.most_recent()
    |> Repo.fetch_one()
  end

  defmodule Query do
    @moduledoc false
    import Ecto.Query

    alias App.MiClub.AuthCookie

    def cookie_base do
      from c in AuthCookie, as: :cookie, order_by: [desc: c.inserted_at]
    end

    def valid_only(query) do
      where(query, [cookie: c], fragment("datetime('?') > datetime('now')", c.expires_at))
    end

    def for_club(query, club_id) do
      where(query, [cookie: cookie], cookie.club_id == ^club_id)
    end

    def by_token(query, cookie) do
      where(query, [cookie: cookie], cookie.cookie == ^cookie)
    end

    def most_recent(query) do
      limit(query, 1)
    end
  end
end
