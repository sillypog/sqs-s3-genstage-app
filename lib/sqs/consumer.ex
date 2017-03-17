defmodule SQS.Consumer do
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

    event_string = Enum.join(events, ", ")
    IO.puts "Consumed by #{inspect(self())}: #{event_string}"

    {:noreply, [], state}
  end
end
