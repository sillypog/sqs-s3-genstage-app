defmodule Palleto do
  @moduledoc """
  An example GenStage data processing pipeline, reading messages
  from SQS triggered by modifications to an S3 bucket. Each SQS
  message contains the location of a newly created or modified
  S3 object.

  A single producer stage controls a server that retrieves SQS
  messages as demand comes in from consumers, and sends those
  events to multiple producer/consumer-consumer stages. The
  producer/consumer-consumer stages are managed as single units
  within a supervision tree.

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
