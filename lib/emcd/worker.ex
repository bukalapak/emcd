defmodule Emcd.Worker do
  use GenServer

  def start_link(options) do
    {:ok, sock} = :gen_tcp.connect(
      options[:host], options[:port], options[:connection_options], options[:timeout]
    )

    GenServer.start_link(__MODULE__, {sock, options}, [name: __MODULE__])
  end

  # get <key>*\r\n
  def handle_call({:get, key}, _from, {sock, options}) do
    timeout = options[:timeout]
    key = format_key(key, options[:namespace])

    packet = "get #{key}\r\n" |> String.to_charlist()

    :ok = :gen_tcp.send(sock, packet)
    {:ok, return} = :gen_tcp.recv(sock, 0, timeout)

    {:reply, {:ok, get_value(return)}, {sock, options}}
  end

  # set <key> <flags> <exptime> <bytes> [noreply]\r\n<value>\r\n
  def handle_call({:set, key, value}, _from, {sock, options}) do
    timeout = options[:timeout]
    key = format_key(key, options[:namespace])
    bytes = byte_size(value)

    packet = "set #{key} 0 0 #{bytes} \r\n#{value}\r\n" |> String.to_charlist()

    :ok = :gen_tcp.send(sock, packet)
    {:ok, result} = :gen_tcp.recv(sock, 0, timeout)

    {:reply, {:ok, format_result(result)}, {sock, options}}
  end

  # version\r\n
  def handle_call({:version}, _from, {sock, options}) do
    timeout = options[:timeout]

    packet = "version\r\n" |> String.to_charlist()

    :ok = :gen_tcp.send(sock, packet)
    {:ok, result} = :gen_tcp.recv(sock, 0, timeout)

    {:reply, {:ok, format_result(result)}, {sock, options}}
  end

  defp format_key(key, namespace) do
    if namespace == nil or namespace == "" do
      key
    else
      "#{namespace}:#{key}"
    end
  end

  defp get_value(raw) do
    string = to_string(raw)

    [_first, value, _last] = String.split(string, "\r\n", trim: true)
    value
  end

  defp format_result(raw) do
    string = to_string(raw)

    String.trim(string)
  end
end
