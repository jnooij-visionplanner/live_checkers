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
        <p class="text-gray-500 mb-2">Waiting for opponent...</p>
        <!-- Game will be implemented here later -->
      </div>
    </div>
    """
  end

  def handle_event("back-to-lobbies", _, socket) do
    send(self(), :back_to_lobbies)
    {:noreply, socket}
  end
end
