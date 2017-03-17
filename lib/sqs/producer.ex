defmodule SQS.Producer do
  @moduledoc """
  The producer state receives demand from the producer/consumers,
  asking for messages to be read from SQS. In order to not block
  at this step, delaying other stages from sending further demand,
  the producer requests the events from a separate server process.
  The server immediately responds to the producer with no message,
  and begins pollign SQS asynchronously. Once the server receives
  messages from SQS, these events are sent back to the producer via
  the enqueue/1 function, which is also asynchronous, allowing the
  server to keep working. The enqueued event is handled in handle_cast/2,
  which passes the event to the next stage for processing.

  The producer stores demand from the subscribing stages and
  adds this to any previously unmet demand. In the final application,
  each subscriber has a demand of 1, and this is never immediately
  satisfied in handle_demand/2, but the logic has been left in for
  flexibility.
  """
  use GenStage

  ##########
  # Client API
  ##########
  def start_link do
    GenStage.start_link(__MODULE__, 0, name: __MODULE__)
  end

  def enqueue({_count, _events} = message) do
    IO.puts "Casting events to producer"
    GenServer.cast(SQS.Producer, {:events, message})
  end


  ##########
  # Server callbacks
  ##########

  def init(0) do
    IO.puts "Initalised SQS.Producer"
    {:producer, 0}
  end

  def handle_demand(demand, state) when demand > 0 do
    IO.puts "SQS.Producer handling demand of #{demand}"

    new_demand = demand + state

    {count, events} = take(new_demand)

    {:noreply, events, new_demand - count}
  end

  def handle_cast({:events, {count, events}}, state) do
    IO.puts "SQS.Producer got notified about #{count} new events"

    {:noreply, events, state - count}
  end

  defp take(demand) do
    IO.puts "Asking for #{demand} events"

    {count, events} = SQS.Server.pull(demand)

    IO.puts "Received #{count} events"
    {count, events}
  end
end
