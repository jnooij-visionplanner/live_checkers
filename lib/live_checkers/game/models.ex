defmodule LiveCheckers.Game.Models do
  @moduledoc """
  Domain models for the Live Checkers game.
  """

  defmodule Player do
    @moduledoc """
    Represents a player in the game.
    """

    @type t :: %__MODULE__{
      username: String.t(),
      status: :idle | :in_lobby | :playing
    }

    defstruct [
      :username,
      status: :idle
    ]
  end

  defmodule Lobby do
    @moduledoc """
    Represents a game lobby.
    """

    @type t :: %__MODULE__{
      id: String.t(),
      name: String.t(),
      creator: String.t(),
      players: [String.t()],
      created_at: DateTime.t(),
      status: :waiting | :full | :in_game,
      game_state: map() | nil
    }

    defstruct [
      :id,
      :name,
      :creator,
      players: [],
      created_at: nil,
      status: :waiting,
      game_state: nil
    ]

    @doc """
    Creates a new lobby with the given name and creator.
    """
    def new(id, name, creator) do
      %__MODULE__{
        id: id,
        name: name,
        creator: creator,
        players: [creator],
        created_at: DateTime.utc_now(),
        status: :waiting
      }
    end

    @doc """
    Adds a player to the lobby.
    """
    def add_player(lobby, player) do
      updated_players = [player | lobby.players]
      status = if length(updated_players) >= 2, do: :full, else: :waiting

      %{lobby |
        players: updated_players,
        status: status
      }
    end

    @doc """
    Removes a player from the lobby.
    """
    def remove_player(lobby, player) do
      updated_players = Enum.filter(lobby.players, fn p -> p != player end)

      cond do
        # No players left
        Enum.empty?(updated_players) ->
          {:empty, %{lobby | players: []}}

        # Creator is leaving - assign a new creator
        player == lobby.creator ->
          new_creator = List.first(updated_players)
          {:update_creator, %{lobby |
            players: updated_players,
            creator: new_creator,
            status: :waiting
          }}

        # Regular player leaving
        true ->
          {:ok, %{lobby |
            players: updated_players,
            status: :waiting
          }}
      end
    end

    @doc """
    Checks if the lobby is full.
    """
    def full?(lobby), do: length(lobby.players) >= 2

    @doc """
    Checks if the player is in the lobby.
    """
    def has_player?(lobby, player), do: player in lobby.players
  end
end
