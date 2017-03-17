defmodule SQS.Consumer do
  @moduledoc """
  The consumer is now subscribing to the producer/consumer,
  with a demand of 1 because we only want to process one
  file at a time. The consumer now receives the contents
  of the S3 file and counts the number of lines in the file,
  writing the count to the output/ folder.

  The artificial delay in the consumer has been removed,
  as latency is introduced to the pipeline by the file
  download in the producer/consumer.
  """

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
    {:consumer, :ok, subscribe_to: [{SQS.ProducerConsumer, min_demand: 0, max_demand: 1}]}
  end

  def handle_events([%{key: key, file: file}] = events, _from, state) do
    file
    |> process_file
    |> write_output(String.split(key, "."))

    IO.puts "Consumer processed #{key}"

    SQS.Server.release(events)

    {:noreply, [], state}
  end

  ########
  # Private functions
  ########
  defp process_file(file) do
    file
    |> String.split("\n")
    |> Enum.filter(fn(line) -> line != "" end)
    |> Enum.count
  end

  defp write_output(event_count, [filepath, _]) do
    filename = filepath
    |> String.split("/")
    |> List.last

    # Write the count to a file in append mode,
    # we can use this to ensure each file was only processed once
    File.open("output/#{filename}.txt", [:append], fn(file) ->
      IO.write(file, "#{event_count}\n")
    end)
  end
end
