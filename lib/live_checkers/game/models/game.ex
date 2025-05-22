defmodule LiveCheckers.Game.Models.Game do
  @moduledoc """
  Represents an international draughts game.
  """

  alias LiveCheckers.Game.GamePersistence

  @type piece_type :: :regular | :king
  @type piece :: %{type: piece_type, player: integer()}
  @type position :: {integer(), integer()}
  @type move :: {position, position, [position] | nil}  # from, to, captured pieces
  @type capture :: {position, position, position} # from, jumped, to

  @type t :: %__MODULE__{
    id: String.t(),
    board: %{position => piece},
    players: [%{username: String.t(), color: :white | :black}],
    current_player_index: integer(),
    status: :waiting | :in_progress | :finished,
    winner: String.t() | nil,
    moves: [move()],
    started_at: DateTime.t(),
    finished_at: DateTime.t() | nil,
    saved: boolean()
  }

  defstruct [
    :id,
    board: %{},
    players: [],
    current_player_index: 0,
    status: :waiting,
    winner: nil,
    moves: [],
    started_at: nil,
    finished_at: nil,
    available_moves: [],
    saved: false
  ]

  @board_size 10

  @doc """
  Creates a new game with the given players.
  """
  def new(id, players) when length(players) == 2 do
    # Sort players - we assign the first player to be white
    sorted_players = Enum.map(Enum.with_index(players), fn {username, idx} ->
      %{username: username, color: if(idx == 0, do: :white, else: :black)}
    end)

    %__MODULE__{
      id: id,
      board: initialize_board(),
      players: sorted_players,
      status: :in_progress,
      started_at: DateTime.utc_now(),
      available_moves: calculate_available_moves(initialize_board(), 0)
    }
  end

  @doc """
  Initializes the board with pieces in their starting positions.
  """
  def initialize_board do
    # Initialize the empty board
    board = %{}

    # Add white pieces (player 0) - bottom of the board
    white_board = Enum.reduce(1..4, board, fn row, acc ->
      populate_row(acc, row, 0)
    end)

    # Add black pieces (player 1) - top of the board
    Enum.reduce(7..10, white_board, fn row, acc ->
      populate_row(acc, row, 1)
    end)
  end

  defp populate_row(board, row, player) do
    Enum.reduce(1..@board_size, board, fn col, acc ->
      # Pieces only go on black squares, which are when row+col is odd
      if rem(row + col, 2) == 1 do
        Map.put(acc, {col, row}, %{type: :regular, player: player})
      else
        acc
      end
    end)
  end

  @doc """
  Makes a move on the board.
  """
  def make_move(game, player_index, from_pos, to_pos) do
    # Check if it's the player's turn
    if player_index != game.current_player_index do
      {:error, :not_your_turn}
    else
      # Check if the move is in the list of available moves
      case find_matching_move(game.available_moves, from_pos, to_pos) do
        nil ->
          {:error, :invalid_move}

        move = {_, _, captures} ->
          # Execute the move
          {updated_board, crowned} = execute_move(game.board, move)

          # Check if there are follow-up captures
          follow_up_captures = if captures && crowned do
            [] # No follow-up captures if piece was just crowned
          else
            check_follow_up_captures(updated_board, to_pos)
          end

          if captures && !crowned && length(follow_up_captures) > 0 do
            # Player must continue capturing with the same piece
            updated_game = %{game |
              board: updated_board,
              moves: [move | game.moves],
              available_moves: follow_up_captures
            }
            {:ok, :continue_capturing, updated_game}
          else
            # Move to next player
            next_player = rem(game.current_player_index + 1, 2)
            next_moves = calculate_available_moves(updated_board, next_player)

            # Check if game is over
            cond do
              Enum.empty?(next_moves) ->
                # Player has no moves - current player wins
                winner = Enum.at(game.players, game.current_player_index).username
                updated_game = %{game |
                  board: updated_board,
                  status: :finished,
                  winner: winner,
                  finished_at: DateTime.utc_now(),
                  moves: [move | game.moves],
                  available_moves: []
                }
                {:ok, :game_over, updated_game}

              true ->
                # Game continues with next player
                updated_game = %{game |
                  board: updated_board,
                  current_player_index: next_player,
                  moves: [move | game.moves],
                  available_moves: next_moves
                }
                {:ok, :valid_move, updated_game}
            end
          end
      end
    end
  end

  # Implement the rest of the game logic functions
  # Including move validation, execution, and calculating available moves

  # Find a matching move in the available moves list
  defp find_matching_move(moves, from_pos, to_pos) do
    Enum.find(moves, fn {from, to, _} -> from == from_pos && to == to_pos end)
  end

  # Execute a move on the board
  defp execute_move(board, {from, to, captures}) do
    # Get the piece being moved
    piece = Map.get(board, from)

    # Remove the piece from its original position
    board = Map.delete(board, from)

    # Remove any captured pieces
    board = if captures && length(captures) > 0 do
      Enum.reduce(captures, board, fn pos, acc ->
        Map.delete(acc, pos)
      end)
    else
      board
    end

    # Check if the piece should be crowned
    {crowned, updated_piece} = check_for_crowning(piece, to)

    # Place the piece at its new position
    board = Map.put(board, to, updated_piece)

    {board, crowned}
  end

  # Check if a piece should be crowned (become a king)
  defp check_for_crowning(piece = %{type: :regular, player: 0}, {_, row}) do
    if row == @board_size do
      {true, %{piece | type: :king}}
    else
      {false, piece}
    end
  end

  defp check_for_crowning(piece = %{type: :regular, player: 1}, {_, row}) do
    if row == 1 do
      {true, %{piece | type: :king}}
    else
      {false, piece}
    end
  end

  defp check_for_crowning(piece, _), do: {false, piece}

  # Check for follow-up captures after a capturing move
  defp check_follow_up_captures(board, position) do
    piece = Map.get(board, position)

    case piece do
      %{type: :regular, player: player} ->
        find_capture_moves(board, position, player, :regular)

      %{type: :king, player: player} ->
        find_capture_moves(board, position, player, :king)

      _ -> []
    end
  end

  # Helper to find all capture sequences starting from a given position after an initial capture
  # Returns a list of {final_landing_pos, all_captured_in_sequence}
  defp find_capture_sequences_recursive(board, current_pos, player, piece_type, captured_so_far) do
    # Find next possible single captures from current_pos
    next_captures =
      case piece_type do
        :regular -> find_regular_captures(board, current_pos, player)
        :king -> find_king_captures(board, current_pos, player)
      end
      |> Enum.filter(fn {_, _, captured} -> captured != nil and length(captured) > 0 end) # Ensure they are captures

    if Enum.empty?(next_captures) do
      # Base case: No more captures possible from here. Return the sequence found so far.
      [{current_pos, captured_so_far}]
    else
      # Recursive step: Explore each possible next capture
      Enum.flat_map(next_captures, fn {from, next_pos, [captured_piece_pos]} ->
        # Simulate the board state after this capture
        moving_piece = Map.get(board, from) # Get the piece from its 'from' position in this step
        simulated_board = board
                          |> Map.delete(from)
                          |> Map.delete(captured_piece_pos)
                          |> Map.put(next_pos, moving_piece) # Place piece at landing spot

        # Recursively find sequences starting from the new position
        find_capture_sequences_recursive(
          simulated_board,
          next_pos,
          player,
          piece_type, # Piece type doesn't change mid-sequence
          captured_so_far ++ [captured_piece_pos]
        )
      end)
    end
  end

  # Calculate all available moves for a player, enforcing mandatory maximum capture
  def calculate_available_moves(board, player_index) do
    player_pieces = for {pos, piece = %{player: ^player_index}} <- board, do: {pos, piece}

    # Find all possible *first* captures for all pieces
    initial_captures = Enum.flat_map(player_pieces, fn {pos, piece} ->
      find_capture_moves(board, pos, player_index, piece.type)
      |> Enum.filter(fn {_, _, captured} -> captured != nil and length(captured) > 0 end)
    end)

    if Enum.empty?(initial_captures) do
      # No captures possible, find regular moves
      Enum.flat_map(player_pieces, fn {pos, piece} ->
        find_regular_moves(board, pos, player_index, piece.type)
      end)
    else
      # Captures are mandatory. Find all full capture sequences.
      all_sequences = Enum.flat_map(initial_captures, fn {start_pos, first_landing_pos, [first_captured_pos]} ->
        # Simulate the board after the first capture
        piece = Map.get(board, start_pos)
        simulated_board = board
                          |> Map.delete(start_pos)
                          |> Map.delete(first_captured_pos)
                          |> Map.put(first_landing_pos, piece)

        # Find all continuations from the first landing position
        continuations = find_capture_sequences_recursive(
          simulated_board,
          first_landing_pos,
          player_index,
          piece.type,
          [first_captured_pos] # Start recursion with the first capture already made
        )

        # Format the results as {start_pos, final_landing_pos, all_captured_list}
        Enum.map(continuations, fn {final_landing_pos, all_captured_list} ->
          {start_pos, final_landing_pos, all_captured_list}
        end)
      end)

      # Find the maximum number of captures
      max_captures = Enum.map(all_sequences, fn {_, _, captured} -> length(captured) end)
                     |> Enum.max(fn -> 0 end) # Handle case where all_sequences might be empty

      # Filter sequences to keep only those with the maximum number of captures
      Enum.filter(all_sequences, fn {_, _, captured} -> length(captured) == max_captures end)
    end
  end

  # Find regular (non-capturing) moves
  defp find_regular_moves(board, {x, y}, player, :regular) do
    # Direction depends on player (white moves to higher row index, black to lower)
    dy = if player == 0, do: 1, else: -1 # CORRECTED direction logic

    # Check forward diagonal moves
    Enum.flat_map([-1, 1], fn dx ->
      new_pos = {x + dx, y + dy}

      if is_valid_position?(new_pos) && is_empty?(board, new_pos) do
        [{{x, y}, new_pos, nil}] # Return a list containing the move tuple
      else
        []
      end
    end)
  end

  defp find_regular_moves(board, {x, y}, player, :king) do
    # Kings can move diagonally in all directions
    directions = for dx <- [-1, 1], dy <- [-1, 1], do: {dx, dy}

    # Kings can move any distance diagonally
    Enum.flat_map(directions, fn {dx, dy} ->
      # Find all empty spots in this direction, starting from the original position
      find_moves_in_direction(board, {x, y}, {x, y}, dx, dy, player, [])
    end)
  end

  # Find all empty positions in a direction until an obstacle is hit
  # Added original_pos argument and corrected recursion/return value
  defp find_moves_in_direction(board, original_pos, {curr_x, curr_y}, dx, dy, player, acc) do
    new_pos = {curr_x + dx, curr_y + dy}

    if is_valid_position?(new_pos) && is_empty?(board, new_pos) do
      # Continue in this direction
      move = {original_pos, new_pos, nil} # Move is from original_pos to new_pos
      find_moves_in_direction(board, original_pos, new_pos, dx, dy, player, [move | acc]) # Recurse from new_pos
    else
      # Hit a boundary or a piece
      Enum.reverse(acc) # Return moves in order
    end
  end

  # Find capturing moves
  defp find_capture_moves(board, {x, y}, player, piece_type) do
    case piece_type do
      :regular -> find_regular_captures(board, {x, y}, player)
      :king -> find_king_captures(board, {x, y}, player)
    end
  end

  # Find captures for regular pieces
  defp find_regular_captures(board, {x, y}, player) do
    # Regular pieces can capture in all four diagonal directions
    directions = for dx <- [-1, 1], dy <- [-1, 1], do: {dx, dy}

    Enum.flat_map(directions, fn {dx, dy} ->
      check_capture_in_direction(board, {x, y}, dx, dy, player) # Use helper
    end)
  end

  # Helper to check for a regular capture in one direction
  defp check_capture_in_direction(board, from_pos = {x, y}, dx, dy, player) do
    opponent_pos = {x + dx, y + dy}
    landing_pos = {x + 2 * dx, y + 2 * dy}
    opponent_player = 1 - player

    if is_valid_position?(opponent_pos) && is_valid_position?(landing_pos) do
      case {get_piece_at(board, opponent_pos), get_piece_at(board, landing_pos)} do
        {%{player: ^opponent_player}, nil} -> # Opponent piece and empty landing spot
          [{from_pos, landing_pos, [opponent_pos]}] # Return list with the capture move
        _ ->
          [] # Cannot capture in this direction
      end
    else
      [] # Out of bounds
    end
  end

  # Find captures for king pieces
  defp find_king_captures(board, from_pos = {_x, _y}, player) do
    # Kings can capture in all four diagonal directions
    directions = for dx <- [-1, 1], dy <- [-1, 1], do: {dx, dy}

    # For each direction, find all possible captures
    Enum.flat_map(directions, fn {dx, dy} ->
      find_king_captures_in_direction(board, from_pos, dx, dy, player)
    end)
  end

  # Find all possible king captures in a specific direction
  defp find_king_captures_in_direction(board, from_pos = {x, y}, dx, dy, player) do
    # Look for opponent pieces along the diagonal
    find_king_captures_recursive(board, from_pos, {x + dx, y + dy}, dx, dy, player, [])
  end

  # Recursively find all possible king captures along a diagonal
  defp find_king_captures_recursive(board, from_pos, curr_pos = {x, y}, dx, dy, player, captures) do
    opponent_player = 1 - player

    cond do
      # If we're out of bounds or hit our own piece, stop searching
      !is_valid_position?(curr_pos) ||
      (Map.has_key?(board, curr_pos) && Map.get(board, curr_pos).player == player) ->
        []

      # If we find an opponent's piece
      Map.has_key?(board, curr_pos) && Map.get(board, curr_pos).player == opponent_player ->
        # Look for landing spots beyond the opponent piece
        find_king_landing_spots(board, from_pos, curr_pos, {x + dx, y + dy}, dx, dy)

      # Empty square, continue searching
      true ->
        find_king_captures_recursive(board, from_pos, {x + dx, y + dy}, dx, dy, player, captures)
    end
  end

  # Find all valid landing spots after jumping over an opponent piece
  defp find_king_landing_spots(board, from_pos, captured_pos, curr_pos = {x, y}, dx, dy) do
    cond do
      # Out of bounds or occupied square stops the search
      !is_valid_position?(curr_pos) || Map.has_key?(board, curr_pos) ->
        []

      # Valid landing spot found
      true ->
        # This position is a valid landing spot
        current_capture = {from_pos, curr_pos, [captured_pos]}
        # Continue looking for further landing spots
        next_captures = find_king_landing_spots(board, from_pos, captured_pos, {x + dx, y + dy}, dx, dy)
        [current_capture | next_captures]
    end
  end

  # Helper functions

  defp is_valid_position?({x, y}) do
    x >= 1 && x <= @board_size && y >= 1 && y <= @board_size
  end

  defp is_empty?(board, pos) do
    not Map.has_key?(board, pos)
  end

  defp get_piece_at(board, pos) do
    Map.get(board, pos)
  end

  @doc """
  Saves the current game state and returns the game ID.
  """
  def save(game) do
    case GamePersistence.save_game(game) do
      {:ok, game_id} -> {:ok, %{game | id: game_id, saved: true}}
      error -> error
    end
  end

  @doc """
  Loads a saved game by its ID.
  """
  def load(game_id) do
    GamePersistence.load_game(game_id)
  end
end
