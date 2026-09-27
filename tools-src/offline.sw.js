// Lets the home-screen app start without signal. Every file is fetched fresh when there is a
// connection (so updates arrive) and kept in a cache; with no connection, or a very slow one,
// the cached copy is used instead. Copied into build/web/ on export (see CLAUDE.md).
const CACHE = "unbound";
const FILES = ["index.html", "index.js", "index.wasm", "index.pck", "index.audio.worklet.js",
  "index.audio.position.worklet.js", "app.webmanifest", "index.png", "index.icon.png",
  "index.apple-touch-icon.png"];
const TIMEOUT_MS = 4000;   // give up on the network after this and use the cache

self.addEventListener("install", (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(FILES)).then(() => self.skipWaiting()));
});

self.addEventListener("activate", (e) => e.waitUntil(self.clients.claim()));

self.addEventListener("fetch", (e) => {
  const req = e.request;
  if (req.method !== "GET" || new URL(req.url).origin !== location.origin) return;
  // The page itself (any address like / or /index.html) is stored as index.html.
  const key = req.mode === "navigate" ? new URL("index.html", self.registration.scope).href : req.url;
  e.respondWith(fromNetworkOrCache(req, key));
});

async function fromNetworkOrCache(req, key) {
  const cache = await caches.open(CACHE);
  const network = fetch(req).then((res) => {
    if (res.ok && res.status === 200) cache.put(key, res.clone());
    return res;
  });
  const cached = await cache.match(key, { ignoreSearch: true });
  if (!cached) return network;
  // Use the network if it answers in time, otherwise the cached copy (the download carries on
  // in the background and updates the cache for next time).
  const timeout = new Promise((resolve) => setTimeout(() => resolve(cached), TIMEOUT_MS));
  return Promise.race([network.catch(() => cached), timeout]);
}
