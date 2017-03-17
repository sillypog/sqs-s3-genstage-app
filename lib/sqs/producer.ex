defmodule SQS.Producer do
  use GenStage

  ##########
  # Client API
  ##########
  def start_link do
    GenStage.start_link(__MODULE__, 0, name: __MODULE__)
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

    # Make a call to the server for the required number of events,
    # accounting for previously unsatisfied demand
    new_demand = demand + state

    {count, events} = take(new_demand)

    # Events will always be returned from this server,
    # but if `events` was empty, state will be updated to the new demand level
    {:noreply, events, new_demand - count}
  end

  defp take(demand) do
    # Return a list no longer than the demand value
    IO.puts "Asking for #{demand} events"

    {count, events} = SQS.Server.pull(demand)

    IO.puts "Received #{count} events"
    {count, events}
  end
end
