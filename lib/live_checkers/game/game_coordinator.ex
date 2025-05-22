defmodule LiveCheckers.Game.GameCoordinator do
  @moduledoc """
  Coordinates game creation and interactions.
  """

  alias LiveCheckers.Game.Models.Game
  alias LiveCheckers.Game.LobbyManager

  require Logger

  def start_game(lobby_id) do
    with {:ok, lobby} <- LobbyManager.get_lobby(lobby_id),
         true <- length(lobby.players) == 2 do

      # Create new game using the Game module
      game = Game.new(lobby_id, lobby.players)

      # Update the lobby with the game state
      LobbyManager.update_lobby_game(lobby_id, game)

      # Broadcast game start to all players
      Phoenix.PubSub.broadcast(
        LiveCheckers.PubSub,
        "game:#{lobby_id}",
        {:game_started, game}
      )

      {:ok, game}
    else
      {:error, reason} ->
        {:error, reason}
      false ->
        {:error, :not_enough_players}
    end
  end

  def make_move(game_id, player, from_pos, to_pos) do
    with {:ok, lobby} <- LobbyManager.get_lobby(game_id),
         %{game_state: game} when not is_nil(game) <- lobby,
         player_index <- find_player_index(game, player) do

      case Game.make_move(game, player_index, from_pos, to_pos) do
        {:ok, result, updated_game} ->
          # Update the game state in the lobby
          LobbyManager.update_lobby_game(game_id, updated_game)

          # Broadcast the move to all players
          Phoenix.PubSub.broadcast(
            LiveCheckers.PubSub,
            "game:#{game_id}",
            {:move_made, player, from_pos, to_pos, result, updated_game}
          )

          # Handle game over scenario
          if result == :game_over do
            Phoenix.PubSub.broadcast(
              LiveCheckers.PubSub,
              "game:#{game_id}",
              {:game_over, updated_game.winner, updated_game}
            )
          end

          {:ok, result, updated_game}

          {:error, reason} ->
            {:error, reason}
      end
    else
      {:error, reason} -> {:error, reason} # Handle LobbyManager.get_lobby failure
      %{game_state: nil} -> {:error, :game_not_started} # Handle game not started in lobby
      nil -> {:error, :player_not_in_game} # Handle player not found by find_player_index
    end
  end

  defp find_player_index(game, username) do
    Enum.find_index(game.players, fn player -> player.username == username end)
  end
end
