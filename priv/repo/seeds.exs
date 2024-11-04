# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     App.Repo.insert!(%App.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias App.MiClub.Club
alias App.Repo

clubs = [
  %{
    "name" => "NSW Golf Course",
    "slug" => "nsw_gc",
    "website" => "https://www.nswgolfclub.com.au"
  },
  %{
    "name" => "The Ridge Golf Course",
    "slug" => "ridge",
    "website" => "https//theridgegolf.com.au"
  }
]

for club <- clubs do
  %Club{} |> Club.changeset(club) |> Repo.insert()
end

user = %{email: "test@example.com", password: "password12345"}
App.Accounts.register_user(user)
