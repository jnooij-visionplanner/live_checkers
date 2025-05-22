defmodule LiveCheckersWeb.BoardComponent do
  use LiveCheckersWeb, :html

  attr :board, :map, required: true
  attr :selected, :any, default: nil
  attr :valid_moves, :list, default: []
  attr :capture_paths, :list, default: []

  def board(assigns) do
    ~H"""
    <div class="grid grid-cols-10 gap-0">
      <%= for row <- 0..9 do %>
        <%= for col <- 0..9 do %>
          <% piece = Map.get(@board, {row, col}) %>
          <div
            id={"square-#{row}-#{col}"}
            phx-click="square_click"
            phx-value-row={row}
            phx-value-col={col}
            class={square_classes(row, col, @selected, @valid_moves, @capture_paths)}
          >
            <%= case piece do %>
              <% nil -> %>

              <% {:black, :man} -> %>
                <span class="text-black">●</span>
              <% {:red, :man} -> %>
                <span class="text-red-600">●</span>
              <% {:black, :king} -> %>
                <span class="font-bold text-black">K</span>
              <% {:red, :king} -> %>
                <span class="font-bold text-red-600">K</span>
            <% end %>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp square_classes(row, col, selected, valid_moves, capture_paths) do
    base =
      if rem(row + col, 2) == 0 do
        "w-8 h-8 flex items-center justify-center bg-gray-200"
      else
        "w-8 h-8 flex items-center justify-center bg-gray-700 text-white"
      end

    move_highlight = if {row, col} in valid_moves, do: " border-2 border-green-400", else: ""
    capture_highlight = if {row, col} in capture_paths, do: " bg-red-500", else: ""
    selected_highlight = if selected == {row, col}, do: " border-2 border-yellow-400", else: ""

    base <> move_highlight <> capture_highlight <> selected_highlight
  end
end
