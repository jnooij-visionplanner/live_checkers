defmodule LiveCheckersWeb.LobbyLive do
  use LiveCheckersWeb, :live_view
  alias LiveCheckers.Game.LobbyManager
  alias LiveCheckersWeb.{LoginComponent, LobbyListComponent, LobbyDetailComponent}
  alias LiveCheckersWeb.GameBoardComponent
  alias LiveCheckers.Game.GameCoordinator

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(LiveCheckers.PubSub, "lobbies")
    end

    {:ok,
     assign(socket,
       username: nil,
       lobbies: LobbyManager.get_lobbies(),
       page: :login,
       new_lobby_name: "",
       error_message: nil,
       current_lobby: nil
     )}
  end

  # Handle component messages
  def handle_info({:set_username, username}, socket) do
    if LobbyManager.player_exists?(username) do
      {:noreply, assign(socket, error_message: "Username already taken")}
    else
      {:noreply, assign(socket, username: username, page: :lobby_list, error_message: nil)}
    end
  end

  def handle_info({:username_error, message}, socket) do
    {:noreply, assign(socket, error_message: message)}
  end

  def handle_info({:update_lobby_name, name}, socket) do
    {:noreply, assign(socket, new_lobby_name: name)}
  end

  def handle_info({:create_lobby, name}, socket) when name != "" do
    username = socket.assigns.username

    case LobbyManager.create_lobby(name, username) do
      {:ok, lobby} ->
        broadcast_lobby_update()
        {:noreply, assign(socket, page: :lobby, current_lobby: lobby, error_message: nil)}

      {:error, reason} ->
        {:noreply, assign(socket, error_message: "Error creating lobby: #{reason}")}
    end
  end

  def handle_info({:create_lobby, _}, socket) do
    {:noreply, assign(socket, error_message: "Lobby name cannot be empty")}
  end

  def handle_info({:join_lobby, lobby_id}, socket) do
    username = socket.assigns.username

    case LobbyManager.join_lobby(lobby_id, username) do
      {:ok, lobby} ->
        broadcast_lobby_update()
        {:noreply, assign(socket, page: :lobby, current_lobby: lobby, error_message: nil)}

      {:error, :not_found} ->
        {:noreply, assign(socket, error_message: "Lobby not found")}

      {:error, :already_joined} ->
        # Find the lobby and navigate to it
        lobby = Enum.find(socket.assigns.lobbies, &(&1.id == lobby_id))
        {:noreply, assign(socket, page: :lobby, current_lobby: lobby, error_message: nil)}

      {:error, :lobby_full} ->
        {:noreply, assign(socket, error_message: "This lobby is full (maximum 2 players)")}

      {:error, reason} ->
        {:noreply, assign(socket, error_message: "Error joining lobby: #{reason}")}
    end
  end

  def handle_info({:delete_lobby, lobby_id}, socket) do
    case LobbyManager.delete_lobby(lobby_id) do
      {:ok, _lobby} ->
        broadcast_lobby_update()
        {:noreply,
         assign(socket,
           page: :lobby_list,
           lobbies: LobbyManager.get_lobbies(),
           current_lobby: nil
         )}

      {:error, :not_found} ->
        {:noreply, assign(socket, error_message: "Lobby not found")}

      {:error, reason} ->
        {:noreply, assign(socket, error_message: "Error deleting lobby: #{reason}")}
    end
  end

  def handle_info(:back_to_lobbies, socket) do
    if socket.assigns.page == :lobby and socket.assigns.current_lobby do
      # Get current lobby and username
      lobby_id = socket.assigns.current_lobby.id
      username = socket.assigns.username

      # Leave the lobby
      case LobbyManager.leave_lobby(lobby_id, username) do
        {:ok, :lobby_deleted} ->
          # Lobby was deleted because this was the last player
          broadcast_lobby_update()
          {:noreply,
           assign(socket,
             page: :lobby_list,
             lobbies: LobbyManager.get_lobbies(),
             current_lobby: nil
           )}

        {:ok, _updated_lobby} ->
          # Player was removed, lobby still exists
          broadcast_lobby_update()
          {:noreply,
           assign(socket,
             page: :lobby_list,
             lobbies: LobbyManager.get_lobbies(),
             current_lobby: nil
           )}

        {:error, _reason} ->
          # Error occurred, still go back to lobby list
          {:noreply,
           assign(socket,
             page: :lobby_list,
             lobbies: LobbyManager.get_lobbies(),
             current_lobby: nil
           )}
      end
    else
      # Already on the lobby list or not in a lobby
      {:noreply, assign(socket, page: :lobby_list, lobbies: LobbyManager.get_lobbies())}
    end
  end

  def handle_info({:start_game, lobby_id}, socket) do
    case GameCoordinator.start_game(lobby_id) do
      {:ok, game} ->
        # Subscribe to game-specific events
        Phoenix.PubSub.subscribe(LiveCheckers.PubSub, "game:#{lobby_id}")
        # Broadcast game started event to all players in the lobby
        Phoenix.PubSub.broadcast(LiveCheckers.PubSub, "lobbies", {:game_started, lobby_id, game})
        # Update the current_lobby with the new game state before switching page
        updated_lobby = %{socket.assigns.current_lobby | game_state: game, status: :in_game}
        {:noreply, assign(socket, page: :game, current_lobby: updated_lobby, error_message: nil)}

      {:error, reason} ->
        {:noreply, assign(socket, error_message: "Failed to start game: #{reason}")}
    end
  end

  def handle_info({:game_started, lobby_id, game}, socket) do
    # Only update if we're in the same lobby
    if socket.assigns.current_lobby && socket.assigns.current_lobby.id == lobby_id do
      Phoenix.PubSub.subscribe(LiveCheckers.PubSub, "game:#{lobby_id}")
      updated_lobby = %{socket.assigns.current_lobby | game_state: game, status: :in_game}
      {:noreply, assign(socket, page: :game, current_lobby: updated_lobby)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:game_started, game}, socket) do
    # Ensure the component receives the game state, likely through current_lobby
    updated_lobby = %{socket.assigns.current_lobby | game_state: game}
    {:noreply, assign(socket, page: :game, current_lobby: updated_lobby)}
  end

  def handle_info({:move_made, _player, _from, _to, _result, updated_game}, socket) do
    # Update the game state within the current_lobby
    updated_lobby = %{socket.assigns.current_lobby | game_state: updated_game}
    {:noreply, assign(socket, current_lobby: updated_lobby)}
  end

  def handle_info({:game_over, _winner, updated_game}, socket) do
    # Update the game state within the current_lobby
    updated_lobby = %{socket.assigns.current_lobby | game_state: updated_game}
    {:noreply, assign(socket, current_lobby: updated_lobby)}
  end

  def handle_info(:lobby_updated, socket) do
    # Always update the lobbies list
    updated_lobbies = LobbyManager.get_lobbies()

    # If player is currently in a lobby, update that specific lobby data too
    socket =
      if socket.assigns.page == :lobby do
        # Get the updated version of the current lobby
        current_lobby_id = socket.assigns.current_lobby.id

        case LobbyManager.get_lobby(current_lobby_id) do
          {:ok, updated_lobby} ->
            assign(socket, current_lobby: updated_lobby)

          {:error, :not_found} ->
            # Lobby no longer exists, go back to list
            assign(socket, page: :lobby_list)
        end
      else
        socket
      end

    {:noreply, assign(socket, lobbies: updated_lobbies)}
  end

  def handle_info({:game_loaded, loaded_game}, socket) do
    # Subscribe to game-specific events for the loaded game
    Phoenix.PubSub.subscribe(LiveCheckers.PubSub, "game:#{loaded_game.id}")

    # Update the current lobby with the loaded game state
    {:noreply, assign(socket,
      page: :game,
      current_lobby: %{socket.assigns.current_lobby | game_state: loaded_game},
      error_message: nil
    )}
  end

  defp broadcast_lobby_update do
    Phoenix.PubSub.broadcast(LiveCheckers.PubSub, "lobbies", :lobby_updated)
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto p-4">
      <h1 class="text-3xl font-bold mb-6 text-center">Live Checkers</h1>

      <%= if @error_message do %>
        <div class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
          <%= @error_message %>
        </div>
      <% end %>

      <%= case @page do %>
        <% :login -> %>
          <.live_component module={LoginComponent} id="login" />

        <% :lobby_list -> %>
          <.live_component
            module={LobbyListComponent}
            id="lobby-list"
            username={@username}
            lobbies={@lobbies}
            new_lobby_name={@new_lobby_name}
          />

        <% :lobby -> %>
          <.live_component
            module={LobbyDetailComponent}
            id="lobby-detail"
            username={@username}
            lobby={@current_lobby}
          />

        <% :game -> %>
          <.live_component
            module={GameBoardComponent}
            id="game-board"
            username={@username}
            game={@current_lobby.game_state}
          />
      <% end %>
    </div>
    """
  end
end
