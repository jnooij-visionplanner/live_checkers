defmodule LiveCheckersWeb.Presence do
  use Phoenix.Presence,
    otp_app: :live_checkers,
    pubsub_server: LiveCheckers.PubSub
end
