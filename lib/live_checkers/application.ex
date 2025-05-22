defmodule LiveCheckers.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      LiveCheckersWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:live_checkers, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: LiveCheckers.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: LiveCheckers.Finch},
      # Start a worker by calling: LiveCheckers.Worker.start_link(arg)
      # {LiveCheckers.Worker, arg},
      LiveCheckers.Game.LobbyManager,
      LiveCheckers.Game.GamePersistence,
      # Start to serve requests, typically the last entry
      LiveCheckersWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: LiveCheckers.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LiveCheckersWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
