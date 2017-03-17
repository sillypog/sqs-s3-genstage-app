defmodule SQS.Server do
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
    terminate_servers(children)

    {:ok, pid} = Task.Supervisor.start_child(SQS.Server.TaskSupervisor, fn -> loop(count, 0) end)
    IO.puts "Started new server loop with pid #{inspect(pid)}"
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

  ##########
  # Private functions
  ##########
  defp loop(count, runs) do
    IO.puts "Server #{inspect(self())} looping: Run #{runs}. Looking for #{count} events"

    # Simulate the scenario where we don't have enough supply immediately
    events = if runs < 5  do
      []
    else
      List.duplicate("hey", 2)
    end

    if length(events) > 0 do
      SQS.Producer.enqueue({length(events), events})
      # If the original demand hasn't been satisfied, keep looping
    end

    if length(events) == count do
      Process.exit(self(), :normal)
    else
      # Wait for more messages to arrive, then check again
      :timer.sleep(5000)
      loop(count - length(events), runs + 1)
    end
  end

  defp terminate_servers([]) do
    IO.puts "All servers terminated"
    :ok
  end
  defp terminate_servers([h|t]) do
    IO.puts "Terminating server with pid #{inspect(h)}"
    Process.exit(h, :kill)
    terminate_servers(t)
  end
end
