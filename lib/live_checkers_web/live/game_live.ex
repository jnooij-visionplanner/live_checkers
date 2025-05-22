defmodule LiveCheckersWeb.GameLive do
  use LiveCheckersWeb, :live_view

  alias LiveCheckers.Game.CheckersGame

  @impl true
  def mount(%{"id" => game_id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(LiveCheckers.PubSub, "game:" <> game_id)
    end

    state = CheckersGame.current_state(game_id)

    {:ok, assign(socket, game_id: game_id, state: state)}
  end

  @impl true
  def handle_info({:state_changed, state}, socket) do
    {:noreply, assign(socket, state: state)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto p-4">
      <h1 class="text-xl font-bold mb-4">Game <%= @game_id %></h1>
      <pre><%= inspect(@state, pretty: true) %></pre>
    </div>
    """
  end
end

