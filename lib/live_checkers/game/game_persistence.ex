defmodule LiveCheckers.Game.GamePersistence do
  use GenServer
  require Logger

  # Client API

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def save_game(game) do
    GenServer.call(__MODULE__, {:save_game, game})
  end

  def load_game(game_id) do
    GenServer.call(__MODULE__, {:load_game, game_id})
  end

  def delete_saved_game(game_id) do
    GenServer.call(__MODULE__, {:delete_game, game_id})
  end

  # Server Callbacks

  @impl true
  def init(_) do
    # Initialize with an empty map to store games
    {:ok, %{saved_games: %{}}}
  end

  @impl true
  def handle_call({:save_game, game}, _from, state) do
    game_id = game.id || generate_game_id()
    game = %{game | id: game_id}
    new_state = put_in(state.saved_games[game_id], game)
    {:reply, {:ok, game_id}, new_state}
  end

  @impl true
  def handle_call({:load_game, game_id}, _from, state) do
    case Map.get(state.saved_games, game_id) do
      nil ->
        {:reply, {:error, :not_found}, state}
      game ->
        # Broadcast the loaded game state to all players
        Phoenix.PubSub.broadcast(LiveCheckers.PubSub, "game:#{game_id}", {:game_loaded, game})
        {:reply, {:ok, game}, state}
    end
  end

  @impl true
  def handle_call({:delete_game, game_id}, _from, state) do
    new_saved_games = Map.delete(state.saved_games, game_id)
    {:reply, :ok, %{state | saved_games: new_saved_games}}
  end

  # Private functions

  defp generate_game_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
