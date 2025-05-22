defmodule LiveCheckers.Game.LobbyManager do
  use GenServer
  require Logger

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

  def start_game(lobby_id) do
    GenServer.call(__MODULE__, {:start_game, lobby_id})
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

    lobby = %{
      id: lobby_id,
      name: name,
      creator: creator,
      players: [creator],
      created_at: DateTime.utc_now()
    }

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
          player in lobby.players ->
            {:reply, {:error, :already_joined}, state}

          length(lobby.players) >= 2 ->
            {:reply, {:error, :lobby_full}, state}

          true ->
            updated_lobby = Map.update!(lobby, :players, &[player | &1])
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
        if username not in lobby.players do
          # Player not in this lobby
          {:reply, {:error, :player_not_in_lobby}, state}
        else
          # Remove player from the lobby's player list
          remaining_players = Enum.filter(lobby.players, fn player -> player != username end)

          # Remove player from players map
          new_players = Map.delete(state.players, username)

          cond do
            # No players left - delete the lobby
            Enum.empty?(remaining_players) ->
              new_lobbies = Map.delete(state.lobbies, lobby_id)
              {:reply, {:ok, :lobby_deleted}, %{state | lobbies: new_lobbies, players: new_players}}

            # Creator is leaving - assign a new creator
            username == lobby.creator ->
              new_creator = List.first(remaining_players)
              updated_lobby = %{lobby | players: remaining_players, creator: new_creator}
              new_lobbies = Map.put(state.lobbies, lobby_id, updated_lobby)
              {:reply, {:ok, updated_lobby}, %{state | lobbies: new_lobbies, players: new_players}}

            # Regular player leaving
            true ->
              updated_lobby = %{lobby | players: remaining_players}
              new_lobbies = Map.put(state.lobbies, lobby_id, updated_lobby)
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
    {:reply, Map.get(state.lobbies, lobby_id), state}
  end

  @impl true
  def handle_call({:start_game, lobby_id}, _from, state) do
    case Map.get(state.lobbies, lobby_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      %{players: players} = lobby when length(players) < 2 ->
        {:reply, {:error, :not_enough_players}, state}

      lobby ->
        if Map.has_key?(lobby, :game_pid) do
          {:reply, {:error, :already_started}, state}
        else
          {:ok, pid} = LiveCheckers.Game.GameSupervisor.start_game(lobby_id, Enum.reverse(lobby.players))
          updated_lobby = Map.put(lobby, :game_pid, pid)
          new_lobbies = Map.put(state.lobbies, lobby_id, updated_lobby)
          {:reply, {:ok, updated_lobby}, %{state | lobbies: new_lobbies}}
        end
    end
  end

  # Private functions

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
