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
    - `spawn` create's a process and execute it
    - PID identifies the process, and the function `self` returns the current process's
    - Process die after the last line of code! † Use `Process.alive?` to check it
  - Living forever == running in circles
    - The only way to live forever is through infinite recursion. A `Nothing` module
    with a `loop` function should do it
    - Stack overflow? Naah! Check the `:observer.start()`... TCO FTW!!!
    - CPU usage? Well, not so much, but that's because we have multiple schedulers running.
    Check it out with one scheduler with the option `--erl "+S 1"`
  - The solution for that? Mess... Wait for it! ...ssages
    - A message is a package of any data you send to a process
    - `send` send's a message to the process
    - Messages go to the mailbox (a FIFO queue), you can use `flush` to clean it and print
    the messages that were on it
    - `receive` take a messages from the mailbox and assigns a code to run with it
    - It waits for a new message if the mailbox is empty. Create a `Printer` module with
    `receive` on the `loop` function to check it out
    - PS.: it's a good call to have a way to gracefully stop a process, so you are sure
    nothing will get interrupted, so please pattern match a `:stop` message on `receive`
    - Commit `The process handling triplet!`
- The not so basic practics
  - The processes and data relation
    - Saving data inside the process
      - Just send it to the loop when spawning the process. Spawn an anonymous function
      receiving `name` and print `"Hello #{name}"`
      - For long living ones, remember to pass it back to the loop function. A `Counter`
      module that adds any message to the initial one looks good to exemplify it
    - Processes allow MUTABILITY!!
      - Transforming the initial data and passing the new data to the loop function. Keep
      sending messages to the `Counter` for example, and the value stored will change. Pattern
      match a `:print` message to print the current value and you will see
    - Commit `How to use processes to save state?`
  - Processes deeply interacting with each other
    - Sync vs async
      - The 1`send` -> 2`receive` -> 2`send` -> 1`receive` sequence can be used! So if
      instead of sending a `:print` message to `Counter`, we `send` a `{:get, self()}`
      message and wait to `receive` an aswer back from it? That's synchronous!
    - Deadlocks
      - Timeouts!
    - Commit `Processes talk to each other!`
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

