const { app, BrowserWindow } = require("electron");
const { spawn } = require("child_process");
const path = require("path");
const fs = require("fs");
const net = require("net");

let mainWindow = null;
let serverProcess = null;

const PORT = 17338;
const HOST = "127.0.0.1";

function hasNextBuild() {
  const candidates = [
    path.join(process.cwd(), ".next", "BUILD_ID"),
    path.join(app.getAppPath(), ".next", "BUILD_ID"),
  ];
  return candidates.some((c) => {
    try { return fs.statSync(c).isFile(); } catch { return false; }
  });
}

function waitForPort(host, port, timeoutMs = 90000) {
  return new Promise((resolve, reject) => {
    const deadline = Date.now() + timeoutMs;
    const attempt = () => {
      const socket = net.createConnection({ host, port });
      socket.once("connect", () => {
        socket.destroy();
        resolve();
      });
      socket.once("error", () => {
        socket.destroy();
        if (Date.now() > deadline) reject(new Error("timeout waiting for server"));
        else setTimeout(attempt, 250);
      });
    };
    attempt();
  });
}

async function ensureBuild() {
  if (hasNextBuild()) return;
  console.log("[purge] Building app for the first time…");
  await new Promise((resolve, reject) => {
    const builder = spawn("npx", ["next", "build"], {
      cwd: process.cwd(),
      env: { ...process.env },
      stdio: "inherit",
    });
    builder.once("close", (code) => (code === 0 ? resolve() : reject(new Error(`next build exited ${code}`))));
  });
}

async function startNextServer() {
  await ensureBuild();
  const runScript = process.platform === "win32" ? "next.cmd" : "next";
  const localBin = path.join(process.cwd(), "node_modules", ".bin", runScript);

  serverProcess = spawn(localBin, ["start", "-p", String(PORT), "-H", HOST], {
    cwd: process.cwd(),
    env: { ...process.env, PORT: String(PORT), HOSTNAME: HOST },
    stdio: "ignore",
  });

  serverProcess.once("exit", (code) => {
    console.log(`[purge] Server exited (${code})`);
    serverProcess = null;
  });

  await waitForPort(HOST, PORT);
  return `http://${HOST}:${PORT}`;
}

function createWindow(url) {
  mainWindow = new BrowserWindow({
    width: 1120,
    height: 780,
    minWidth: 380,
    minHeight: 600,
    backgroundColor: "#0a1a14",
    title: "Purge — Free disk space",
    autoHideMenuBar: true,
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
    },
  });

  void mainWindow.loadURL(url);
  mainWindow.on("closed", () => { mainWindow = null; });
}

app.whenReady().then(async () => {
  try {
    const devUrl = process.env.PURGE_DEV_URL;
    const url = devUrl || (await startNextServer());
    createWindow(url);
  } catch (err) {
    console.error("[purge] Failed to start:", err);
    app.quit();
  }
});

app.on("window-all-closed", () => {
  serverProcess?.kill();
  if (process.platform !== "darwin") app.quit();
});

app.on("activate", () => {
  if (mainWindow === null && serverProcess) {
    createWindow(`http://${HOST}:${PORT}`);
  }
});

app.on("will-quit", () => {
  serverProcess?.kill();
});