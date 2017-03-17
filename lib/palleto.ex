defmodule Palleto do
  @moduledoc """
  This is the first step that downloads data from SQS.
  There are significant changes to the server to retrieve and
  parse messages from the queue.

  Although the server has changed significantly, the interaction
  with the producer is unchanged and the producer has not been
  modified at all.

  The consumer has been modified to display the new message
  format.

  There is a major issue with the code at this point - although
  messages are consumed, they are never removed from the queue.
  Messages will be consumed more than once.
  """

  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      worker(SQS.Server, []),
      worker(SQS.Producer, []),
      worker(SQS.Consumer, [])
    ]

    opts = [strategy: :one_for_one, name: ApplicationSupervisor]
    Supervisor.start_link(children, opts)
  end
end
