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

  defp loop do
    receive do
      {:process, client, items} ->
        for i <- items..1 do
          Process.sleep(1000)
          IO.puts("#{client}: Processing item #{i}")
        end

        Process.sleep(1000)
        IO.puts("#{client}: Paying")

        loop()

      :stop ->
        :ok
    end
  end
end
