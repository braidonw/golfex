defmodule Golfex.BookingsTest do
  use Golfex.DataCase, async: true

  import Golfex.AccountsFixtures
  import Golfex.ClubsFixtures

  alias Golfex.Bookings
  alias Golfex.Bookings.ScheduledBooking

  defp create_booking_attrs(user, user_club) do
    %{
      user_id: user.id,
      user_club_id: user_club.id,
      miclub_event_id: 123,
      miclub_group_id: 456,
      miclub_row_id: 789,
      miclub_member_id: 12345,
      scheduled_for: DateTime.add(DateTime.utc_now(:second), 3600)
    }
  end

  defp setup_user_and_club(_context) do
    scope = user_scope_fixture()
    club = club_fixture()
    user_club = user_club_fixture(scope, club) |> Golfex.Repo.preload(:club)
    %{scope: scope, user: scope.user, club: club, user_club: user_club}
  end

  defp stub_miclub_success(_context) do
    Req.Test.stub(Golfex.MiClub.Client, fn conn ->
      case conn.request_path do
        "/security/login.msp" -> Req.Test.json(conn, %{})
        "/members/Ajax" -> Req.Test.text(conn, "<Success/>")
      end
    end)

    :ok
  end

  describe "schedule_booking/1" do
    setup [:setup_user_and_club, :stub_miclub_success]

    test "creates a booking and enqueues Oban job", %{user: user, user_club: user_club} do
      attrs = create_booking_attrs(user, user_club)
      assert {:ok, %ScheduledBooking{} = booking} = Bookings.schedule_booking(attrs)

      assert booking.user_id == user.id
      assert booking.user_club_id == user_club.id
      assert booking.miclub_group_id == 456
      assert booking.miclub_row_id == 789
      assert booking.miclub_member_id == 12345
      assert booking.id != nil
    end
  end

  describe "cancel_booking/1" do
    setup [:setup_user_and_club, :stub_miclub_success]

    test "cancels a pending booking", %{user: user, user_club: user_club} do
      attrs = create_booking_attrs(user, user_club)
      {:ok, booking} = Bookings.schedule_booking(attrs)

      # Reload to get fresh status (inline Oban may have already run it)
      booking = Bookings.get_scheduled_booking!(booking.id)

      # Force status back to pending for this test
      {:ok, booking} = Bookings.update_booking_status(booking, "pending")

      assert {:ok, cancelled} = Bookings.cancel_booking(booking)
      assert cancelled.status == "cancelled"
    end

    test "returns error for completed booking", %{user: user, user_club: user_club} do
      attrs = create_booking_attrs(user, user_club)
      {:ok, booking} = Bookings.schedule_booking(attrs)
      {:ok, booking} = Bookings.update_booking_status(booking, "completed")

      assert {:error, :not_cancellable} = Bookings.cancel_booking(booking)
    end
  end

  describe "list_bookings_for_user/1" do
    setup [:setup_user_and_club, :stub_miclub_success]

    test "returns bookings for the user", %{scope: scope, user: user, user_club: user_club} do
      attrs = create_booking_attrs(user, user_club)
      {:ok, _booking} = Bookings.schedule_booking(attrs)

      bookings = Bookings.list_bookings_for_user(scope)
      assert length(bookings) == 1
      assert hd(bookings).user_id == user.id
    end
  end

  describe "book_now/3" do
    setup [:setup_user_and_club]

    test "resolves first empty slot and books", %{user_club: user_club} do
      event_detail_xml = """
      <?xml version="1.0" encoding="utf-8"?>
      <BookingEvent id="42">
        <active>true</active>
        <id>42</id>
        <Date>2024-01-15T07:00:00</Date>
        <Name>Saturday Comp</Name>
        <lastModified>2024-01-10T12:00:00</lastModified>
        <BookingSections>
          <BookingSection id="1">
            <id>1</id>
            <active>true</active>
            <Name>Morning</Name>
            <BookingGroups>
              <BookingGroup id="456" size="4">
                <id>456</id>
                <Time>07:00</Time>
                <StatusCode>0</StatusCode>
                <active>true</active>
                <RequireHandicap>false</RequireHandicap>
                <RequireGolfLink>false</RequireGolfLink>
                <VisitorAccepted>false</VisitorAccepted>
                <MemberAccepted>true</MemberAccepted>
                <PublicMemberAccepted>false</PublicMemberAccepted>
                <NineHoles>false</NineHoles>
                <EighteenHoles>true</EighteenHoles>
                <BookingEntries>
                  <BookingEntry id="200" type="member" index="1">
                    <PersonName>John Smith</PersonName>
                  </BookingEntry>
                  <BookingEntry id="201" type="member" index="2">
                    <PersonName></PersonName>
                  </BookingEntry>
                </BookingEntries>
              </BookingGroup>
            </BookingGroups>
          </BookingSection>
        </BookingSections>
      </BookingEvent>
      """

      Req.Test.stub(Golfex.MiClub.Client, fn conn ->
        case {conn.method, conn.request_path} do
          {_, "/security/login.msp"} -> Req.Test.json(conn, %{})
          {"GET", "/spring/bookings/events/42"} -> Req.Test.text(conn, event_detail_xml)
          {"POST", "/members/Ajax"} -> Req.Test.text(conn, "<Success/>")
        end
      end)

      assert :ok = Bookings.book_now(user_club, 42, 456)
    end

    test "returns error when no empty slots", %{user_club: user_club} do
      event_detail_xml = """
      <?xml version="1.0" encoding="utf-8"?>
      <BookingEvent id="42">
        <active>true</active>
        <id>42</id>
        <Date>2024-01-15T07:00:00</Date>
        <Name>Saturday Comp</Name>
        <lastModified>2024-01-10T12:00:00</lastModified>
        <BookingSections>
          <BookingSection id="1">
            <id>1</id>
            <active>true</active>
            <Name>Morning</Name>
            <BookingGroups>
              <BookingGroup id="456" size="4">
                <id>456</id>
                <Time>07:00</Time>
                <StatusCode>0</StatusCode>
                <active>true</active>
                <RequireHandicap>false</RequireHandicap>
                <RequireGolfLink>false</RequireGolfLink>
                <VisitorAccepted>false</VisitorAccepted>
                <MemberAccepted>true</MemberAccepted>
                <PublicMemberAccepted>false</PublicMemberAccepted>
                <NineHoles>false</NineHoles>
                <EighteenHoles>true</EighteenHoles>
                <BookingEntries>
                  <BookingEntry id="200" type="member" index="1">
                    <PersonName>John Smith</PersonName>
                  </BookingEntry>
                  <BookingEntry id="201" type="member" index="2">
                    <PersonName>Jane Doe</PersonName>
                  </BookingEntry>
                </BookingEntries>
              </BookingGroup>
            </BookingGroups>
          </BookingSection>
        </BookingSections>
      </BookingEvent>
      """

      Req.Test.stub(Golfex.MiClub.Client, fn conn ->
        case {conn.method, conn.request_path} do
          {_, "/security/login.msp"} -> Req.Test.json(conn, %{})
          {"GET", "/spring/bookings/events/42"} -> Req.Test.text(conn, event_detail_xml)
        end
      end)

      assert {:error, :no_empty_slots} = Bookings.book_now(user_club, 42, 456)
    end
  end
end
