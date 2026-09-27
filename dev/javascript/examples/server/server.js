// server.js — Node's event loop: a web server, and waiting without blocking.
//
// Node runs JavaScript on one thread, but never sits idle while waiting:
// a timer, a network request or a file read is started, and the code
// carries on; `await` picks the result up when it's ready. So one small
// program can be a web server and ask it three things at once.
import { createServer } from "node:http";

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// Each answer takes 300 ms to "work out".
const server = createServer(async (request, response) => {
  await sleep(300);
  response.end(`you asked for ${request.url}\n`);
});

server.listen(0, async () => {                    // port 0: any free port
  const base = `http://127.0.0.1:${server.address().port}`;
  console.log(`a server is listening on ${base}`);

  const started = Date.now();
  // Three requests at once: Promise.all waits for all of them together.
  const answers = await Promise.all(
    ["/apples", "/bread", "/cheese"].map((path) => fetch(base + path).then((r) => r.text())),
  );
  for (const answer of answers) process.stdout.write(answer);
  console.log(`three answers of 300 ms each took ${Date.now() - started} ms together`);

  server.close();                                 // nothing left to wait for: Node exits
});
