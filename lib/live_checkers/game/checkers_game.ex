defmodule LiveCheckers.Game.CheckersGame do
  @moduledoc """
  A GenServer representing a single game of checkers.

  The process keeps track of the current board state, whose turn it is and
  which players are participating. State changes are broadcast on the topic
  `"game:" <> game_id` via `LiveCheckers.PubSub`.
  """

  use GenServer

  alias Phoenix.PubSub

  ## Client API

  @doc """
  Starts a new game process. `game_id` is typically the lobby id and
  `players` should be a list with two player names `[player_one, player_two]`.
  """
  def start_link({game_id, players}) do
    GenServer.start_link(__MODULE__, {game_id, players}, name: game_name(game_id))
  end

  @doc "Returns the current state for the given `game_id`."
  def current_state(game_id) do
    GenServer.call(game_name(game_id), :current_state)
  end

  @doc "Applies a move described by `{from, to}` coordinates." 
  def apply_move(game_id, {from, to} = move) do
    GenServer.call(game_name(game_id), {:apply_move, move})
  end

  @doc "Resign from the game as `player`."
  def resign(game_id, player) do
    GenServer.call(game_name(game_id), {:resign, player})
  end

  ## Server callbacks

  @impl true
  def init({game_id, [p1, p2]}) do
    state = %{
      id: game_id,
      board: initial_board(),
      players: %{black: p1, red: p2},
      turn: :black,
      status: :playing,
      winner: nil
    }

    broadcast_state(state)
    {:ok, state}
  end

  @impl true
  def handle_call(:current_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:apply_move, {from, to}}, _from, %{status: :game_over} = state) do
    {:reply, {:error, :game_over}, state}
  end

  def handle_call({:apply_move, {from, to}}, _from, state) do
    piece = Map.get(state.board, from)

    cond do
      piece == nil ->
        {:reply, {:error, :no_piece}, state}

      elem(piece, 0) != state.turn ->
        {:reply, {:error, :wrong_turn}, state}

      Map.get(state.board, to) != nil ->
        {:reply, {:error, :occupied}, state}

      true ->
        new_board =
          state.board
          |> Map.put(from, nil)
          |> Map.put(to, piece)

        new_state = %{state | board: new_board, turn: opposite(state.turn)}
        broadcast_state(new_state)
        {:reply, {:ok, new_state}, new_state}
    end
  end

  def handle_call({:resign, player}, _from, state) do
    color = player_color(state, player)

    cond do
      color == nil ->
        {:reply, {:error, :unknown_player}, state}

      state.status == :game_over ->
        {:reply, {:error, :game_over}, state}

      true ->
        other_color = opposite(color)
        winner = Map.get(state.players, other_color)
        new_state = %{state | status: :game_over, winner: winner}
        broadcast_state(new_state)
        {:reply, :ok, new_state}
    end
  end

  ## Internal helpers

  defp broadcast_state(state) do
    topic = "game:" <> state.id
    PubSub.broadcast(LiveCheckers.PubSub, topic, {:state_changed, state})
  end

  defp game_name(game_id) do
    String.to_atom("checkers_game_" <> game_id)
  end

  defp opposite(:black), do: :red
  defp opposite(:red), do: :black

  defp player_color(state, player) do
    Enum.find_value(state.players, fn {color, name} -> if name == player, do: color end)
  end

  defp initial_board do
    for row <- 0..9, col <- 0..9, into: %{} do
      cond do
        row < 4 and rem(row + col, 2) == 1 -> {{row, col}, {:black, :man}}
        row > 5 and rem(row + col, 2) == 1 -> {{row, col}, {:red, :man}}
        true -> {{row, col}, nil}
      end
    end
  end
end
