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

        Process.monitor(cashier)

        cashier
        |> Cashier.get_in_line()
        |> handle_cashier_response(state, fn ->
          send(pid, :in_line)
          queue_loop(new_state)
        end)

      :stop ->
        :ok
    end
  end

  defp queue_loop(%{cashier: cashier} = state) do
    receive do
      {:start_processing, pid} ->
        send(pid, :processing)

        process_loop(state)

      {:DOWN, _, :process, ^cashier, _} ->
        cashier_is_dead(state)

      :stop ->
        :ok
    end
  end

  defp process_loop(state) do
    if state.items > 0 do
      new_state = Map.update(state, :items, 0, &(&1 - 1))

      state
      |> send_item()
      |> handle_cashier_response(state, fn ->
        process_loop(new_state)
      end)
    else
      state
      |> send_pay()
      |> handle_cashier_response(state, fn ->
        go_away(state)
      end)
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

  defp handle_cashier_response(:ok, _, fun), do: fun.()
  defp handle_cashier_response(:timeout, state, _), do: cashier_is_dead(state)

  defp cashier_is_dead(state) do
    IO.puts("#{state.name}: There's something wrong with this cashier, send me to another one")
    go_away(state)
  end

  defp go_away(state) do
    state
    |> Map.put(:cashier, nil)
    |> away_loop()
  end
end
