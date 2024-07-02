defmodule App.MiClub.Api do
  @moduledoc false

  def list_events(base_url) do
    [base_url: base_url] |> Req.new() |> Req.get("/spring/bookings/events/between/{}/{}/3000000")
  end
end
