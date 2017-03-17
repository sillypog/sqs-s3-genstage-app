defmodule Palleto do
  @moduledoc """
  Files are now being processed concurrently. A single producer
  is now sending events to multiple producer/consumer-consumer
  stages. The producer/consumer-consumer stages are managed as
  single units within a supervision tree.

  This design allows us to scale up the number of file processing
  units while keeping the cost of querying SQS relatively constant.
  """

  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      worker(SQS.Server, []),
      worker(SQS.Producer, []),
      supervisor(SQS.ConsumerSupervisor, ["Pipeline1"], id: 1),
      supervisor(SQS.ConsumerSupervisor, ["Pipeline2"], id: 2),
      supervisor(SQS.ConsumerSupervisor, ["Pipeline3"], id: 3)
    ]

    opts = [strategy: :one_for_one, name: ApplicationSupervisor]
    Supervisor.start_link(children, opts)
  end
end
