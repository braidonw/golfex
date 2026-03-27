defmodule Golfex.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      GolfexWeb.Telemetry,
      Golfex.Repo,
      {DNSCluster, query: Application.get_env(:golfex, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Golfex.PubSub},
      Golfex.Vault,
      {Oban, Application.fetch_env!(:golfex, Oban)},
      # Start to serve requests, typically the last entry
      GolfexWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Golfex.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    GolfexWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
