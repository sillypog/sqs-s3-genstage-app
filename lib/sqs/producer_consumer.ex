defmodule SQS.ProducerConsumer do
  @moduledoc """
  This stage receives an event containing the location
  of a file on S3. It downloads and unzips this file
  before handing it off to the consumer stage.

  Multiple producer/consumers will be running in parallel,
  so each process receives the pipeline name from the
  supervisor and uses it to create a unique name that is
  discoverable by the consumer in that pipeline.

  The pipeline name is also set as the process state so
  it can be included in the log output.
  """

  use GenStage

  ##########
  # Client API
  ##########
  def start_link(pipeline_name) do
    process_name = Enum.join([pipeline_name, "ProducerConsumer"], "")
    GenStage.start_link(__MODULE__, pipeline_name, name: String.to_atom(process_name))
  end

  ##########
  # Server callbacks
  ##########

  def init(pipeline_name) do
    {:producer_consumer, pipeline_name, subscribe_to: [{SQS.Producer, min_demand: 0, max_demand: 1}]}
  end

  def handle_events([event] = events, _from, pipeline_name) do
    IO.puts "#{pipeline_name} ProducerConsumer received #{length events} events"

    # Retrieve file from S3
    {_status, %{body: zipped_file}} = ExAws.S3.get_object(event.bucket, event.key)
    |> ExAws.request

    file = :zlib.gunzip(zipped_file)

    IO.puts "#{pipeline_name} ProducerConsumer downloaded #{event.key}"

    # Pass the contents of that file to the consumer
    {:noreply, [Map.put(event, :file, file)], pipeline_name}
  end
end
