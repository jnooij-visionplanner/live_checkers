defmodule LiveCheckersWeb.GameLiveTest do
  use LiveCheckersWeb.ConnCase

  import Phoenix.LiveViewTest

  alias LiveCheckers.Game.CheckersGame

  setup %{conn: conn} do
    {:ok, pid} = CheckersGame.start_link({"ui_game", ["p1", "p2"]})
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    {:ok, conn: conn, game_id: "ui_game"}
  end

  test "selecting and moving a piece", %{conn: conn, game_id: id} do
    {:ok, lv, _html} = live(conn, ~p"/game/#{id}")

    lv |> element("#square-2-1") |> render_click()
    assert lv.assigns.selected == {2, 1}

    lv |> element("#square-3-0") |> render_click()

    state = CheckersGame.current_state(id)
    assert Map.get(state.board, {3, 0}) == {:black, :man}
    assert state.turn == :red
  end
end

