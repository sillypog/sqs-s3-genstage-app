defmodule SQS.Consumer do
  @moduledoc """
  The consumer is now informing the server that messages have
  been processed. The consumer doesn't need to know how this
  works, it just passes the original message back to the server.
  The message contains all the information necessary to remove
  the SQS message from the queue.

  The display_events function has changed because the event is
  now a map in order to contain the extra information needed
  to delete the SQS message.
  """

  use GenStage

  ##########
  # Client API
  ##########
  def start_link do
    GenStage.start_link(__MODULE__, :ok)
  end


  ##########
  # Server callbacks
  ##########

  def init(:ok) do
    {:consumer, :ok, subscribe_to: [{SQS.Producer, min_demand: 0, max_demand: 10}]}
  end

  def handle_events(events, _from, state) do
    :timer.sleep(1000)

    display_events(events)

    # Remove the event from the queue
    SQS.Server.release(events)

    {:noreply, [], state}
  end

  ########
  # Private functions
  ########
  defp display_events(events) do
    event_string = events
    |> Enum.map(fn(%{bucket: bucket, key: key}) -> "#{bucket}/#{key}" end)
    |> Enum.join(", ")
    IO.puts "Consumed by #{inspect(self())}: #{event_string}"
  end
end
