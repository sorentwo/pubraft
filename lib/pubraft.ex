defmodule PubRaft do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  @impl Supervisor
  def init(opts) do
    psub = Keyword.fetch!(opts, :psub)
    node = Keyword.fetch!(opts, :node)
    size = Keyword.fetch!(opts, :size)

    children = [
      {Phoenix.PubSub,
       adapter: Phoenix.PubSub.Redis,
       name: psub,
       node_name: node,
       url: "redis://localhost:6379/10"},
      {PubRaft.Peer, node: node, psub: psub, size: size}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def leader(sup) do
    [{PubRaft.Peer, pid, :worker, _}] =
      sup
      |> Supervisor.which_children()
      |> Enum.filter(fn {module, _, _, _} -> module == PubRaft.Peer end)

    GenServer.call(pid, :leader)
  end
end
