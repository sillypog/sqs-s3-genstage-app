defmodule SQS.Server do
  use Supervisor
  @moduledoc """
  In order to support asynchronous fetching of events,
  pull/1 no longer makes a synchronous Genserver.call.
  Instead, a supervised Task is launched to keep looking
  for events until demand is satisfied.

  Requests for further demand will cause the existing
  loop to be terminated, and a new loop to be started
  to satisfy this and any existing unsatisfied demand.
  """

  ##########
  # Client API
  ##########
  def start_link do
    IO.puts "Attempting to start SQS.Server"
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def pull(count) do
    # GenServer.call(SQS.Server, {:pull, count})

    # Cancel any running loops
    children = Task.Supervisor.children(SQS.Server.TaskSupervisor)
    IO.puts "There are currently #{length(children)} servers looping"
    # Start a new loop
    {:ok, pid} = Task.Supervisor.start_child(SQS.Server.TaskSupervisor, fn -> loop(count, 0) end)
    # Register that pid somewhere?
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

  # def handle_call({:pull, count}, _from, runs) do
  #   IO.puts "Pulling #{count} events from server"
  #   events = List.duplicate("ho", count)
  #   {:reply, {length(events), events}, count + 1}
  # end

  defp loop(count, runs) do
    IO.puts "Server looping: Run #{runs}. Looking for #{count} events"
    events = List.duplicate("hey", count)

    if length(events) > 0 do
      # Send events to producer
      send(SQS.Producer, {:events, {length(events), events}})
      # Exit the process
      Process.exit(self(), :normal)
    else
      :timer.sleep(1000)
      loop(count, runs + 1)
    end
  end

end
