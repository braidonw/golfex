defmodule App.MiClub.Supervisor do
  @moduledoc false
  use Supervisor

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_init_arg) do
    children = [
      {Registry, name: App.MiClub.Registry, keys: :unique},
      {App.MiClub.Server,
       name: "nsw_gc",
       base_url: "https://www.nswgolfclub.com.au",
       username: System.get_env("GC_USERNAME"),
       password: System.get_env("GC_PASSWORD")}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
