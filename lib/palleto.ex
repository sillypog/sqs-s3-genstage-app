defmodule Palleto do
  @moduledoc """
  This has the same functionality as the previous step,
  but now the producer provides an API to make it explicit
  that the server should inform it when events are found.
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
