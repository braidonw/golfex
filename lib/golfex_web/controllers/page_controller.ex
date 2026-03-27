defmodule GolfexWeb.PageController do
  use GolfexWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
