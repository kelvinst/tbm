defmodule TBM.Cashier do
  @moduledoc """
  A simple cashier simulator.
  """

  alias TBM.Client

  def start(opts \\ []) do
    spawn(fn ->
      queue_loop(opts)
    end)
  end

  def stop(cashier) do
    send(cashier, :stop)
  end

  def process_item(cashier) do
    send(cashier, {:process_item, self()})

    receive do
      message -> message
    after
      1000 -> :timeout
    end
  end

  def get_in_line(cashier) do
    send(cashier, {:get_in_line, self()})

    receive do
      :in_line -> :ok
    after
      1000 -> :timeout
    end
  end

  def pay(cashier) do
    send(cashier, {:pay, self()})

    receive do
      :payed -> :ok
    after
      1000 -> :timeout
    end
  end

  def get_report(cashier) do
    send(cashier, {:get_report, self()})

    receive do
      {:report, report} -> report
    after
      1000 -> :timeout
    end
  end

  def get_stroke(cashier) do
    send(cashier, :stroke)
  end

  @default_state %{line: :queue.new(), items: 0, smart: false}

  defp queue_loop(opts) when is_list(opts) do
    opts
    |> Enum.into(@default_state)
    |> queue_loop()
  end

  defp queue_loop(state) do
    if :queue.is_empty(state.line) do
      receive do
        message -> fallback_receive(message, state, &queue_loop/1)
      end
    else
      {{:value, client}, new_line} = :queue.out(state.line)
      :ok = Client.process(client)

      state
      |> Map.put(:line, new_line)
      |> process_loop()
    end
  end

  defp process_loop(state) do
    receive do
      {:process_item, pid} ->
        Process.sleep(500)
        new_state = Map.update(state, :report, 0, &(&1 + 1))

        if state.smart do
          new_state = Map.update(new_state, :line, :queue.new(), &:queue.in(pid, &1))
          send(pid, :back_to_line)
          queue_loop(new_state)
        else
          send(pid, :next_item)
          process_loop(new_state)
        end

      {:pay, pid} ->
        Process.sleep(500)
        send(pid, :payed)
        queue_loop(state)

      message ->
        fallback_receive(message, state, &process_loop/1)
    after
      5000 ->
        queue_loop(state)
    end
  end

  defp fallback_receive({:get_report, pid}, state, loop_fun) do
    send(pid, {:report, state})
    loop_fun.(state)
  end

  defp fallback_receive({:get_in_line, pid}, state, loop_fun) do
    new_state = Map.update(state, :line, :queue.new(), &:queue.in(pid, &1))
    send(pid, :in_line)
    loop_fun.(new_state)
  end

  defp fallback_receive(:stop, _, _), do: :ok
  defp fallback_receive(:stroke, _, _), do: raise "Cashier had a stroke"
end
