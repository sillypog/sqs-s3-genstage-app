defmodule SQS.Server do
  @moduledoc """
  When new events are found in the loop, the server sends these
  to the producer using the producer's client API.
  """
  use Supervisor

  ##########
  # Client API
  ##########
  def start_link do
    IO.puts "Attempting to start SQS.Server"
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def pull(count) do
    # Cancel any running loops
    children = Task.Supervisor.children(SQS.Server.TaskSupervisor)
    IO.puts "There are currently #{length(children)} servers looping"
    # Start a new loop
    {:ok, pid} = Task.Supervisor.start_child(SQS.Server.TaskSupervisor, fn -> loop(count, 0) end)
    IO.puts "Started new server loop with pid #{inspect(pid)}"
    # Return something empty to caller
    {0, []}
  end

  ##########
  # Server callbacks
  ##########
  def init(:ok) do
    IO.puts "Initializing SQS.Server supervision tree"
    children = [
      supervisor(Task.Supervisor, [[name: SQS.Server.TaskSupervisor]])
    ]

    opts = [strategy: :one_for_one, name: SQSServerSupervisor]
    supervise(children, opts)
  end

  defp loop(count, runs) do
    IO.puts "Server looping: Run #{runs}. Looking for #{count} events"
    events = List.duplicate("hey", count)

    if length(events) > 0 do
      # Use the producer's API to send events
      SQS.Producer.enqueue({length(events), events})
      Process.exit(self(), :normal)
    else
      :timer.sleep(1000)
      loop(count, runs + 1)
    end
  end

end
