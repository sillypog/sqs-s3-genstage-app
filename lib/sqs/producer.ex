defmodule SQS.Producer do
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
