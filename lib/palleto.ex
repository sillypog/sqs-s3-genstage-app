defmodule Palleto do
  @moduledoc """
  There are now multiple consumers, all demanding 10 events.
  The producer and server have not changed since the last step,
  except to include their pid in some log messages.
  """

  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      worker(SQS.Server, []),
      worker(SQS.Producer, []),
      worker(SQS.Consumer, [], id: 1),
      worker(SQS.Consumer, [], id: 2),
      worker(SQS.Consumer, [], id: 3)
    ]

    opts = [strategy: :one_for_one, name: ApplicationSupervisor]
    Supervisor.start_link(children, opts)
  end
end
