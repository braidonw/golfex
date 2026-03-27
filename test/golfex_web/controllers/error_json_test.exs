defmodule GolfexWeb.ErrorJSONTest do
  use GolfexWeb.ConnCase, async: true

  test "renders 404" do
    assert GolfexWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert GolfexWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
