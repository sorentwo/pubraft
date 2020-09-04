defmodule PubRaft do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  @impl Supervisor
  def init(opts) do
    Logger.configure(level: :debug)

    Logger.configure_backend(:console,
      format: "\n$time $metadata$message",
      metadata: [:node, :mode]
    )

    psub = Keyword.fetch!(opts, :psub)
    size = Keyword.fetch!(opts, :size)

    children = [
      {Phoenix.PubSub,
       adapter: Phoenix.PubSub.Redis,
       name: psub,
       node_name: Node.self(),
       url: "redis://localhost:6379/10"},
      {PubRaft.Peer, node: Node.self(), psub: psub, size: size}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def leader(sup) do
    {PubRaft.Peer, pid, :worker, _} =
      sup
      |> Supervisor.which_children()
      |> List.first()

    GenServer.call(pid, :leader)
  end
end
