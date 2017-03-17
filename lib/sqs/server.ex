defmodule SQS.Server do
  use GenServer

  ##########
  # Client API
  ##########
  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def pull(count) do
    GenServer.call(SQS.Server, {:pull, count})
  end

  ##########
  # Server callbacks
  ##########
  def init(:ok) do
    {:ok, 0}
  end

  def handle_call({:pull, count}, _from, runs) do
    IO.puts "Pulling #{count} events from server"
    events = List.duplicate("ho", count)
    {:reply, {length(events), events}, runs + 1}
  end
end
