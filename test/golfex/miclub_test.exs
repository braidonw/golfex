defmodule Golfex.MiClubTest do
  use ExUnit.Case, async: true

  alias Golfex.MiClub

  defp stub_miclub_responses(_context) do
    login_response = fn conn -> Req.Test.json(conn, %{}) end

    events_response = fn conn ->
      Req.Test.json(conn, [
        %{
          "bookingEventId" => 1,
          "title" => "Saturday Comp",
          "eventDate" => "2024-01-15",
          "availability" => 24,
          "isOpen" => true,
          "isBallot" => false,
          "isBallotOpen" => false,
          "isLottery" => false,
          "hasCompetition" => true,
          "isMatchplay" => false,
          "isResults" => false,
          "eventStatusCode" => 1,
          "eventStatusCodeFriendly" => "Open",
          "eventTypeCode" => 2,
          "eventCategoryCode" => 3,
          "eventTimeCodeFriendly" => "AM"
        }
      ])
    end

    booking_response = fn conn -> Req.Test.text(conn, "<Success/>") end

    event_detail_response = fn conn ->
      Req.Test.text(conn, """
      <?xml version="1.0" encoding="utf-8"?>
      <BookingEvent>
        <Active>true</Active>
        <Id>1</Id>
        <Date>2024-01-15T07:00:00</Date>
        <Name>Saturday Comp</Name>
        <LastModified>2024-01-10T12:00:00</LastModified>
        <BookingSections>
          <BookingSection>
            <Id>1</Id>
            <Active>true</Active>
            <Name>Morning</Name>
            <BookingGroups>
              <BookingGroup>
                <Id>10</Id>
                <Time>07:00</Time>
                <StatusCode>0</StatusCode>
                <Active>true</Active>
                <RequireHandicap>true</RequireHandicap>
                <RequireGolfLink>false</RequireGolfLink>
                <VisitorAccepted>false</VisitorAccepted>
                <MemberAccepted>true</MemberAccepted>
                <PublicMemberAccepted>false</PublicMemberAccepted>
                <NineHoles>false</NineHoles>
                <EighteenHoles>true</EighteenHoles>
                <BookingEntries>
                  <BookingEntry>
                    <Id>200</Id>
                    <Type>member</Type>
                    <Index>1</Index>
                    <PersonName>John Smith</PersonName>
                    <MembershipNumber>M001</MembershipNumber>
                    <Handicap>15.5</Handicap>
                  </BookingEntry>
                </BookingEntries>
              </BookingGroup>
            </BookingGroups>
          </BookingSection>
        </BookingSections>
      </BookingEvent>
      """)
    end

    %{
      login_response: login_response,
      events_response: events_response,
      booking_response: booking_response,
      event_detail_response: event_detail_response
    }
  end

  defp user_club do
    %{
      club: %{base_url: "https://testgolf.com.au"},
      username: "testuser",
      password: "testpass",
      member_id: "12345"
    }
  end

  defp route_request(conn, ctx) do
    case {conn.method, conn.request_path} do
      {_, "/security/login.msp"} -> ctx.login_response.(conn)
      {"GET", "/spring/bookings/events/between/" <> _} -> ctx.events_response.(conn)
      {"GET", "/spring/bookings/events/" <> _} -> ctx.event_detail_response.(conn)
      {"POST", "/members/Ajax"} -> ctx.booking_response.(conn)
    end
  end

  setup :stub_miclub_responses

  describe "list_events/1" do
    test "fetches and parses events from MiClub", ctx do
      # GET login page + POST login + GET events = 3 requests
      Req.Test.expect(Golfex.MiClub.Client, 3, fn conn ->
        route_request(conn, ctx)
      end)

      assert {:ok, [event]} = MiClub.list_events(user_club())
      assert event.title == "Saturday Comp"
      assert event.availability == 24
    end
  end

  describe "get_event/2" do
    test "fetches and parses event detail from MiClub", ctx do
      Req.Test.expect(Golfex.MiClub.Client, 3, fn conn ->
        route_request(conn, ctx)
      end)

      assert {:ok, event} = MiClub.get_event(user_club(), 1)
      assert event.name == "Saturday Comp"
      assert length(event.booking_sections) == 1
    end
  end

  describe "book/4" do
    test "executes a booking via MiClub", ctx do
      Req.Test.expect(Golfex.MiClub.Client, 3, fn conn ->
        route_request(conn, ctx)
      end)

      assert :ok = MiClub.book(user_club(), 10, 200, "12345")
    end

    test "returns error when booking fails", ctx do
      error_booking = fn conn ->
        Req.Test.text(conn, "<Error><ErrorText>Booking is full</ErrorText></Error>")
      end

      Req.Test.expect(Golfex.MiClub.Client, 3, fn conn ->
        case {conn.method, conn.request_path} do
          {_, "/security/login.msp"} -> ctx.login_response.(conn)
          {"POST", "/members/Ajax"} -> error_booking.(conn)
        end
      end)

      assert {:error, "Booking is full"} = MiClub.book(user_club(), 10, 200, "12345")
    end
  end
end
