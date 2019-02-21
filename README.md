# TBM

The BEAM market! A market simulator to learn processes basics in Elixir.

## Script (first presentation)

- The project
  - A supermarket simulator where the cashier and the clients are processes
  - The cashier has a line, clients get in it
  - When there is clients in line, the cashier call them in sequence
  - When the client is called, the cashier starts to process it's items one by one
  - When there is no more items, the client pays and goes away
- The theorics
  - What are processes?
    - The dummy answer == the thing that **executes** some code
    - The right answer == the thing that **is executed**
    - Its only role is to hold the data needed to be executed
      - All the code that should run
      - Initial arguments to run the code
      - Current function and its stacktrace
      - Arguments for the current function
      - Mailbox
  - Who executes then?
    - Introducing the **Scheduler**
    - Its role is to get the code and the arguments of the processes and execute them
    - One for each core by default, but configurable
  - What aren't processes?
    - Your SO processes (although very similar)
    - Your SO threads (not similar at all)
- The basic practics
  - Running until we die
    - Code is data == anonymous functions or MFAs, you can check types with `i`

    ```elixir
    i fn -> :test end
    ```

    - `spawn` create's a process and execute it

    ```elixir
    pid = spawn fn -> IO.puts("oi") end
    ```

    - PID identifies the process, and the function `self` returns the current process's

    ```elixir
    self()
    ```

    - Process die after the last line of code! †

    ```elixir
    Process.alive? pid
    ```

  - Living forever == running in circles
    - The only way to live forever is through infinite recursion

    ```elixir
    defmodule Nothing do
      def loop, do: loop()
    end

    pid = spawn Nothing, :loop, []
    Process.alive? pid
    Process.exit pid, :kill
    Process.alive? pid
    ```

    - Stack overflow? Naah!

    ```elixir
    :observer.start()
    ```

    - CPU usage? Well, not so much, but that's because we have multiple schedulers running

    ```
    iex --erl "+S 1" -S mix
    ```

    ```elixir
    defmodule Nothing do
      def loop, do: loop()
    end

    pid = spawn Nothing, :loop, []
    :observer.start()
    ```

  - The solution for that? Mess... Wait for it! ...ssages
    - A message is a package of any data you send to a process
    - `send` send's a message to the process

    ```elixir
    send self(), "hello"
    ```

    - Messages go to the mailbox (a FIFO queue), you can use `flush` to clean it and print
    the messages that were on it

    ```elixir
    flush()
    ```

    - `receive` take a messages from the mailbox and assigns a code to run with it


    ```elixir
    send self(), "hello"

    receive do
      msg -> IO.puts(msg)
    end
    ```

    - It waits for a new message if the mailbox is empty

    ```elixir
    defmodule Printer do
      def loop do
        receive do
          msg -> IO.puts msg
        end
      end
    end

    pid = spawn Printer, :loop, []
    send pid, "hello"
    ```

    - PS.: it's a good call to have a way to gracefully stop a process, so you are sure
    nothing will get interrupted, so please pattern match a `:stop` message on `receive`

    ```elixir
    defmodule Printer do
      def loop do
        receive do
          :stop -> :ok
          msg -> IO.puts msg
        end
      end
    end

    pid = spawn Printer, :loop, []
    send pid, "hello"
    ```

    - Commit `The process handling triplet!`

    ```elixir
    ca = TBM.Cashier.start()
    Process.alive?(ca)

    TBM.Cashier.process(ca, a: 10, b: 5)
    Process.alive?(ca)

    TBM.Cashier.stop(ca)
    Process.alive?(ca)
    ```

