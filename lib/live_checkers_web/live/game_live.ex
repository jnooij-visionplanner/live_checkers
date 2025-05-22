defmodule LiveCheckersWeb.GameLive do
  use LiveCheckersWeb, :live_view

  alias LiveCheckers.Game.CheckersGame
  alias LiveCheckers.Game.Rules
  alias LiveCheckersWeb.{BoardComponent, Presence}

  @impl true
  def mount(%{"id" => game_id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(LiveCheckers.PubSub, "game:" <> game_id)
      Presence.track(self(), "game:" <> game_id, socket.id, %{})
    end

    state = CheckersGame.current_state(game_id)
    watchers = Presence.list("game:" <> game_id) |> map_size()

    {:ok,
     assign(socket,
       game_id: game_id,
       state: state,
       selected: nil,
       valid_moves: [],
       capture_paths: [],
       watchers: watchers
     )}
  end

  @impl true
  def handle_info({:state_changed, state}, socket) do
    {:noreply, assign(socket, state: state)}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    watchers = Presence.list("game:" <> socket.assigns.game_id) |> map_size()
    {:noreply, assign(socket, watchers: watchers)}
  end

  @impl true
  def handle_event("square_click", %{"row" => row, "col" => col}, socket) do
    pos = {String.to_integer(row), String.to_integer(col)}

    case socket.assigns.selected do
      nil ->
        moves =
          case Map.get(socket.assigns.state.board, pos) do
            {color, _} ->
              Rules.legal_moves(socket.assigns.state.board, color)
              |> Enum.filter(fn {from, _} -> from == pos end)
            _ ->
              []
          end

        valid = Enum.map(moves, fn {_f, to} -> to end)
        capture_paths =
          Enum.filter(moves, fn {from, to} -> abs(elem(from, 0) - elem(to, 0)) == 2 end)
          |> Enum.map(fn {from, to} -> {div(elem(from, 0) + elem(to, 0), 2), div(elem(from, 1) + elem(to, 1), 2)} end)
        {:noreply,
         assign(socket,
           selected: pos,
           valid_moves: valid,
           capture_paths: capture_paths
         )}

      from ->
        CheckersGame.apply_move(socket.assigns.game_id, {from, pos})
        {:noreply,
         assign(socket,
           selected: nil,
           valid_moves: [],
           capture_paths: []
         )}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto p-4">
      <h1 class="text-xl font-bold mb-4">Game <%= @game_id %></h1>
      <div class="mb-2 text-sm text-gray-600">Spectators: <%= @watchers %></div>
      <BoardComponent.board
        board={@state.board}
        selected={@selected}
        valid_moves={@valid_moves}
        capture_paths={@capture_paths}
      />
      <%= if @state.status == :game_over do %>
        <div class="mt-4 p-4 bg-green-100 border border-green-400 rounded">
          <%= if @state.winner do %>
            Winner: <%= @state.winner %>
          <% else %>
            Draw!
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
end

