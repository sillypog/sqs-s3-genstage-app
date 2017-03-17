defmodule SQS.ProducerConsumer do
  @moduledoc """
  The producer/consumer receives a list of processed SQS
  messages from the producer. Because the demand at this
  (and subsequent) stages is set to 1, there will only
  be one event in the events list in handle_events. This
  event contains the bucket and key information needed to
  download a file from S3. That file is then unzipped and
  sent to the next stage.

  In this pipeline the next stage is the consumer, but we
  could have a chain of several producer/consumers processing
  the file data before it reaches the final consumer.
  """

  use GenStage

  ##########
  # Client API
  ##########
  def start_link() do
    GenStage.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  ##########
  # Server callbacks
  ##########

  def init(:ok) do
    {:producer_consumer, :ok, subscribe_to: [{SQS.Producer, min_demand: 0, max_demand: 1}]}
  end

  def handle_events([event] = events, _from, state) do
    # Because demand is set to 1, there will only be one event in the list
    IO.puts "ProducerConsumer received #{length events} events"

    # Retrieve file from S3
    {_status, %{body: zipped_file}} = ExAws.S3.get_object(event.bucket, event.key)
    |> ExAws.request

    file = :zlib.gunzip(zipped_file)

    IO.puts "#ProducerConsumer downloaded #{event.key}"

    # Pass the contents of that file to the consumer
    {:noreply, [Map.put(event, :file, file)], state}
  end
end
