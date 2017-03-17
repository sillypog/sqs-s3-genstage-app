defmodule Palleto do
  @moduledoc """
  A producer/consumer step has been added which downloads
  the file from S3 based on the location extracted from
  the message in the server. The consumer now counts the
  lines in that file and writes the count for each file
  to disk.
  """

  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      worker(SQS.Server, []),
      worker(SQS.Producer, []),
      worker(SQS.ProducerConsumer, []),
      worker(SQS.Consumer, [])
    ]

    opts = [strategy: :one_for_one, name: ApplicationSupervisor]
    Supervisor.start_link(children, opts)
  end
end
