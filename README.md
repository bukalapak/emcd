# Emcd

Emcd is Memcached Client written using Elixir. Emcd uses text protocol instead of binary protocol.

## Installation

First, add Emcd to your `mix.exs` dependencies:

```elixir
def deps do
  [{:emcd, "~> 0.1.0", github: "bukalapak/emcd"}]
end
```

## Configuration

Complete configuration options with default values:

```elixir
config :emcd,
  host: "127.0.0.1",
  port: 3000,
  timeout: 5000,
  namespace: nil
```

## Usage

```elixir
iex> Emcd.start([], [])
{:ok, #Port<0.3561>}
iex> Emcd.set("key", "value")
{:ok, "STORED"}
iex> Emcd.get("key")
{:ok, "value"}
```
