defmodule LiveCheckers.Game.LobbyManager do
  use GenServer
  require Logger

  alias LiveCheckers.Game.Models.Lobby

  # Client API

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def get_lobbies do
    GenServer.call(__MODULE__, :get_lobbies)
  end

  def create_lobby(name, creator) do
    GenServer.call(__MODULE__, {:create_lobby, name, creator})
  end

  def join_lobby(lobby_id, player) do
    GenServer.call(__MODULE__, {:join_lobby, lobby_id, player})
  end

  def leave_lobby(lobby_id, username) do
    GenServer.call(__MODULE__, {:leave_lobby, lobby_id, username})
  end

  def player_exists?(username) do
    GenServer.call(__MODULE__, {:player_exists, username})
  end

  def get_lobby(lobby_id) do
    GenServer.call(__MODULE__, {:get_lobby, lobby_id})
  end

  def delete_lobby(lobby_id) do
    GenServer.call(__MODULE__, {:delete_lobby, lobby_id})
  end

  def update_lobby_game(lobby_id, game) do
    GenServer.call(__MODULE__, {:update_lobby_game, lobby_id, game})
  end

  # Server Callbacks

  @impl true
  def init(_) do
    {:ok, %{lobbies: %{}, players: %{}}}
  end

  @impl true
  def handle_call(:get_lobbies, _from, state) do
    {:reply, Map.values(state.lobbies), state}
  end

  @impl true
  def handle_call({:create_lobby, name, creator}, _from, state) do
    lobby_id = generate_id()

    # Create a new lobby using the Lobby struct
    lobby = Lobby.new(lobby_id, name, creator)

    new_lobbies = Map.put(state.lobbies, lobby_id, lobby)
    new_players = Map.put(state.players, creator, lobby_id)

    {:reply, {:ok, lobby}, %{state | lobbies: new_lobbies, players: new_players}}
  end

  @impl true
  def handle_call({:join_lobby, lobby_id, player}, _from, state) do
    case Map.get(state.lobbies, lobby_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      lobby ->
        cond do
          Lobby.has_player?(lobby, player) ->
            {:reply, {:error, :already_joined}, state}

          Lobby.full?(lobby) ->
            {:reply, {:error, :lobby_full}, state}

          true ->
            updated_lobby = Lobby.add_player(lobby, player)
            new_lobbies = Map.put(state.lobbies, lobby_id, updated_lobby)
            new_players = Map.put(state.players, player, lobby_id)

            {:reply, {:ok, updated_lobby}, %{state | lobbies: new_lobbies, players: new_players}}
        end
    end
  end

  @impl true
  def handle_call({:leave_lobby, lobby_id, username}, _from, state) do
    case Map.get(state.lobbies, lobby_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      lobby ->
        if not Lobby.has_player?(lobby, username) do
          # Player not in this lobby
          {:reply, {:error, :player_not_in_lobby}, state}
        else
          # Remove player from the lobby using the Lobby struct's function
          case Lobby.remove_player(lobby, username) do
            {:empty, _} ->
              # No players left - delete the lobby
              new_lobbies = Map.delete(state.lobbies, lobby_id)
              new_players = Map.delete(state.players, username)
              {:reply, {:ok, :lobby_deleted}, %{state | lobbies: new_lobbies, players: new_players}}

            {:update_creator, updated_lobby} ->
              # Creator is leaving - assign a new creator
              new_lobbies = Map.put(state.lobbies, lobby_id, updated_lobby)
              new_players = Map.delete(state.players, username)
              {:reply, {:ok, updated_lobby}, %{state | lobbies: new_lobbies, players: new_players}}

            {:ok, updated_lobby} ->
              # Regular player leaving
              new_lobbies = Map.put(state.lobbies, lobby_id, updated_lobby)
              new_players = Map.delete(state.players, username)
              {:reply, {:ok, updated_lobby}, %{state | lobbies: new_lobbies, players: new_players}}
          end
        end
    end
  end

  @impl true
  def handle_call({:delete_lobby, lobby_id}, _from, state) do
    case Map.get(state.lobbies, lobby_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      lobby ->
        new_lobbies = Map.delete(state.lobbies, lobby_id)
        new_players = Enum.reduce(lobby.players, state.players, fn player, acc -> Map.delete(acc, player) end)

        {:reply, {:ok, lobby}, %{state | lobbies: new_lobbies, players: new_players}}
    end
  end

  @impl true
  def handle_call({:player_exists, username}, _from, state) do
    {:reply, Map.has_key?(state.players, username), state}
  end

  @impl true
  def handle_call({:get_lobby, lobby_id}, _from, state) do
    case Map.get(state.lobbies, lobby_id) do
      nil -> {:reply, {:error, :not_found}, state}
      lobby -> {:reply, {:ok, lobby}, state}
    end
  end

  @impl true
  def handle_call({:update_lobby_game, lobby_id, game}, _from, state) do
    case Map.get(state.lobbies, lobby_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      lobby ->
        updated_lobby = %{lobby | game_state: game, status: :in_game}
        new_lobbies = Map.put(state.lobbies, lobby_id, updated_lobby)

        {:reply, {:ok, updated_lobby}, %{state | lobbies: new_lobbies}}
    end
  end

  # Private functions

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
