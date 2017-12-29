defmodule Emcd.Worker do
  use GenServer
  require Logger

  def start_link(options) do
    {socket, status} =
    try do
      {:ok, socket} = :gen_tcp.connect(options[:host], options[:port], options[:connection_options], options[:timeout])
      {socket, true}
    rescue
      _error ->
        :erlang.spawn(Emcd, :retry, [1_000])
        {nil, false}
    end

    GenServer.start_link(__MODULE__, {socket, status, options}, [name: __MODULE__])
  end

  # get <key>*\r\n
  def handle_call({:get, key}, _from, {socket, status, options}) do
    if (status == false) do
      {:reply, {:errorr, :not_connected}, {socket, status, options}}
    else
      key = format_key(key, options[:namespace])

      packet = "get #{key}\r\n" |> String.to_charlist()

      case send_and_receive(socket, packet, options) do
        {:ok, received_packet} ->
          {:reply, {:ok, format_result(received_packet)}, {socket, status, options}}
        {:error, reason} ->
          status = check_error_reason(status, reason)
          {:reply, {:error, reason}, {socket, status, options}}
      end
    end
  end

  # set <key> <flags> <exptime> <bytes> [noreply]\r\n<value>\r\n
  def handle_call({:set, key, value}, _from, {socket, status, options}) do
    if (status == false) do
      {:reply, {:errorr, :not_connected}, {socket, status, options}}
    else
      key = format_key(key, options[:namespace])
      bytes = byte_size(value)

      packet = "set #{key} 0 0 #{bytes} \r\n#{value}\r\n" |> :binary.bin_to_list()

      case send_and_receive(socket, packet, options) do
        {:ok, received_packet} ->
          {:reply, {:ok, format_result(received_packet)}, {socket, status, options}}
        {:error, reason} ->
          status = check_error_reason(status, reason)
          {:reply, {:error, reason}, {socket, status, options}}
      end
    end
  end

  # version\r\n
  def handle_call({:version}, _from, {socket, status, options}) do
    if (status == false) do
      {:reply, {:errorr, :not_connected}, {socket, status, options}}
    else
      packet = "version\r\n" |> String.to_charlist()

      case send_and_receive(socket, packet, options) do
        {:ok, received_packet} ->
          {:reply, {:ok, format_result(received_packet)}, {socket, status, options}}
        {:error, reason} ->
          status = check_error_reason(status, reason)
          {:reply, {:error, reason}, {socket, status, options}}
      end
    end
  end

  def handle_cast({:connect, interval}, {_socket, _status, options}) do
    {socket, status} =
    try do
      {:ok, socket} = :gen_tcp.connect(options[:host], options[:port], options[:connection_options], options[:timeout])
      Logger.info "Connected to server"
      {socket, true}
    rescue
      _error ->
        :erlang.spawn(Emcd, :retry, [interval * 2])
        {nil, false}
    end

    {:noreply, {socket, status, options}}
  end


  defp send_and_receive(socket, packet, options) do
    timeout = options[:timeout]

    case :gen_tcp.send(socket, packet) do
      :ok ->
        :gen_tcp.recv(socket, 0, timeout)
      result ->
        result
    end
  end

  defp check_error_reason(status, reason) do
    if (reason == :closed) do
      :erlang.spawn(Emcd, :retry, [1_000])
      false
    else
      status
    end
  end

  defp format_key(key, namespace) do
    if namespace == nil or namespace == "" do
      key
    else
      "#{namespace}:#{key}"
    end
  end

  defp format_result(raw) do
    to_string(raw) |> String.split("\r\n", trim: true)
  end
end
