defmodule Golfex.Bookings.BookingWorkerTest do
  use Golfex.DataCase, async: true
  use Oban.Testing, repo: Golfex.Repo

  import Golfex.AccountsFixtures
  import Golfex.ClubsFixtures
  import Golfex.EventsFixtures

  alias Golfex.Bookings
  alias Golfex.Bookings.BookingWorker

  describe "perform/1" do
    test "executes booking and updates status to completed" do
      scope = user_scope_fixture()
      club = club_fixture()
      user_club = user_club_fixture(scope, club)

      Req.Test.stub(Golfex.MiClub.Client, fn conn ->
        case conn.request_path do
          "/security/login.msp" -> Req.Test.json(conn, %{})
          "/members/Ajax" -> Req.Test.text(conn, "<Success/>")
        end
      end)

      # Insert booking directly (bypass schedule_booking to avoid inline execution)
      {:ok, booking} =
        %Golfex.Bookings.ScheduledBooking{}
        |> Golfex.Bookings.ScheduledBooking.changeset(%{
          user_id: scope.user.id,
          user_club_id: user_club.id,
          miclub_group_id: 456,
          miclub_row_id: 789,
          miclub_member_id: 12345,
          scheduled_for: DateTime.utc_now(:second)
        })
        |> Repo.insert()

      assert :ok = perform_job(BookingWorker, %{booking_id: booking.id})

      updated = Bookings.get_scheduled_booking!(booking.id)
      assert updated.status == "completed"
    end

    test "resolves first empty slot at execution time when miclub_row_id is nil" do
      scope = user_scope_fixture()
      club = club_fixture()
      user_club = user_club_fixture(scope, club)
      event = event_fixture(club, %{miclub_event_id: 42})

      event_xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <BookingEvent>
        <id>42</id>
        <active>true</active>
        <Name>Test Event</Name>
        <Date>2026-04-01</Date>
        <lastModified>2026-03-29</lastModified>
        <BookingSections>
          <BookingSection>
            <id>1</id>
            <active>true</active>
            <Name>Morning</Name>
            <BookingGroups>
              <BookingGroup>
                <id>456</id>
                <Time>08:00</Time>
                <StatusCode>1</StatusCode>
                <active>true</active>
                <RequireHandicap>false</RequireHandicap>
                <RequireGolfLink>false</RequireGolfLink>
                <VisitorAccepted>true</VisitorAccepted>
                <MemberAccepted>true</MemberAccepted>
                <PublicMemberAccepted>false</PublicMemberAccepted>
                <NineHoles>false</NineHoles>
                <EighteenHoles>true</EighteenHoles>
                <BookingEntries>
                  <BookingEntry id="101" type="member" index="1">
                    <PersonName>John Smith</PersonName>
                    <MembershipNumber>M001</MembershipNumber>
                    <Gender>M</Gender>
                    <Handicap>10.0</Handicap>
                    <GolfLinkNo></GolfLinkNo>
                  </BookingEntry>
                  <BookingEntry id="102" type="member" index="2">
                    <PersonName></PersonName>
                    <MembershipNumber></MembershipNumber>
                    <Gender></Gender>
                    <Handicap></Handicap>
                    <GolfLinkNo></GolfLinkNo>
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
          {"GET", "/spring/bookings/events/42"} -> Req.Test.text(conn, event_xml)
          {"POST", "/members/Ajax"} -> Req.Test.text(conn, "<Success/>")
        end
      end)

      {:ok, booking} =
        %Golfex.Bookings.ScheduledBooking{}
        |> Golfex.Bookings.ScheduledBooking.changeset(%{
          user_id: scope.user.id,
          user_club_id: user_club.id,
          miclub_event_id: event.miclub_event_id,
          miclub_group_id: 456,
          miclub_row_id: nil,
          miclub_member_id: 12345,
          scheduled_for: DateTime.utc_now(:second)
        })
        |> Repo.insert()

      assert :ok = perform_job(BookingWorker, %{booking_id: booking.id})

      updated = Bookings.get_scheduled_booking!(booking.id)
      assert updated.status == "completed"
    end

    test "fails when no empty slots available" do
      scope = user_scope_fixture()
      club = club_fixture()
      user_club = user_club_fixture(scope, club)
      event = event_fixture(club, %{miclub_event_id: 42})

      event_xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <BookingEvent>
        <id>42</id>
        <active>true</active>
        <Name>Test Event</Name>
        <Date>2026-04-01</Date>
        <lastModified>2026-03-29</lastModified>
        <BookingSections>
          <BookingSection>
            <id>1</id>
            <active>true</active>
            <Name>Morning</Name>
            <BookingGroups>
              <BookingGroup>
                <id>456</id>
                <Time>08:00</Time>
                <StatusCode>1</StatusCode>
                <active>true</active>
                <RequireHandicap>false</RequireHandicap>
                <RequireGolfLink>false</RequireGolfLink>
                <VisitorAccepted>true</VisitorAccepted>
                <MemberAccepted>true</MemberAccepted>
                <PublicMemberAccepted>false</PublicMemberAccepted>
                <NineHoles>false</NineHoles>
                <EighteenHoles>true</EighteenHoles>
                <BookingEntries>
                  <BookingEntry id="101" type="member" index="1">
                    <PersonName>John Smith</PersonName>
                    <MembershipNumber>M001</MembershipNumber>
                    <Gender>M</Gender>
                    <Handicap>10.0</Handicap>
                    <GolfLinkNo></GolfLinkNo>
                  </BookingEntry>
                  <BookingEntry id="102" type="member" index="2">
                    <PersonName>Jane Doe</PersonName>
                    <MembershipNumber>M002</MembershipNumber>
                    <Gender>F</Gender>
                    <Handicap>15.0</Handicap>
                    <GolfLinkNo></GolfLinkNo>
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
          {"GET", "/spring/bookings/events/42"} -> Req.Test.text(conn, event_xml)
        end
      end)

      {:ok, booking} =
        %Golfex.Bookings.ScheduledBooking{}
        |> Golfex.Bookings.ScheduledBooking.changeset(%{
          user_id: scope.user.id,
          user_club_id: user_club.id,
          miclub_event_id: event.miclub_event_id,
          miclub_group_id: 456,
          miclub_row_id: nil,
          miclub_member_id: 12345,
          scheduled_for: DateTime.utc_now(:second)
        })
        |> Repo.insert()

      assert {:error, reason} = perform_job(BookingWorker, %{booking_id: booking.id})
      assert reason =~ "No empty slots"

      updated = Bookings.get_scheduled_booking!(booking.id)
      assert updated.status == "failed"
      assert updated.last_error =~ "No empty slots"
    end
  end
end
