# Why My Swift CLI Hung After Touch ID (And What JavaScript and Python Do Differently)

I was building a macOS CLI tool that stores secrets in the Keychain with Touch ID confirmation. Everything worked — Touch ID prompted, the secret was saved — but the program just sat there for a few seconds before exiting. No error. No crash. Just... waiting.

The fix was one line: `exit(0)`. But understanding *why* that was needed taught me something about how three different languages handle async work under the hood.

## The problem

Here's the simplified Swift code that triggers Touch ID:

```swift
context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                       localizedReason: "confirm your identity") { success, error in
    // runs later, after the user touches the sensor
    authSuccess = success
    semaphore.signal()
}
semaphore.wait()  // block until callback fires

// ... store the secret in Keychain ...
print(jsonResponse)
// program reaches end of main.swift... and hangs
```

The secret was stored. The JSON was printed. But the process didn't exit for several seconds.

## What's happening: dispatch queues

Swift (on Apple platforms) uses a concurrency system called **Grand Central Dispatch (GCD)**. Think of it as a pool of worker threads managed by the OS. When you call `evaluatePolicy`, the system handles the Touch ID prompt on a background thread and delivers the result via a callback placed on a **dispatch queue**.

A dispatch queue is essentially a todo list of work items. The system pulls items off the queue and executes them one at a time (serial queue) or concurrently (concurrent queue).

The key behavior: **when a Swift program reaches the end of `main.swift`, the runtime doesn't exit immediately if dispatch queues are still alive.** It waits for them to clean up. The `LAContext` (Touch ID) object internally holds references to dispatch resources, and even though there's no more work to do, the runtime doesn't know that. So it waits.

The fix:

```swift
exit(0)  // hard exit, don't wait for queue cleanup
```

This tells the OS to terminate the process immediately. Since we've already written our output, there's nothing left to lose.

## How JavaScript handles this differently

JavaScript has a single-threaded **event loop**. There are no dispatch queues or background threads (from the developer's perspective). Instead, there's one loop that continuously checks: "is there anything left to do?"

```
   +---> Check timers (setTimeout, setInterval)
   |        |
   |     Check I/O callbacks (file reads, network)
   |        |
   |     Check immediate callbacks (setImmediate)
   |        |
   +---- Anything left? Loop again. Nothing? Exit.
```

Here's the equivalent scenario in Node.js:

```javascript
const crypto = require('crypto');

setTimeout(() => {
    console.log('done');
}, 1000);

// Node exits ~1 second later, right after the callback fires
```

Node.js exits **as soon as the event loop is empty** — no pending timers, no open sockets, no queued callbacks. It doesn't hang because the event loop is the *only* thing keeping the process alive. Once everything is done, there's nothing left to check, and Node exits on its own.

This is why you sometimes see servers do this:

```javascript
const server = http.createServer(handler);
server.listen(3000);
// Node stays alive because the server socket is an open handle in the event loop
```

And if you called `server.close()`, Node would exit — the last reference keeping the event loop alive is gone.

**The difference from Swift:** JavaScript's event loop has perfect knowledge of what's pending. Swift's GCD queues are more opaque — the runtime can't always tell if a queue is "done" because it doesn't own the lifecycle of every object that might post work to a queue.

## How Python handles this

Python's `asyncio` sits between Swift and JavaScript in terms of explicitness:

```python
import asyncio

async def main():
    await authenticate_touch_id()  # hypothetical
    store_secret()
    print(json_response)

asyncio.run(main())
# exits immediately after main() completes
```

`asyncio.run()` creates an event loop, runs your coroutine to completion, then **shuts down the loop and exits**. It's explicit: you tell it what to run, and when that thing finishes, it cleans up.

But Python also has a lower-level API where you can hit the same problem as Swift:

```python
import asyncio

loop = asyncio.get_event_loop()
loop.call_later(5, lambda: print("delayed"))
loop.run_forever()  # hangs until you call loop.stop()
```

If you use `run_forever()` with tasks that schedule other tasks, you need to explicitly stop the loop. Sound familiar?

Python also has `concurrent.futures` with thread pools, which is closer to GCD:

```python
from concurrent.futures import ThreadPoolExecutor

executor = ThreadPoolExecutor(max_workers=4)
future = executor.submit(some_work)
result = future.result()  # blocks until done

# Python process exits... eventually.
# The executor's threads are daemon threads by default,
# so they won't block exit. But if you used daemon=False, they would.
```

Python avoids Swift's problem here by making thread pool threads daemonic by default — they die when the main thread exits, rather than keeping the process alive.

## The comparison at a glance

| Aspect | Swift (GCD) | JavaScript (Event Loop) | Python (asyncio) |
|---|---|---|---|
| **Model** | Thread pool with queues | Single-threaded event loop | Single-threaded event loop (+ optional thread pool) |
| **Who manages threads?** | OS (GCD) | Runtime (libuv/V8) | Runtime (asyncio) |
| **Exit behavior** | Waits for queues to drain | Exits when loop is empty | Exits when `run()` coroutine completes |
| **Hang risk** | Yes — opaque queue lifetimes | Rare — loop tracks references | Low with `asyncio.run()`, possible with `run_forever()` |
| **Fix for hangs** | `exit(0)` or explicit cleanup | `server.close()`, `clearTimeout()` | `loop.stop()`, cancel tasks |

## The takeaway

The fundamental difference is **who knows when the work is done**:

- **JavaScript** knows exactly what's pending because everything goes through one event loop with reference counting. Empty loop = exit.
- **Python's asyncio** knows because you explicitly tell it: "run this one async function, then we're done."
- **Swift's GCD** doesn't always know because dispatch queues are decentralized. Any framework can hold queue resources internally, and the runtime can't distinguish "idle but alive" from "about to post more work."

For a CLI tool that does one thing and exits, this means Swift sometimes needs a nudge: `exit(0)`. It's not a hack — it's the right tool for the job. You're telling the runtime something it can't infer on its own: "we're done here."
