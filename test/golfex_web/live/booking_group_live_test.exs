defmodule GolfexWeb.BookingGroupLiveTest do
  use GolfexWeb.ConnCase, async: true

  import Golfex.AccountsFixtures
  import Golfex.ClubsFixtures
  import Golfex.EventsFixtures
  import Phoenix.LiveViewTest

  describe "Show" do
    test "renders loading state on mount", %{conn: conn} do
      user = user_fixture()
      scope = Golfex.Accounts.Scope.for_user(user)
      club = club_fixture(%{name: "Test Club"})
      _user_club = user_club_fixture(scope, club)

      event =
        event_fixture(club, %{
          title: "Saturday Comp",
          event_date: ~D[2026-04-04]
        })

      Req.Test.stub(Golfex.MiClub.Client, fn conn ->
        Req.Test.json(conn, %{})
      end)

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/clubs/#{club.id}/events/#{event.id}/groups/1")

      assert html =~ "Loading group details"
    end

    test "shows 'Opens for booking' when event has auto_open_date_time_display", %{conn: conn} do
      user = user_fixture()
      scope = Golfex.Accounts.Scope.for_user(user)
      club = club_fixture(%{name: "Test Club"})
      _user_club = user_club_fixture(scope, club)

      event =
        event_fixture(club, %{
          title: "Saturday Comp",
          event_date: ~D[2026-04-04],
          is_open: false,
          auto_open_date_time_display: "04/04/2026 7:00 AM"
        })

      event_detail_xml = """
      <?xml version="1.0" encoding="utf-8"?>
      <BookingEvent id="#{event.miclub_event_id}">
        <active>true</active>
        <id>#{event.miclub_event_id}</id>
        <Date>2026-04-04T07:00:00</Date>
        <Name>Saturday Comp</Name>
        <lastModified>2026-03-28T12:00:00</lastModified>
        <BookingSections>
          <BookingSection id="1">
            <id>1</id>
            <active>true</active>
            <Name>Morning</Name>
            <BookingGroups>
              <BookingGroup id="10" size="4">
                <id>10</id>
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
        case conn.request_path do
          "/security/login.msp" -> Req.Test.json(conn, %{})
          "/spring/bookings/events/" <> _ -> Req.Test.text(conn, event_detail_xml)
        end
      end)

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/clubs/#{club.id}/events/#{event.id}/groups/10")

      # Wait for async load
      html = render(lv)
      assert html =~ "Opens for booking"
      assert html =~ "04/04/2026 7:00 AM"
      assert html =~ "Schedule Booking"
      refute html =~ "Book Now"
    end

    test "shows 'Book Now' button when event is open", %{conn: conn} do
      user = user_fixture()
      scope = Golfex.Accounts.Scope.for_user(user)
      club = club_fixture(%{name: "Test Club"})
      _user_club = user_club_fixture(scope, club)

      event =
        event_fixture(club, %{
          title: "Saturday Comp",
          event_date: ~D[2026-04-04],
          is_open: true
        })

      event_detail_xml = """
      <?xml version="1.0" encoding="utf-8"?>
      <BookingEvent id="#{event.miclub_event_id}">
        <active>true</active>
        <id>#{event.miclub_event_id}</id>
        <Date>2026-04-04T07:00:00</Date>
        <Name>Saturday Comp</Name>
        <lastModified>2026-03-28T12:00:00</lastModified>
        <BookingSections>
          <BookingSection id="1">
            <id>1</id>
            <active>true</active>
            <Name>Morning</Name>
            <BookingGroups>
              <BookingGroup id="10" size="4">
                <id>10</id>
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
        case conn.request_path do
          "/security/login.msp" -> Req.Test.json(conn, %{})
          "/spring/bookings/events/" <> _ -> Req.Test.text(conn, event_detail_xml)
        end
      end)

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/clubs/#{club.id}/events/#{event.id}/groups/10")

      html = render(lv)
      assert html =~ "Book Now"
      refute html =~ "Schedule Booking"
    end
  end
end
