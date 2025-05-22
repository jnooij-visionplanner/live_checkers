defmodule LiveCheckersWeb.GameLive do
  use LiveCheckersWeb, :live_view

  alias LiveCheckers.Game.CheckersGame
  alias LiveCheckersWeb.BoardComponent

  @impl true
  def mount(%{"id" => game_id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(LiveCheckers.PubSub, "game:" <> game_id)
    end

    state = CheckersGame.current_state(game_id)

    {:ok, assign(socket, game_id: game_id, state: state, selected: nil)}
  end

  @impl true
  def handle_info({:state_changed, state}, socket) do
    {:noreply, assign(socket, state: state)}
  end

  @impl true
  def handle_event("square_click", %{"row" => row, "col" => col}, socket) do
    pos = {String.to_integer(row), String.to_integer(col)}

    case socket.assigns.selected do
      nil ->
        {:noreply, assign(socket, selected: pos)}

      from ->
        CheckersGame.apply_move(socket.assigns.game_id, {from, pos})
        {:noreply, assign(socket, selected: nil)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto p-4">
      <h1 class="text-xl font-bold mb-4">Game <%= @game_id %></h1>
      <BoardComponent.board board={@state.board} selected={@selected} />
    </div>
    """
  end
end

