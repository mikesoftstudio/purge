import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { parseBinarySize, parseDfPosix, parseDockerSize, parseDuKilobytes } from "../src/lib/engine/bytes";
import { dedupeNestedPaths, sizeOfPath, walkSize } from "../src/lib/engine/scanner";

assert.equal(parseDockerSize("1.5GB (40%)"), 1_500_000_000);
assert.equal(parseDockerSize("0B (0%)"), 0);
assert.equal(parseDockerSize("2.001GB (48%)"), 2_001_000_000);
assert.equal(parseDockerSize("512kB"), 512_000);
assert.equal(parseBinarySize("1.5GB"), Math.round(1.5 * 1024 ** 3));
assert.equal(parseDuKilobytes("12\t/tmp/foo"), 12);
assert.equal(parseDuKilobytes("0\t/tmp/foo"), 0);

const df = parseDfPosix(
  "Filesystem 1024-blocks Used Available Capacity Mounted on\n/dev/disk3s5 1000000 700000 300000 70% /System/Volumes/Data"
);
assert.ok(df);
assert.equal(df.totalBytes, 1000000 * 1024);
assert.equal(df.usedBytes, 700000 * 1024);
assert.equal(df.freeBytes, 300000 * 1024);
assert.equal(df.filesystem, "/dev/disk3s5");

const nested = dedupeNestedPaths(["/tmp/a/b", "/tmp/a", "/tmp/a/b/c", "/tmp/z"]);
assert.deepEqual(nested.sort(), ["/tmp/a", "/tmp/z"].sort());

async function main() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "purge-size-"));
  try {
    fs.writeFileSync(path.join(dir, "a.bin"), Buffer.alloc(4096));
    fs.mkdirSync(path.join(dir, "sub"));
    fs.writeFileSync(path.join(dir, "sub", "b.bin"), Buffer.alloc(8192));
    const walked = walkSize(dir);
    assert.ok(walked >= 4096 + 8192, `walkSize too small: ${walked}`);
    const sized = await sizeOfPath(dir);
    assert.ok(sized >= 4096 + 8192, `sizeOfPath too small: ${sized}`);
    const fileSize = await sizeOfPath(path.join(dir, "a.bin"));
    assert.ok(fileSize >= 4096, `file sizeOfPath too small: ${fileSize}`);
    assert.equal(await sizeOfPath(path.join(dir, "missing")), 0);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }

  console.log("ok — size parsers and path sizing");
}

void main();
