defmodule GolfexWeb.ClubLive.Index do
  use GolfexWeb, :live_view

  alias Golfex.Clubs

  @impl true
  def mount(_params, _session, socket) do
    user_clubs = Clubs.list_clubs_for_user(socket.assigns.current_scope)

    {:ok,
     socket
     |> assign(:page_title, "Clubs")
     |> assign(:user_clubs, user_clubs)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action)}
  end

  defp apply_action(socket, :new) do
    assign(socket, :page_title, "Add Club")
  end

  defp apply_action(socket, :index) do
    assign(socket, :page_title, "Clubs")
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    {:ok, _} = Clubs.remove_club_for_user(socket.assigns.current_scope, id)
    user_clubs = Clubs.list_clubs_for_user(socket.assigns.current_scope)

    {:noreply, assign(socket, :user_clubs, user_clubs)}
  end

  @impl true
  def handle_info({:club_added, _club}, socket) do
    user_clubs = Clubs.list_clubs_for_user(socket.assigns.current_scope)

    {:noreply, assign(socket, :user_clubs, user_clubs)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flow">
      <.header>
        Clubs
        <:actions>
          <.link navigate={~p"/clubs/new"}>
            <.button>Add Club</.button>
          </.link>
        </:actions>
      </.header>

      <%= if @live_action == :new do %>
        <.live_component
          module={GolfexWeb.ClubLive.FormComponent}
          id="new-club"
          current_scope={@current_scope}
        />
      <% end %>

      <.table id="clubs" rows={@user_clubs} row_id={fn uc -> "club-#{uc.id}" end}>
        <:col :let={uc} label="Name">{uc.club.name}</:col>
        <:col :let={uc} label="URL">{uc.club.base_url}</:col>
        <:action :let={uc}>
          <.link navigate={~p"/clubs/#{uc.club_id}/events"}>Events</.link>
        </:action>
        <:action :let={uc}>
          <.link phx-click="delete" phx-value-id={uc.id} data-confirm="Are you sure?">
            Remove
          </.link>
        </:action>
      </.table>
    </div>
    """
  end
end
