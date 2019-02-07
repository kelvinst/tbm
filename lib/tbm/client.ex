defmodule TBM.Client do
  @moduledoc """
  The client simulator.
  """

  alias TBM.Cashier

  def start(list) when is_list(list) do
    for {name, items} <- list do
      start(name, items)
    end
  end

  def start(name, items) do
    spawn(fn ->
      state = %{name: name, items: items}
      away_loop(state)
    end)
  end

  def stop(client) do
    send(client, :stop)
  end

  def process(client) do
    send(client, {:start_processing, self()})

    receive do
      :processing -> :ok
    after
      1000 -> :timeout
    end
  end

  def take_items(client, items) do
    send(client, {:take_items, items, self()})

    receive do
      :items_took -> :ok
    after
      1000 -> :timeout
    end
  end

  def get_in_line(clients, cashier) when is_list(clients) do
    for client <- clients do
      get_in_line(client, cashier)
    end
  end

  def get_in_line(client, cashier) do
    send(client, {:get_in_line, cashier, self()})

    receive do
      :in_line -> :ok
    after
      1000 -> :timeout
    end
  end

  defp away_loop(state) do
    receive do
      {:take_items, items, pid} ->
        new_state = Map.update(state, :items, 0, &(&1 + items))
        send(pid, :items_took)
        away_loop(new_state)

      {:get_in_line, cashier, pid} ->
        new_state = Map.put(state, :cashier, cashier)
        :ok = Cashier.get_in_line(cashier)
        send(pid, :in_line)
        queue_loop(new_state)

      :stop ->
        :ok
    end
  end

  defp queue_loop(state) do
    receive do
      {:start_processing, pid} ->
        send(pid, :processing)

        process_loop(state)

      :stop ->
        :ok
    end
  end

  defp process_loop(state) do
    if state.items > 0 do
      new_state = Map.update(state, :items, 0, &(&1 - 1))
      :ok = send_item(state)
      process_loop(new_state)
    else
      :ok = send_pay(state)

      state
      |> Map.put(:cashier, nil)
      |> away_loop()
    end
  end

  defp send_item(state) do
    Process.sleep(500)
    IO.puts("#{state.name}: Processing item #{state.items}")
    Cashier.process_item(state.cashier)
  end

  defp send_pay(state) do
    Process.sleep(500)
    IO.puts("#{state.name}: Paying")
    Cashier.pay(state.cashier)
  end
end
