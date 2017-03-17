defmodule SQS.Server do
  @moduledoc """
  The server is now pulling real events from SQS instead of simulating them.
  ExAws is used to make requests to SQS. SweetXML is used to extract the
  message body, which is an event from S3. Those events are json encoded,
  so Poison is used to extract the bucket and object information from the
  S3 event.

  The nature of the loop, and the interactions with the producer have not
  changed much. One important difference is that the demand from the producer
  is being limited, as the SQS API only allows us to retrieve up to 10
  messages at a time. If the producer requests more than this, a loop will
  be started to retrieve 10 messages. The producer doesn't need to know
  about this limitation because it keeps track of all demand independently.
  """
  use Supervisor

  import SweetXml

  ##########
  # Client API
  ##########
  def start_link do
    IO.puts "Attempting to start SQS.Server"
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def pull(count) do
    # Limit the count as SQS can only support a maximum of 10 events
    limited_count = min(10, count)

    # Cancel any running loops
    children = Task.Supervisor.children(SQS.Server.TaskSupervisor)
    IO.puts "There are currently #{length(children)} servers looping"
    terminate_servers(children)

    # Start a new loop
    {:ok, pid} = Task.Supervisor.start_child(SQS.Server.TaskSupervisor, fn -> loop(limited_count, 0) end)
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

    {_status, response} = ExAws.SQS.receive_message("warehouse_raw_events", [wait_time_seconds: 2, max_number_of_messages: count])
    |> ExAws.request

    events = Map.get(response, :body)
    |> xpath(~x"//Body/text()"s)
    |> Poison.Parser.parse
    |> get_paths

    if length(events) > 0 do
      SQS.Producer.enqueue({length(events), events})
    end

    if length(events) == count do
      Process.exit(self(), :normal)
    else
      :timer.sleep(5000)
      loop(count - length(events), runs + 1)
    end
  end

  defp get_paths({:error, _}) do
    []
  end
  defp get_paths({:ok, json}) do
    Map.get(json, "Records")
    |> Enum.map(fn(record) ->
      s3 = Map.get(record, "s3")
      bucket = s3
      |> Map.get("bucket")
      |> Map.get("name")
      key = s3
      |> Map.get("object")
      |> Map.get("key")
      {bucket, key}
    end)
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
