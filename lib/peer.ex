defmodule PubRaft.Peer do
  use GenServer

  require Logger

  alias Phoenix.PubSub

  @heartbeat_timeout 150
  @election_timeout_range 300..600

  defmodule State do
    defstruct [
      :node,
      :psub,
      :size,
      leader: :none,
      mode: :follower,
      term: 0,
      timer: nil,
      vote_for: nil,
      votes: []
    ]
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl GenServer
  def init(opts) do
    state = struct!(State, opts)

    PubSub.subscribe(state.psub, "gossip")

    {:ok, schedule_timeout(state)}
  end

  @impl GenServer
  def terminate(_reason, %State{} = state) do
    PubSub.broadcast(state.psub, "gossip", {:peer_exit, state.node})

    :ok
  end

  @impl GenServer
  def handle_call(:leader, _from, %State{} = state) do
    {:reply, state.leader, state}
  end

  @impl GenServer
  def handle_info(:timeout, %State{} = state) do
    case state.mode do
      :follower -> become_candidate(state)
      :candidate -> check_candidacy(state)
      :leader -> send_heartbeat(state)
    end
  end

  def handle_info({:heartbeat, from, term}, %State{} = state) do
    case {state.mode, state.node, check_term(term, state)} do
      {:leader, ^from, :same} ->
        {:noreply, schedule_timeout(state)}

      {:leader, _from, :older} ->
        {:noreply, schedule_timeout(state)}

      {_mode, _from, _term} ->
        state = %{state | leader: from, mode: :follower}

        {:noreply, schedule_timeout(state)}
    end
  end

  def handle_info({:request_vote, from, term}, %State{} = state) do
    log("Vote request from #{from} on term #{term}", state)

    case {check_term(term, state), check_vote(state)} do
      {:newer, :no_vote} ->
        PubSub.broadcast(state.psub, "gossip", {:respond_vote, state.node, term, from})

        {:noreply, %{state | vote_for: from}}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info({:respond_vote, from, term, vote}, %State{} = state) do
    case {state.node, check_term(term, state), check_quorum(from, state)} do
      {^vote, :same, :quorum} ->
        log("Voted the leader for #{term}", state)

        state =
          state
          |> Map.put(:leader, vote)
          |> Map.put(:mode, :leader)
          |> Map.put(:term, term)
          |> Map.put(:votes, [])
          |> Map.put(:voted_for, nil)

        PubSub.broadcast(state.psub, "gossip", {:announce_leader, state.node, term})

        {:noreply, schedule_timeout(state)}

      {^vote, :same, :no_quorum} ->
        log("Received vote from #{from} on #{term}, no quorum yet", state)

        {:noreply, record_vote(from, state)}

      {_vote, :newer, _quorum} ->
        log("Newer term (#{term}) discovered, falling back to follower", state)

        {:noreply, %{state | mode: :follower, term: term}}

      _ ->
        log("Received vote on term #{term} for another node", state)

        {:noreply, state}
    end
  end

  def handle_info({:announce_leader, from, term}, %State{} = state) do
    case {state.node, term} do
      {^from, _term} ->
        {:noreply, state}

      {_from, _term} ->
        log("Leader announced as #{from} for term #{term}, becoming follower", state)

        {:noreply, %{state | leader: from, term: term, mode: :follower}}
    end
  end

  def handle_info({:peer_exit, from}, %State{} = state) do
    log("Peer #{from} exited and the node is down, starting election", state)

    {:noreply, schedule_timeout(state)}
  end

  # Logging Helpers

  defp log(message, state) do
    Logger.debug(message, node: state.node, term: state.term, mode: state.mode)
  end

  # Timeout Helpers

  defp schedule_timeout(%State{} = state) do
    if is_reference(state.timer), do: Process.cancel_timer(state.timer)

    timeout =
      case state.mode do
        :follower -> Enum.random(@election_timeout_range)
        :candidate -> Enum.max(@election_timeout_range)
        :leader -> @heartbeat_timeout
      end

    timer = Process.send_after(self(), :timeout, timeout)

    %{state | timer: timer}
  end

  # Candidate Helpers

  defp become_candidate(%State{} = state) do
    state = %{state | leader: :none, mode: :candidate, term: state.term + 1}

    PubSub.broadcast(state.psub, "gossip", {:request_vote, state.node, state.term})

    {:noreply, schedule_timeout(state)}
  end

  defp check_candidacy(%State{} = state) do
    if state.mode == :candidate do
      become_candidate(state)
    else
      {:noreply, state}
    end
  end

  defp send_heartbeat(%State{} = state) do
    PubSub.broadcast(state.psub, "gossip", {:heartbeat, state.node, state.term})

    {:noreply, schedule_timeout(state)}
  end

  # Voting Helpers

  defp check_term(term, %State{} = state) do
    cond do
      term > state.term -> :newer
      term == state.term -> :same
      term < state.term -> :older
    end
  end

  defp check_vote(%State{vote_for: nil}), do: :no_vote
  defp check_vote(_state), do: :voted

  defp record_vote(from, state) do
    %{state | votes: [from | state.votes]}
  end

  defp check_quorum(from, state) do
    if length([from | state.votes]) >= state.size / 2 do
      :quorum
    else
      :no_quorum
    end
  end
end
