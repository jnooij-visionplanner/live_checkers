defmodule LiveCheckersWeb.GameBoardComponent do
  use LiveCheckersWeb, :live_component

  alias LiveCheckers.Game.GameCoordinator
  alias LiveCheckers.Game.Models.Game

  def update(assigns, socket) do
    {:ok,
      socket
      |> assign(assigns)
      |> assign(:selected_piece, nil)
      |> assign(:valid_moves, [])
      |> assign(:error_message, nil)
    }
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4">
      <div class="flex justify-between items-center mb-4">
        <div class="flex-1">
          <h2 class="text-xl font-bold">
            <%= if @game.status == :finished do %>
              Game Over - <%= @game.winner %> wins!
            <% else %>
              Current Player: <%= Enum.at(@game.players, @game.current_player_index).username %>
            <% end %>
          </h2>
        </div>
        <div class="flex gap-4">
          <button
            phx-click="save-game"
            phx-target={@myself}
            class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
          >
            Save Game
          </button>
          <form phx-submit="load-game" phx-target={@myself} class="flex gap-2">
            <input
              type="text"
              name="game_id"
              placeholder="Enter Game ID"
              class="px-3 py-2 border rounded"
            />
            <button
              type="submit"
              class="bg-green-500 hover:bg-green-700 text-white font-bold py-2 px-4 rounded"
            >
              Load Game
            </button>
          </form>
        </div>
      </div>

      <%= if @error_message do %>
        <div class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
          <%= @error_message %>
        </div>
      <% end %>

      <%= if @game.saved do %>
        <div class="bg-green-100 border border-green-400 text-green-700 px-4 py-3 rounded mb-4">
          Game saved! ID: <%= @game.id %>
        </div>
      <% end %>

      <div class="w-full max-w-2xl mx-auto">
        <div class="mb-4 flex justify-between items-center">
          <div>
            <h2 class="text-xl font-bold">Game #<%= @game.id %></h2>
            <p class="text-sm text-gray-600">
              <%= player_name(@game, 0) %> (White) vs. <%= player_name(@game, 1) %> (Black)
            </p>
          </div>
          <div>
            <p class={"text-md font-semibold #{current_player_class(@game)}"}>
              Current Turn: <%= current_player_name(@game) %>
            </p>
          </div>
        </div>

        <div class="board-container relative w-full pb-[100%]">
          <div class="absolute inset-0 grid grid-cols-10 grid-rows-10 border-2 border-gray-800 select-none">
            <%= for y <- 1..10, x <- 1..10 do %>
              <div
                phx-click="square-click"
                phx-value-x={x}
                phx-value-y={y}
                phx-target={@myself}
                class={cell_class(x, y, @selected_piece, @valid_moves)}
              >
                <%= render_piece(@game.board, {x, y}, @selected_piece) %>
              </div>
            <% end %>
          </div>
        </div>

        <%= if @game.status == :finished do %>
          <div class="mt-4 p-4 bg-yellow-100 border border-yellow-400 rounded-md text-center">
            <p class="text-lg font-bold">Game Over!</p>
            <p class="text-md"><%= @game.winner %> has won the game!</p>
            <button
              phx-click="return-to-lobby"
              phx-target={@myself}
              class="mt-2 bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
            >
              Return to Lobby
            </button>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def handle_event("square-click", %{"x" => x_str, "y" => y_str}, socket) do
    x = String.to_integer(x_str)
    y = String.to_integer(y_str)
    position = {x, y}
    game = socket.assigns.game
    username = socket.assigns.username

    # Find player index
    player_index = Enum.find_index(game.players, fn player -> player.username == username end)

    # Only allow moves if it's the player's turn
    if player_index == game.current_player_index do
      piece = Map.get(game.board, position)

      cond do
        # Player clicked on their own piece - select it and show valid moves
        piece && piece.player == player_index && socket.assigns.selected_piece != position ->
          valid_moves = Enum.filter(game.available_moves, fn {from, _, _} -> from == position end)
          {:noreply, assign(socket, selected_piece: position, valid_moves: valid_moves)}

        # Player clicked on the same piece again - deselect
        socket.assigns.selected_piece == position ->
          {:noreply, assign(socket, selected_piece: nil, valid_moves: [])}

        # Player clicked on a valid move destination
        socket.assigns.selected_piece && Enum.any?(socket.assigns.valid_moves, fn {_, to, _} -> to == position end) ->
          # Make the move
          from_pos = socket.assigns.selected_piece
          GameCoordinator.make_move(game.id, username, from_pos, position)
          {:noreply, assign(socket, selected_piece: nil, valid_moves: [])}

        # Invalid selection or move
        true ->
          {:noreply, assign(socket, selected_piece: nil, valid_moves: [])}
      end
    else
      # Not player's turn
      {:noreply, socket}
    end
  end

  def handle_event("return-to-lobby", _, socket) do
    send(self(), :back_to_lobbies)
    {:noreply, socket}
  end

  def handle_event("save-game", _params, socket) do
    case Game.save(socket.assigns.game) do
      {:ok, updated_game} ->
        {:noreply, assign(socket, game: updated_game, error_message: nil)}
      {:error, reason} ->
        {:noreply, assign(socket, error_message: "Failed to save game: #{reason}")}
    end
  end

  def handle_event("load-game", %{"game_id" => game_id}, socket) do
    case Game.load(game_id) do
      {:ok, loaded_game} ->
        # Notify the parent LiveView that we've loaded a game
        send(self(), {:game_loaded, loaded_game})
        {:noreply, assign(socket, error_message: nil)}
      {:error, :not_found} ->
        {:noreply, assign(socket, error_message: "Game not found with ID: #{game_id}")}
      {:error, reason} ->
        {:noreply, assign(socket, error_message: "Failed to load game: #{reason}")}
    end
  end

  # Helper functions

  defp cell_class(x, y, selected_piece, valid_moves) do
    base_class = if rem(x + y, 2) == 0, do: "bg-amber-200", else: "bg-amber-800"

    # Add highlight for selected piece
    selected_class = if selected_piece == {x, y}, do: " ring-2 ring-blue-500 ring-inset", else: ""

    # Add highlight for valid move targets
    move_class = if Enum.any?(valid_moves, fn {_, to, _} -> to == {x, y} end) do
      " bg-green-500 bg-opacity-50"
    else
      ""
    end

    "#{base_class}#{selected_class}#{move_class} w-full h-full flex items-center justify-center"
  end

  defp render_piece(board, pos, _selected_pos) do
    case Map.get(board, pos) do
      %{type: :regular, player: 0} ->
        Phoenix.HTML.raw("""
        <div class="w-4/5 h-4/5 rounded-full bg-white border-2 border-gray-300 shadow-md"></div>
        """)

      %{type: :regular, player: 1} ->
        Phoenix.HTML.raw("""
        <div class="w-4/5 h-4/5 rounded-full bg-black border-2 border-gray-700 shadow-md"></div>
        """)

      %{type: :king, player: 0} ->
        Phoenix.HTML.raw("""
        <div class="w-4/5 h-4/5 rounded-full bg-white border-2 border-gray-300 shadow-md flex items-center justify-center">
          <div class="text-amber-800 text-xl font-bold">K</div>
        </div>
        """)

      %{type: :king, player: 1} ->
        Phoenix.HTML.raw("""
        <div class="w-4/5 h-4/5 rounded-full bg-black border-2 border-gray-700 shadow-md flex items-center justify-center">
          <div class="text-white text-xl font-bold">K</div>
        </div>
        """)

      _ -> nil # Return nil for empty squares
    end
  end

  defp player_name(game, index) do
    Enum.at(game.players, index).username
  end

  defp current_player_name(game) do
    player_name(game, game.current_player_index)
  end

  defp current_player_class(game) do
    if game.current_player_index == 0, do: "text-amber-800", else: "text-black"
  end
end
