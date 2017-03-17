defmodule Palleto do
  @moduledoc """
  This is a more accurate simulation of working with SQS.
  Messages are not available immediately and demand is not
  satisfied when the first batch of events is found.
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