- The not so basic practics
  - The processes and data relation
    - Saving data inside the process
      - Just send it to the loop when spawning the process

      ```elixir
      defmodule DumbPrinter do
        def loop(msg) do
          :print -> IO.puts(msg)
        end
      end

      pid = spawn DumbPrinter, :loop, ["hello"]
      send pid, :print
      ```

      - For long living ones, remember to pass it back to the loop function. A `Counter`
      module that adds any message to the initial one looks good to exemplify it

      ```elixir
      defmodule Counter do
        def loop(i) do
          receive do
            j ->
              IO.puts("Adding #{j} to #{i}")
              loop(i + j)
          end
        end
      end

      pid = spawn Counter, :loop, [1]
      send pid, 3
      send pid, 10
      send pid, 1
      ```
    - Processes allow MUTABILITY!!
      - Transforming the initial data and passing the new data to the loop function
      sending messages to the `Counter` for example, and the value stored will change

      ```elixir
      defmodule Counter do
        def loop(i) do
          receive do
            :print ->
              IO.puts("Current value: #{i}")
              loop(i)

            j ->
              IO.puts("Adding #{j} to #{i}")
              loop(i + j)
          end
        end
      end

      pid = spawn Counter, :loop, [1]
      send pid, 3
      send pid, :print
      send pid, 10
      send pid, :print
      send pid, 1
      send pid, :print
      ```

    - Commit `How to use processes to save state?`

    ```elixir
    ca = TBM.Cashier.start()
    TBM.Cashier.process(ca, a: 10, b: 5)
    TBM.Cashier.get_report(ca)
    TBM.Cashier.stop(ca)
    ```

  - Processes deeply interacting with each other
    - Sync vs async
      - The 1`send` -> 2`receive` -> 2`send` -> 1`receive` sequence can be used!

      ```elixir
      defmodule Counter do
        def loop(i) do
          receive do
            {:get, pid} ->
              send pid, i
              loop(i)

            j ->
              IO.puts("Adding #{j} to #{i}")
              loop(i + j)
          end
        end
      end

      pid = spawn Counter, :loop, [1]
      send pid, 3
      send pid, {:get, self()}
      receive do
        i -> IO.puts("The response is #{i}")
      end
      ```

    - Deadlocks
      - Timeouts!

      ```elixir
      defmodule Counter do
        def loop(i) do
          receive do
            {:get, pid} ->
              send pid, i
              Process.sleep(5000)
              loop(i)

            j ->
              IO.puts("Adding #{j} to #{i}")
              loop(i + j)
          end
        end
      end

      pid = spawn Counter, :loop, [1]
      send pid, 3
      send pid, {:get, self()}
      receive do
        i -> IO.puts("The response is #{i}")
      after
        500 -> IO.puts("Too late")
      end
      ```

    - Commit `Processes talk to each other!`

    ```elixir
    ca = TBM.Cashier.start()
    [a, b, c] = clients = TBM.Client.start(a: 10, b: 1, c: 5)
    TBM.Client.get_in_line(clients, ca)
    TBM.Cashier.get_report(ca)
    Process.alive?(a)

    TBM.Client.take_items(a, 50)
    TBM.Client.get_in_line(a, ca)
    TBM.Client.stop(a)

    TBM.Cashier.stop(ca)
    ```

    - Debugging
      - Better trace it then break it!
  - Accidents happen, but they don't have to affect everyone!
    - Processes can die earlier than expected
    - The name of this is: ERROR
    - Errors are not really what we want, but they happen!
    - So a process death should be handled as something natural
    - Sending messages to dead processes do not raise any error
    - But deadlocks or timouts can occur
    - It's resposability of the living ones to deal with death
    - Commit `Cashier is working too much!`
    - To guarantee one will be notified from deaths, it can use `Process.monitor/1`.
    You can monitor cashier and use `flush` to check out
- The eureka
  - What a smart cashier can teach us about the BEAM?
    - Instead of process all items to go to the next client,
    let's process one item and send the client back to the queue
    - This way we will divide the cashier time in a fairer way,
    people with less items will not have to wait for the people with
    lots of items that are in front of them in queue
  - Commit `A smart way to handle the line`
  - Elixir works like this market!
    - The smart cashier is a scheduler
    - The client is a process
    - The items are each function call inside the process, the distribution of time is
    counted by the number of functions called on that process since it started to
    be executed
    - `receive` takes the process out of the scheduler queue while there is no message
    on the mailbox, that's how it waits for messages without consuming CPU
    - Immutability and share nothing are very important properties for this to work,
    otherwise stopping the process in the middle of a routine could create unwanted
    side effects that would be a nightmare to debug
    - Everything that talks to external resources, like getting the time, reading a file
    or using a database, is done through processes too, so it is not an exception to the
    immutability and share nothing rule
    - Recursion instead of loops has its role too, otherwise a simple infinite loop
    with nothing inside would DoS a scheduler, with recursion that does not happen
    because the only way to create infinite "loops" is to call the function itself,
    and then the function calls counter would increase, and the scheduler would still
    distribute the processing time evenly through the working processes

