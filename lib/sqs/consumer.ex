defmodule SQS.Consumer do
  @moduledoc """
  This stage receives the contents of a text file.
  It counts the number of non-empty lines in the file
  and writes that count to disk.

  The consumer receives the pipeline name from the
  supervisor and uses this to infer the name of the
  upstream stage it should subscribe to.

  It also sets the pipeline name as its state in
  order to include it in the logging information.
  """

  use GenStage

  ##########
  # Client API
  ##########
  def start_link(pipeline_name) do
    GenStage.start_link(__MODULE__, pipeline_name)
  end


  ##########
  # Server callbacks
  ##########

  def init(pipeline_name) do
    upstream = Enum.join([pipeline_name, "ProducerConsumer"], "")
    {:consumer, pipeline_name, subscribe_to: [{String.to_atom(upstream), min_demand: 0, max_demand: 1}]}
  end

  def handle_events([%{key: key, file: file}] = events, _from, pipeline_name) do
    file
    |> process_file
    |> write_output(String.split(key, "."))

    IO.puts "#{pipeline_name} Consumer processed #{key}"

    SQS.Server.release(events)

    {:noreply, [], pipeline_name}
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
