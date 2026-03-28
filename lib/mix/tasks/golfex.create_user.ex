defmodule Mix.Tasks.Golfex.CreateUser do
  @shortdoc "Creates a new user account"
  @moduledoc "Creates a new user: mix golfex.create_user email password"

  use Mix.Task

  @impl Mix.Task
  def run([email, password]) do
    Mix.Task.run("app.start")

    case Golfex.Accounts.register_user(%{email: email, password: password}) do
      {:ok, user} ->
        user
        |> Ecto.Changeset.change(confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second))
        |> Golfex.Repo.update!()

        Mix.shell().info("User created: #{email}")

      {:error, changeset} ->
        errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
        Mix.shell().error("Failed to create user: #{inspect(errors)}")
    end
  end

  def run(_) do
    Mix.shell().error("Usage: mix golfex.create_user EMAIL PASSWORD")
  end
end
