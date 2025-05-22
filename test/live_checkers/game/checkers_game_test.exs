defmodule LiveCheckers.Game.CheckersGameTest do
  use ExUnit.Case, async: false

  alias LiveCheckers.Game.CheckersGame

  setup do
    {:ok, pid} = CheckersGame.start_link({"game_test", ["p1", "p2"]})
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    %{game_id: "game_test"}
  end

  test "initial state", %{game_id: id} do
    state = CheckersGame.current_state(id)
    assert state.turn == :black
    assert state.players.black == "p1"
    assert state.players.red == "p2"
    assert Map.get(state.board, {2, 1}) == {:black, :man}
  end

  test "apply valid move", %{game_id: id} do
    assert {:ok, state} = CheckersGame.apply_move(id, {{2, 1}, {3, 0}})
    assert Map.get(state.board, {2, 1}) == nil
    assert Map.get(state.board, {3, 0}) == {:black, :man}
    assert state.turn == :red
  end

  test "reject invalid move", %{game_id: id} do
    assert {:error, :wrong_turn} = CheckersGame.apply_move(id, {{6, 1}, {5, 0}})
  end

  test "resign ends game", %{game_id: id} do
    :ok = CheckersGame.resign(id, "p1")
    state = CheckersGame.current_state(id)
    assert state.status == :game_over
    assert state.winner == "p2"
  end
end

