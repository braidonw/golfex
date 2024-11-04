defmodule App.MiClub.Supervisor do
  @moduledoc false
  use Supervisor

  alias App.MiClub.Server

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_init_arg) do
    children = [
      {Registry, name: App.MiClub.Registry, keys: :unique},
      Supervisor.child_spec({Server, :nsw_gc}, id: :nsw_gc_server),
      Supervisor.child_spec({Server, :ridge}, id: :ridge_server)
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
