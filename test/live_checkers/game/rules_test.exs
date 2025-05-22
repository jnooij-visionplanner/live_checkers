defmodule LiveCheckers.Game.RulesTest do
  use ExUnit.Case, async: true

  alias LiveCheckers.Game.Rules

  defp empty_board do
    for r <- 0..7, c <- 0..7, into: %{}, do: {{r, c}, nil}
  end

  describe "legal_moves/2" do
    test "initial board" do
      board = Rules.initial_board()

      moves_black = Rules.legal_moves(board, :black)
      assert {{2, 1}, {3, 0}} in moves_black
      assert length(moves_black) == 7

      moves_red = Rules.legal_moves(board, :red)
      assert {{5, 0}, {4, 1}} in moves_red
      assert length(moves_red) == 7
    end
  end

  describe "valid_move?/4" do
    test "valid and invalid moves" do
      board = Rules.initial_board()
      assert Rules.valid_move?(board, :black, {2, 1}, {3, 0})
      refute Rules.valid_move?(board, :black, {2, 1}, {4, 1})
      refute Rules.valid_move?(board, :red, {2, 1}, {3, 0})
    end
  end

  describe "captures and promotion" do
    test "capture removes jumped piece" do
      board = empty_board()
      board = Map.put(board, {2, 1}, {:black, :man})
      board = Map.put(board, {3, 2}, {:red, :man})

      assert Rules.valid_move?(board, :black, {2, 1}, {4, 3})
      board = Rules.update_board(board, {{2, 1}, {4, 3}})

      assert Map.get(board, {2, 1}) == nil
      assert Map.get(board, {3, 2}) == nil
      assert Map.get(board, {4, 3}) == {:black, :man}
    end

    test "moving to last row promotes" do
      board = empty_board()
      board = Map.put(board, {6, 1}, {:black, :man})

      assert Rules.valid_move?(board, :black, {6, 1}, {7, 0})
      board = Rules.update_board(board, {{6, 1}, {7, 0}})

      assert Map.get(board, {7, 0}) == {:black, :king}
    end
  end
end
