defmodule LiveCheckersWeb.LobbyListComponent do
  use LiveCheckersWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="max-w-lg mx-auto bg-white p-6 rounded-lg shadow-md">
      <div class="flex justify-between items-center mb-4">
        <h2 class="text-xl font-bold">Welcome, <%= @username %></h2>
      </div>

      <div class="mb-6">
        <h3 class="text-lg font-semibold mb-2">Create New Lobby</h3>
        <form phx-submit="create-lobby" phx-target={@myself} class="flex space-x-2">
          <input
            type="text"
            name="name"
            value={@new_lobby_name}
            phx-change="update-lobby-name"
            phx-target={@myself}
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
                  <p class="text-xs text-gray-400">
                    Players: <%= Enum.count(lobby.players) %>/2
                    <%= if Enum.count(lobby.players) >= 2 do %>
                      <span class="text-red-500 font-bold ml-2">FULL</span>
                    <% end %>
                  </p>
                </div>
                <div>
                  <%= if Enum.count(lobby.players) >= 2 do %>
                    <button
                      class="bg-gray-400 text-white text-sm font-bold py-1 px-3 rounded cursor-not-allowed"
                      disabled
                    >
                      Full
                    </button>
                  <% else %>
                    <button
                      phx-click="join-lobby"
                      phx-value-id={lobby.id}
                      phx-target={@myself}
                      class="bg-green-500 hover:bg-green-700 text-white text-sm font-bold py-1 px-3 rounded focus:outline-none focus:shadow-outline"
                    >
                      Join
                    </button>
                  <% end %>

                  <%= if lobby.creator == @username do %>
                    <button
                      phx-click="delete-lobby"
                      phx-value-id={lobby.id}
                      phx-target={@myself}
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
    """
  end

  def handle_event("update-lobby-name", %{"name" => name}, socket) do
    send(self(), {:update_lobby_name, name})
    {:noreply, socket}
  end

  def handle_event("create-lobby", %{"name" => name}, socket) do
    send(self(), {:create_lobby, name})
    {:noreply, socket}
  end

  def handle_event("join-lobby", %{"id" => lobby_id}, socket) do
    send(self(), {:join_lobby, lobby_id})
    {:noreply, socket}
  end

  def handle_event("delete-lobby", %{"id" => lobby_id}, socket) do
    send(self(), {:delete_lobby, lobby_id})
    {:noreply, socket}
  end
end
