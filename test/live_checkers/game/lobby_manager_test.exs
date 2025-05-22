use ExUnit.Case, async: false
alias LiveCheckers.Game.LobbyManager

setup do
  # ensure clean state by deleting existing lobbies
  Enum.each(LobbyManager.get_lobbies(), fn l -> LobbyManager.delete_lobby(l.id) end)
  :ok
end

test "finished lobbies are removed" do
  {:ok, lobby} = LobbyManager.create_lobby("Test", "p1")
  {:ok, lobby} = LobbyManager.join_lobby(lobby.id, "p2")
  {:ok, lobby} = LobbyManager.start_game(lobby.id)

  Phoenix.PubSub.broadcast(LiveCheckers.PubSub, "game:" <> lobby.id, {:state_changed, %{id: lobby.id, status: :game_over}})

  # allow async message to process
  Process.sleep(50)

  assert LobbyManager.get_lobby(lobby.id) == nil
  refute LobbyManager.player_exists?("p1")
  refute LobbyManager.player_exists?("p2")

  # stop the started game pid if still alive
  if is_pid(lobby.game_pid) and Process.alive?(lobby.game_pid) do
    GenServer.stop(lobby.game_pid)
  end
end
