defmodule LiveCheckersWeb.LobbyDetailComponent do
  use LiveCheckersWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="max-w-lg mx-auto bg-white p-6 rounded-lg shadow-md">
      <div class="flex justify-between items-center mb-4">
        <h2 class="text-xl font-bold"><%= @lobby.name %></h2>
        <button
          phx-click="back-to-lobbies"
          phx-target={@myself}
          class="bg-gray-300 hover:bg-gray-400 text-black font-bold py-1 px-3 rounded text-sm"
        >
          Back to Lobby List
        </button>
      </div>

      <div class="mb-4">
        <h3 class="text-lg font-semibold mb-2">Players</h3>
        <ul class="list-disc pl-5">
          <%= for player <- @lobby.players do %>
            <li class={if player == @username, do: "font-bold", else: ""}>
              <%= player %> <%= if player == @lobby.creator, do: "(Creator)" %>
            </li>
          <% end %>
        </ul>
      </div>

      <div class="text-center">
        <%= if length(@lobby.players) < 2 do %>
          <p class="text-gray-500 mb-2">Waiting for opponent...</p>
        <% else %>
          <p class="text-green-500 font-bold mb-4">Game ready to start!</p>
          <%= if @lobby.creator == @username do %>
            <button
              phx-click="start_game"
              phx-target={@myself}
              class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded focus:outline-none focus:shadow-outline"
            >
              Start Game
            </button>
          <% else %>
            <p class="text-gray-500">Waiting for creator to start the game...</p>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  def handle_event("back-to-lobbies", _, socket) do
    send(self(), :back_to_lobbies)
    {:noreply, socket}
  end

  def handle_event("start_game", _, socket) do
    send(self(), {:start_game, socket.assigns.lobby.id})
    {:noreply, socket}
  end
end
