defmodule Golfex.MiClub.ParserTest do
  use ExUnit.Case, async: true

  alias Golfex.MiClub.Parser

  describe "parse_events/1" do
    test "parses JSON event list" do
      json = """
      [
        {
          "Id": 100,
          "EventDate": "2024-01-15T00:00:00",
          "Title": "Saturday Comp",
          "Availability": 24,
          "IsOpen": true,
          "IsBallot": false,
          "IsBallotOpen": false,
          "IsLottery": false,
          "HasCompetition": true,
          "IsMatchplay": false,
          "IsResults": false,
          "EventStatusCode": 1,
          "EventStatusCodeFriendly": "Open",
          "EventTypeCode": 2,
          "EventCategoryCode": 3,
          "EventTimeCodeFriendly": "AM"
        }
      ]
      """

      assert {:ok, [event]} = Parser.parse_events(json)
      assert event.id == 100
      assert event.title == "Saturday Comp"
      assert event.availability == 24
      assert event.is_open == true
    end

    test "returns error for invalid JSON" do
      assert {:error, _} = Parser.parse_events("not json")
    end

    test "returns error for non-list JSON" do
      assert {:error, :unexpected_format} = Parser.parse_events(~s({"key": "value"}))
    end
  end

  describe "parse_event_detail/1" do
    test "parses XML event detail with sections, groups, and entries" do
      xml = """
      <?xml version="1.0" encoding="utf-8"?>
      <BookingEvent>
        <Active>true</Active>
        <Id>100</Id>
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
      """

      assert {:ok, event} = Parser.parse_event_detail(xml)
      assert event.id == 100
      assert event.name == "Saturday Comp"

      [section] = event.booking_sections
      assert section.name == "Morning"

      [group] = section.booking_groups
      assert group.time == "07:00"
      assert group.eighteen_holes == true

      [entry] = group.booking_entries
      assert entry.person_name == "John Smith"
      assert entry.handicap == 15.5
    end
  end

  describe "parse_booking_response/1" do
    test "returns :ok for successful booking (no error XML)" do
      assert :ok = Parser.parse_booking_response("<Success/>")
    end

    test "returns error for failed booking" do
      xml = """
      <Error>
        <ErrorText>Booking is full</ErrorText>
      </Error>
      """

      assert {:error, "Booking is full"} = Parser.parse_booking_response(xml)
    end
  end
end
