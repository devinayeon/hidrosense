import { readdir, readFile } from 'node:fs/promises';
import { extname } from 'node:path';

const root = new URL('../', import.meta.url);
const extensions = new Set(['.ts', '.js', '.mjs', '.sql']);
let largest = { path: '', lines: 0 };
async function scan(path) {
  for (const entry of await readdir(new URL(path, root), { withFileTypes: true })) {
    const child = `${path}/${entry.name}`;
    if (entry.isDirectory()) { await scan(child); continue; }
    if (!extensions.has(extname(entry.name))) continue;
    const lines = (await readFile(new URL(child, root), 'utf8')).trimEnd().split('\n').length;
    if (lines > largest.lines) largest = { path: child, lines };
    if (lines > 400) { console.error(`${child}: ${lines} lines (maximum 400)`); process.exitCode = 1; }
  }
}
for (const directory of ['src', 'test', 'test-support', 'scripts', 'migrations']) await scan(directory);
console.log(`Largest code file: ${largest.path} (${largest.lines} lines; maximum 400).`);
