defmodule LiveCheckers.Game.Rules do
  @moduledoc """
  Helper functions implementing basic checkers rules.
  The board is represented as a map from `{row, col}` coordinates to
  `{color, type}` tuples or `nil` when the square is empty.
  """

  @board_range 0..9

  @type color :: :black | :red
  @type piece_type :: :man | :king
  @type coord :: {integer(), integer()}
  @type piece :: {color(), piece_type()}
  @type board :: %{coord() => piece() | nil}
  @type move :: {coord(), coord()}

  @doc "Returns the initial board setup for a game of checkers."
  @spec initial_board() :: board()
  def initial_board do
    for row <- 0..9, col <- 0..9, into: %{} do
      cond do
        row < 4 and rem(row + col, 2) == 1 -> {{row, col}, {:black, :man}}
        row > 5 and rem(row + col, 2) == 1 -> {{row, col}, {:red, :man}}
        true -> {{row, col}, nil}
      end
    end
  end

  @doc "Returns a list of legal moves for `color` on the given `board`."
  @spec legal_moves(board(), color()) :: [move()]
  def legal_moves(board, color) do
    board
    |> Enum.filter(fn {_pos, piece} -> match?({^color, _}, piece) end)
    |> Enum.flat_map(fn {pos, piece} -> piece_moves(board, pos, piece) end)
  end

  @doc "Returns true if `{from, to}` is a legal move for `color` on `board`."
  @spec valid_move?(board(), color(), coord(), coord()) :: boolean()
  def valid_move?(board, color, from, to) do
    case Map.get(board, from) do
      {^color, _} = piece ->
        Enum.any?(piece_moves(board, from, piece), fn {_f, dest} -> dest == to end)
      _ ->
        false
    end
  end

  @doc """
  Updates the board by applying the given move. The move is assumed to be
  valid and is not rechecked.
  """
  @spec update_board(board(), move()) :: board()
  def update_board(board, {from, to}) do
    piece = Map.fetch!(board, from)
    capture? = capture_move?(from, to)

    board
    |> Map.put(from, nil)
    |> Map.put(to, maybe_promote(piece, to))
    |> maybe_remove_captured(from, to, capture?)
  end

  # -- internal helpers -----------------------------------------------------

  defp piece_moves(board, {row, col} = from, {color, type}) do
    directions =
      case type do
        :man ->
          if color == :black, do: [{1, -1}, {1, 1}], else: [{-1, -1}, {-1, 1}]
        :king ->
          [{1, -1}, {1, 1}, {-1, -1}, {-1, 1}]
      end

    Enum.flat_map(directions, fn {dr, dc} ->
      step = {row + dr, col + dc}
      moves =
        if inside_board?(step) && Map.get(board, step) == nil do
          [{from, step}]
        else
          []
        end

      capture_dest = {row + 2 * dr, col + 2 * dc}
      between = {row + dr, col + dc}
      capture_moves =
        if inside_board?(capture_dest) &&
             match?({other_color(color), _}, Map.get(board, between)) &&
             Map.get(board, capture_dest) == nil do
          [{from, capture_dest}]
        else
          []
        end

      moves ++ capture_moves
    end)
  end

  defp maybe_remove_captured(board, _from, _to, false), do: board
  defp maybe_remove_captured(board, from, to, true) do
    mid = middle(from, to)
    Map.put(board, mid, nil)
  end

  defp capture_move?({r1, _c1}, {r2, _c2}), do: abs(r1 - r2) == 2

  defp inside_board?({row, col}) do
    row in @board_range and col in @board_range
  end

  defp other_color(:black), do: :red
  defp other_color(:red), do: :black

  defp maybe_promote({color, :man}, {row, _}) do
    cond do
      color == :black and row == 9 -> {color, :king}
      color == :red and row == 0 -> {color, :king}
      true -> {color, :man}
    end
  end

  defp maybe_promote(piece, _pos), do: piece

  defp middle({r1, c1}, {r2, c2}) do
    {div(r1 + r2, 2), div(c1 + c2, 2)}
  end
end
