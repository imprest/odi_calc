defmodule OdiCalc.Server do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, [])
  end

  @impl GenServer
  def init(_) do
    {:wx_ref, _, _, pid} = OdiCalc.start_link()
    Process.monitor(pid)
    {:ok, {pid}}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    System.stop(0)
    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    require Logger
    Logger.debug("Unexpected message in OdiCalc: #{inspect(msg)}")
    {:noreply, state}
  end
end
