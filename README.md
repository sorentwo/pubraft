# Pubraft

An implementation of Raft Leadership Election using Phoenix PubSub.

## Installation

Be sure you have Redis installed (or swap out the Phoenix.PubSub adapter). After
cloning the repo install the dependencies:

```elixir
mix deps.get
```

## Usage

Start an iex session with a name or short name, which is necessary for node
identification:

```bash
iex --sname alpha -S mix
```

Once `iex` has started you can start the `PubRaft` supervision tree:

```elixir
{:ok, sup} = PubRaft.start_link(psub: :my_pubsub, size: 3)
```

Without any other nodes to talk to the node will churn along logging out messages like this:

```
12:50:07.113 node=delta@SorenBook mode=follower Becoming a candidate in term 1
12:50:07.119 node=delta@SorenBook mode=candidate Already voted in term 1
12:50:08.320 node=delta@SorenBook mode=candidate Becoming a candidate in term 2
12:50:08.320 node=delta@SorenBook mode=candidate Already voted in term 2
12:50:09.522 node=delta@SorenBook mode=candidate Becoming a candidate in term 3
12:50:09.523 node=delta@SorenBook mode=candidate Already voted in term 3
```

To elect a leader you'll need at least one more node, or preferrably two. Start
another shell and bring up another uniquely named node (beta, gamma, etc), then
start `PubRaft` again.

Now you should see a leader announced:

```
22:49:18.335 node=delta@SorenBook mode=follower Voting for gamma@SorenBook in term 2
22:49:18.340 node=delta@SorenBook mode=follower Newer term (2) discovered, falling back to follower
22:49:18.341 node=delta@SorenBook mode=follower Leader announced as gamma@SorenBook for term 2, becoming follower
```

And you can verify that from any console by asking who the leader is:

```elixir
PubRaft.leader(sup)
# => gamma@local
```

Terminate an iex session, bring it back up, and have fun playing with leadership
election.
