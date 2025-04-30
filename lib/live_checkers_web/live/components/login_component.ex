defmodule LiveCheckersWeb.LoginComponent do
  use LiveCheckersWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="max-w-md mx-auto bg-white p-6 rounded-lg shadow-md">
      <h2 class="text-xl font-bold mb-4">Enter Username</h2>
      <form phx-submit="set-username" phx-target={@myself}>
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
    """
  end

  def handle_event("set-username", %{"username" => username}, socket) when username != "" do
    send(self(), {:set_username, username})
    {:noreply, socket}
  end

  def handle_event("set-username", _, socket) do
    send(self(), {:username_error, "Username cannot be empty"})
    {:noreply, socket}
  end
end
