defmodule GolfexWeb.ClubLive.FormComponent do
  use GolfexWeb, :live_component

  alias Golfex.Clubs
  alias Golfex.Clubs.Club

  @impl true
  def mount(socket) do
    changeset = Club.changeset(%Club{}, %{})

    {:ok,
     socket
     |> assign(:form, to_form(changeset))
     |> assign(:member_id, "")
     |> assign(:username, "")
     |> assign(:password, "")}
  end

  @impl true
  def handle_event("validate", %{"club" => club_params}, socket) do
    changeset =
      %Club{}
      |> Club.changeset(club_params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:form, to_form(changeset))
     |> assign(:member_id, Map.get(club_params, "member_id", ""))
     |> assign(:username, Map.get(club_params, "username", ""))
     |> assign(:password, Map.get(club_params, "password", ""))}
  end

  @impl true
  def handle_event("save", %{"club" => club_params}, socket) do
    case Clubs.create_club(Map.take(club_params, ["name", "base_url"])) do
      {:ok, club} ->
        user_attrs = %{
          member_id: club_params["member_id"],
          username: club_params["username"],
          password: club_params["password"]
        }

        case Clubs.add_club_for_user(socket.assigns.current_scope, club, user_attrs) do
          {:ok, _user_club} ->
            send(self(), {:club_added, club})
            {:noreply, push_navigate(socket, to: ~p"/clubs")}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to associate club with your account.")}
        end

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form for={@form} id="club-form" phx-target={@myself} phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} type="text" label="Club Name" />
        <.input field={@form[:base_url]} type="text" label="Base URL" />
        <.input
          type="text"
          name="club[member_id]"
          id="club_member_id"
          value={@member_id}
          label="Member ID"
        />
        <.input
          type="text"
          name="club[username]"
          id="club_username"
          value={@username}
          label="Username"
        />
        <.input
          type="password"
          name="club[password]"
          id="club_password"
          value={@password}
          label="Password"
        />
        <.button type="submit" variant="accent">Save Club</.button>
      </.form>
    </div>
    """
  end
end
