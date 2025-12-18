defmodule Raining.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      RainingWeb.Telemetry,
      Raining.Repo,
      {DNSCluster, query: Application.get_env(:raining, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Raining.PubSub},
      # Start a worker by calling: Raining.Worker.start_link(arg)
      # {Raining.Worker, arg},
      # Start to serve requests, typically the last entry
      RainingWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Raining.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    RainingWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
