defmodule TBM.Cashier do
  @moduledoc """
  A simple cashier simulator.
  """

  def start do
    spawn(&loop/0)
  end

  def stop(cashier) do
    send(cashier, :stop)
  end

  def process(cashier, clients) do
    for {client, items} <- clients do
      process(cashier, client, items)
    end
  end

  def process(cashier, client, items) do
    send(cashier, {:process, client, items})
  end

  def get_report(cashier) do
    send(cashier, {:get_report, self()})

    receive do
      {:report, report} -> report
    end
  end

  defp loop(report \\ 0) do
    receive do
      {:process, client, items} ->
        for i <- items..1 do
          Process.sleep(1000)
          IO.puts("#{client}: Processing item #{i}")
        end

        Process.sleep(1000)
        IO.puts("#{client}: Paying")

        loop(report + items)

      {:get_report, pid} ->
        send(pid, {:report, report})
        loop(report)

      :stop ->
        :ok
    end
  end
end
