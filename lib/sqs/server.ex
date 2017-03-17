defmodule SQS.Server do
  @moduledoc """
  The server is responsible for managing interactions with SQS,
  and for controlling the lifecycle of SQS messages.

  The producer calls pull/1 to request messages in response to
  demand. This starts a supervised task that makes a call to
  SQS to request messages. pull/1 limits the number of events
  requested to a maximum of 10, as this limit is imposed by SQS.
  When messages are found they are sent back to the producer.
  If this doesn't satisfy the original request, the loop waits
  5 seconds and makes another request. When enough messages are
  found, the task exits. If the producer makes further requests
  for demand while a task is running, the existing task is killed
  and a new task will be started with a request for the new level
  of demand.

  When messages are received they are processed to extract the
  S3 bucket and object key information. These are packaged in a
  map and sent to the stages.

  In addition, the map also contains the message id and request
  handle received from SQS. When the events have been completely
  processed by all stages, the final stage should call release/1
  with the events it received. release/1 will call SQS with the
  message id and request handle to delete the message from the
  queue.
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

  def release([]) do
    :ok
  end
  def release(messages) do
    receipts = Enum.map(messages, fn(message)->
      %{
        receipt_handle: Map.get(message, :receipt_handle),
        id: Map.get(message, :id)
      }
    end)
    ExAws.SQS.delete_message_batch("warehouse_raw_events", receipts)
    |> ExAws.request
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
    |> xpath(~x"//ReceiveMessageResult/Message"l, body: ~x"./Body/text()"s, receipt_handle: ~x"./ReceiptHandle/text()"s, id: ~x"./MessageId/text()"s)
    |> process_messages

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

  defp process_messages([]) do
    []
  end
  defp process_messages(results) do
    Enum.map(results, fn(result) ->
      {bucket, key} = result
      |> Map.get(:body)
      |> Poison.Parser.parse
      |> get_path

      %{bucket: bucket, key: key, receipt_handle: Map.get(result, :receipt_handle), id: Map.get(result, :id)}
    end)
  end

  defp get_path({:error, _}) do
    []
  end
  defp get_path({:ok, json}) do
    s3 = json
    |> Map.get("Records")
    |> List.first         # Assumes each SQS message contains a record for one S3 file
    |> Map.get("s3")

    bucket = s3
    |> Map.get("bucket")
    |> Map.get("name")

    key = s3
    |> Map.get("object")
    |> Map.get("key")

    {bucket, key}
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
