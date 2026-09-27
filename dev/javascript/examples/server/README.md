# server (JavaScript)

What Node is known for: servers, and doing many things at once on one
thread. The program starts a web server, asks it three questions at the
same time, and gets all three answers in about the time of one.

    make run

Try: ask one at a time (a `for` loop with `await` in it) and compare the
time; run just the server part and open its address in Firefox.
Docs: MDN, "Using promises" and async functions; the Node docs for `http`.
