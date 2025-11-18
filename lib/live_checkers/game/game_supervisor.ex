defmodule LiveCheckers.Game.GameSupervisor do
  @moduledoc """
  Dynamic supervisor responsible for running `CheckersGame` processes.
  """
  use DynamicSupervisor

  alias LiveCheckers.Game.CheckersGame

  ## Public API

  @doc "Starts the supervisor"
  def start_link(_init_arg \\ []) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc "Starts a new game under the supervisor"
  def start_game(game_id, players) do
    child_spec = {CheckersGame, {game_id, players}}
    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  ## Callbacks

  @impl true
  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end

