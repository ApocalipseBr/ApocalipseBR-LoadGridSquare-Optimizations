const { spawnSync } = require("node:child_process");

const python = process.platform === "win32" ? "py" : "python3";
const version = process.platform === "win32" ? ["-3"] : [];
const args = ["-B", "-m", "scripts.build_workshop", ...process.argv.slice(2)];
let result = spawnSync(python, [...version, ...args], { stdio: "inherit" });
if (result.error?.code === "ENOENT") {
    result = spawnSync("python", args, { stdio: "inherit" });
}
if (result.error) console.error(result.error.message);
process.exitCode = result.status ?? 1;
