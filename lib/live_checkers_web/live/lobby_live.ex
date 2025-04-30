defmodule LiveCheckersWeb.LobbyLive do
  use LiveCheckersWeb, :live_view
  alias LiveCheckers.Game.LobbyManager

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
       error_message: nil
     )}
  end

  def handle_event("set-username", %{"username" => username}, socket) when username != "" do
    if LobbyManager.player_exists?(username) do
      {:noreply, assign(socket, error_message: "Username already taken")}
    else
      {:noreply, assign(socket, username: username, page: :lobby_list, error_message: nil)}
    end
  end

  def handle_event("set-username", _, socket) do
    {:noreply, assign(socket, error_message: "Username cannot be empty")}
  end

  def handle_event("create-lobby", %{"name" => name}, socket) when name != "" do
    username = socket.assigns.username

    case LobbyManager.create_lobby(name, username) do
      {:ok, lobby} ->
        broadcast_lobby_update()
        {:noreply, assign(socket, page: :lobby, current_lobby: lobby, error_message: nil)}

      {:error, reason} ->
        {:noreply, assign(socket, error_message: "Error creating lobby: #{reason}")}
    end
  end

  def handle_event("create-lobby", _, socket) do
    {:noreply, assign(socket, error_message: "Lobby name cannot be empty")}
  end

  def handle_event("join-lobby", %{"id" => lobby_id}, socket) do
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

      {:error, reason} ->
        {:noreply, assign(socket, error_message: "Error joining lobby: #{reason}")}
    end
  end

  def handle_event("delete-lobby", %{"id" => lobby_id}, socket) do
    case LobbyManager.delete_lobby(lobby_id) do
      {:ok, _lobby} ->
        # Success case - broadcast the update and go back to lobby list
        broadcast_lobby_update()
        {:noreply, assign(socket,
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

  def handle_event("back-to-lobbies", _, socket) do
  if socket.assigns.page == :lobby and socket.assigns.current_lobby do
    # Get current lobby and username
    lobby_id = socket.assigns.current_lobby.id
    username = socket.assigns.username

    # Leave the lobby
    case LobbyManager.leave_lobby(lobby_id, username) do
      {:ok, :lobby_deleted} ->
        # Lobby was deleted because this was the last player
        broadcast_lobby_update()
        {:noreply, assign(socket,
          page: :lobby_list,
          lobbies: LobbyManager.get_lobbies(),
          current_lobby: nil
        )}

      {:ok, _updated_lobby} ->
        # Player was removed, lobby still exists
        broadcast_lobby_update()
        {:noreply, assign(socket,
          page: :lobby_list,
          lobbies: LobbyManager.get_lobbies(),
          current_lobby: nil
        )}

      {:error, _reason} ->
        # Error occurred, still go back to lobby list
        {:noreply, assign(socket,
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

  def handle_event("update-lobby-name", %{"name" => name}, socket) do
    {:noreply, assign(socket, new_lobby_name: name)}
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
          nil ->
            # Lobby no longer exists, go back to list
            assign(socket, page: :lobby_list)
          updated_lobby ->
            assign(socket, current_lobby: updated_lobby)
        end
      else
        socket
      end

    {:noreply, assign(socket, lobbies: updated_lobbies)}
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
          <div class="max-w-md mx-auto bg-white p-6 rounded-lg shadow-md">
            <h2 class="text-xl font-bold mb-4">Enter Username</h2>
            <form phx-submit="set-username">
              <div class="mb-4">
                <label class="block text-gray-700 text-sm font-bold mb-2">Username</label>
                <input
                  type="text"
                  name="username"
                  class="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline"
                  placeholder="Enter your username"
                  autofocus
                />
              </div>
              <div class="flex items-center justify-center">
                <button
                  type="submit"
                  class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded focus:outline-none focus:shadow-outline"
                >
                  Continue
                </button>
              </div>
            </form>
          </div>

        <% :lobby_list -> %>
          <div class="max-w-lg mx-auto bg-white p-6 rounded-lg shadow-md">
            <div class="flex justify-between items-center mb-4">
              <h2 class="text-xl font-bold">Welcome, <%= @username %></h2>
            </div>

            <div class="mb-6">
              <h3 class="text-lg font-semibold mb-2">Create New Lobby</h3>
              <form phx-submit="create-lobby" class="flex space-x-2">
                <input
                  type="text"
                  name="name"
                  value={@new_lobby_name}
                  phx-change="update-lobby-name"
                  class="shadow appearance-none border rounded flex-grow py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline"
                  placeholder="Lobby name"
                />
                <button
                  type="submit"
                  class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded focus:outline-none focus:shadow-outline"
                >
                  Create
                </button>
              </form>
            </div>

            <div>
              <h3 class="text-lg font-semibold mb-2">Available Lobbies</h3>
              <%= if Enum.empty?(@lobbies) do %>
                <p class="text-gray-500">No lobbies available. Create one!</p>
              <% else %>
                <div class="space-y-2">
                  <%= for lobby <- @lobbies do %>
                    <div class="border p-3 rounded flex justify-between items-center">
                      <div>
                        <p class="font-medium"><%= lobby.name %></p>
                        <p class="text-sm text-gray-500">Created by: <%= lobby.creator %></p>
                        <p class="text-xs text-gray-400">Players: <%= Enum.count(lobby.players) %></p>
                      </div>
                      <div>

                      <button
                        phx-click="join-lobby"
                        phx-value-id={lobby.id}
                        class="bg-green-500 hover:bg-green-700 text-white text-sm font-bold py-1 px-3 rounded focus:outline-none focus:shadow-outline"
                      >
                        Join
                      </button>
                      <%= if lobby.creator == @username do %>
                        <button
                          phx-click="delete-lobby"
                          phx-value-id={lobby.id}
                          class="bg-red-500 hover:bg-red-700 text-white text-sm font-bold py-1 px-3 rounded focus:outline-none focus:shadow-outline ml-2"
                        >
                          Delete
                        </button>
                      <% end %>
                      </div>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>

        <% :lobby -> %>
          <div class="max-w-lg mx-auto bg-white p-6 rounded-lg shadow-md">
            <div class="flex justify-between items-center mb-4">
              <h2 class="text-xl font-bold"><%= @current_lobby.name %></h2>
              <button
                phx-click="back-to-lobbies"
                class="bg-gray-300 hover:bg-gray-400 text-black font-bold py-1 px-3 rounded text-sm"
              >
                Back to Lobby List
              </button>
            </div>

            <div class="mb-4">
              <h3 class="text-lg font-semibold mb-2">Players</h3>
              <ul class="list-disc pl-5">
                <%= for player <- @current_lobby.players do %>
                  <li class={if player == @username, do: "font-bold", else: ""}>
                    <%= player %> <%= if player == @current_lobby.creator, do: "(Creator)" %>
                  </li>
                <% end %>
              </ul>
            </div>

            <div class="text-center">
              <p class="text-gray-500 mb-2">Waiting for opponent...</p>
              <!-- Game will be implemented here later -->
            </div>
          </div>
      <% end %>
    </div>
    """
  end
end
