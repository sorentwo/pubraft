# Pubraft

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `pubraft` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:pubraft, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/pubraft](https://hexdocs.pm/pubraft).

# :follower
# :candidate
# :leader
#
# term
# vote? (last voted for)
#
# nodes start in the :follower state
# if they don't hear from a leader within N ms they become a candiate
# candidates request votes from others, nodes reply with their votes
# candidate becomes the leader if it gets votes from a majority of nodes
#
# Leader Election
#
# ### Election Timeout
#
# The amount of time a follower waits until becoming a candidate, randomized to be between 150ms
# and 300ms.
# After the election timeout the follower becomes a candidate and starts a new election term.
# It votes for itself, bumping votes to 1
# Then it sends out a :request_vote message to other nodes
# If the receiving node hasn't voted yet in this term then it votes for the candidate, and the node resets its election timeout
# Once a candidate has a majority of votes it becomes leader
#
# The leader starts sending out :append_entries messages to all followers
# The messages are sent in intervals specified by the "heartbeat timeout"
# Followers respond to each "append entries" message
# This election term will continue until a follower stops receiving heartbeats and becomes a candidate
#
# Split vote example
#
# Two nodes start an election for the same term
# They receive the same number of votes, 2, and are stuck at that level
# Neither can get a majority so they wait to start a new term

