defmodule LiveCheckersWeb.BoardComponent do
  use LiveCheckersWeb, :html

  attr :board, :map, required: true
  attr :selected, :any, default: nil

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
            class={square_classes(row, col, @selected)}
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

  defp square_classes(row, col, selected) do
    base =
      if rem(row + col, 2) == 0 do
        "w-8 h-8 flex items-center justify-center bg-gray-200"
      else
        "w-8 h-8 flex items-center justify-center bg-gray-700 text-white"
      end

    if selected == {row, col} do
      base <> " border-2 border-yellow-400"
    else
      base
    end
  end
end
