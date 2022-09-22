require('./polyfill.js');
require('./wasm_exec.js');

const go = new Go();

const load = WebAssembly.instantiate(WASM, go.importObject)
  .then((instance) => {
    go.run(instance);
    return instance;
  });

async function processRequest(event) {
  const req = event.request;
  await load;
  return handleRequest(req);
}

addEventListener("fetch", (event) => {
  event.respondWith(processRequest(event));
})
