defmodule SQS.Consumer do
  @moduledoc """
  The consumer is now recieving events containing the location
  of a file on s3, and the code to display these more complex
  messages has been moved to a separate function.

  Having consumed the event, the original SQS should be removed
  from the queue. For this to happen, the consumer would need
  the message id and a receipt handle in order to instruct
  SQS to delete the message from the queue. Without this, the
  visibility window will timeout and the message will be available
  to be read again.

  At this point, the consumer doesn't have access to that
  information.
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
    {:consumer, :ok, subscribe_to: [{SQS.Producer, min_demand: 0, max_demand: 10}]}
  end

  def handle_events(events, _from, state) do
    :timer.sleep(1000)

    # event_string = Enum.join(events, ", ")
    # IO.puts "Consumed by #{inspect(self)}: #{event_string}"
    display_events(events)

    # Should remove the event from the queue
    # but we don't have the message id

    {:noreply, [], state}
  end

  ########
  # Private functions
  ########
  defp display_events(events) do
    event_string = events
    |> Enum.map(fn({bucket, key}) -> "#{bucket}/#{key}" end)
    |> Enum.join(", ")
    IO.puts "Consumed by #{inspect(self())}: #{event_string}"
  end
end
