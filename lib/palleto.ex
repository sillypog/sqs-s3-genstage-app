defmodule Palleto do
  @moduledoc """
  Messages are now being deleted once they are processed.
  At this point, the SQS aspects of the pipeline are
  working as planned.

  This was done by adding a release function to the server,
  which extracts the newly added message_id and receipt_handle
  fileds from each event sent through the stages. In this
  way, the consumer doesn't need to know anything about the
  implementation of message deleting, it just informs the server
  when a message should be deleted.
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
