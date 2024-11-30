defmodule App.MiClub.Booking do
  @moduledoc false
  alias __MODULE__.Params
  alias App.MiClub
  alias App.MiClub.Api

  # Params for booking an event
  defmodule Params do
    @moduledoc false
    defstruct [:row_id, :do_action, :member_id, :my_group, :find_alternative]

    defimpl Jason.Encoder, for: __MODULE__ do
      def encode(params, opts) do
        %{
          row_id: row_id,
          do_action: do_action,
          member_id: member_id,
          my_group: my_group,
          find_alternative: find_alternative
        } = params

        Jason.Encode.map(
          %{
            rowId: row_id,
            doAction: do_action,
            memberId: member_id,
            myGroup: my_group,
            findAlternative: find_alternative
          },
          opts
        )
      end
    end
  end

  @doc """
  Book an event

  The event_id is the booking group id

  ## Example
        iex> App.MiClub.Booking.book_event("club-slug", "event-id", "member-id")

  """
  def book_event(slug, booking_group_remote_id) do
    slug_atom = String.to_existing_atom(slug)
    config = Application.get_env(:app, :miclub)[slug_atom]
    member_id = config[:member_id] || raise "Member ID not found for club #{slug}"

    params = %Params{
      row_id: booking_group_remote_id,
      do_action: "makeBooking",
      member_id: member_id,
      my_group: false,
      find_alternative: false
    }

    params = params |> Jason.encode!() |> Jason.decode!()

    with {:ok, club} <- MiClub.fetch_club_by_slug(slug),
         {:ok, token} <- App.MiClub.Auth.get_or_fetch_cookie(club.id) do
      Api.make_booking(slug, token, params)
    end
  end
end
