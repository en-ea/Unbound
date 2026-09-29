// Serves build/web on your Wi-Fi so the iPhone can open the game.
// Usage: node tools-src/serve.js   then open the printed address on the phone.
const http = require("http");
const fs = require("fs");
const path = require("path");
const os = require("os");

const ROOT = path.join(__dirname, "..", "build", "web");
// Localhost is a secure browser context without installing a LAN certificate.
const LOCAL = process.argv.includes("--local");
const PORT = LOCAL ? 8087 : 8080;
const TYPES = {
  ".html": "text/html", ".js": "text/javascript", ".wasm": "application/wasm",
  ".pck": "application/octet-stream", ".png": "image/png", ".json": "application/json",
  ".webmanifest": "application/manifest+json", ".svg": "image/svg+xml",
};

// Godot's web build needs a secure (https) page. A self-signed dev certificate
// is enough: Safari warns once, then you tap through.
const https = require("https");
const opts = LOCAL ? {} : { pfx: fs.readFileSync(path.join(__dirname, "..", "tools", "dev-cert.pfx")), passphrase: "soongame" };

(LOCAL ? http : https).createServer(opts, (req, res) => {
  const url = decodeURIComponent(req.url.split("?")[0]);
  // Godot's offline service worker breaks on iPhone Safari. Serve a tiny one
  // that wipes its caches and removes itself, so the page loads normally.
  if (url === "/index.service.worker.js") {
    res.writeHead(200, { "Content-Type": "text/javascript", "Cache-Control": "no-cache" });
    return res.end(`self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", (e) => e.waitUntil((async () => {
  for (const k of await caches.keys()) await caches.delete(k);
  await self.registration.unregister();
  for (const c of await self.clients.matchAll()) c.navigate(c.url);
})()));`);
  }
  // One-time setup: the phone downloads this to trust the dev certificate.
  if (url === "/trust-me.cer") {
    res.writeHead(200, { "Content-Type": "application/x-x509-ca-cert" });
    return res.end(fs.readFileSync(path.join(__dirname, "..", "tools", "trust-me.cer")));
  }
  const file = path.join(ROOT, url === "/" ? "index.html" : url);
  if (!file.startsWith(ROOT)) { res.writeHead(403); return res.end(); }
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404); return res.end("Not found"); }
    res.writeHead(200, {
      "Content-Type": TYPES[path.extname(file)] || "application/octet-stream",
      "Cache-Control": "no-cache",
    });
    res.end(data);
  });
}).listen(PORT, LOCAL ? "127.0.0.1" : "0.0.0.0", () => {
  if (LOCAL) return console.log(`Local game preview: http://localhost:${PORT}/`);
  const ips = Object.values(os.networkInterfaces()).flat()
    .filter(i => i && i.family === "IPv4" && !i.internal).map(i => i.address);
  console.log("Game server running. On your iPhone (same Wi-Fi), open:");
  ips.forEach(ip => console.log(`  https://${ip}:${PORT}`));
});
