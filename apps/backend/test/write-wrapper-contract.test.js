import assert from 'node:assert/strict';
import { test } from 'node:test';
import { readdir, readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const features = fileURLToPath(new URL('../src/features/', import.meta.url));

// Direct authenticatedWrite callers that bypass the receipt system on purpose.
const exemptions = new Set([
  'accounts/create-employee.ts',
  'accounts/update-employee.ts',
  'accounts/activate-employee.ts',
  'accounts/deactivate-employee.ts',
  'accounts/profile.ts',
  'sync/operations.ts',
]);

// Tripwire, not proof: the per-feature tests prove the 400/200 behaviour. This catches
// a new feature that ships a write wrapper without the shared key helper.
test('every feature write wrapper requires an idempotency key', async () => {
  const wrappers = [];
  for (const entry of await readdir(features, { withFileTypes: true })) {
    if (!entry.isDirectory()) continue;
    const files = await readdir(join(features, entry.name));
    if (files.includes('write.ts')) wrappers.push(entry.name);
  }
  assert.ok(wrappers.length >= 7, `expected the existing wrappers, found ${wrappers.join(', ')}`);
  for (const feature of wrappers) {
    const source = await readFile(join(features, feature, 'write.ts'), 'utf8');
    assert.match(source, /requireIdempotencyKey\(/, `${feature}/write.ts must require the header`);
  }
});

test('only documented routes call authenticatedWrite without a key wrapper', async () => {
  const found = [];
  for (const entry of await readdir(features, { recursive: true, withFileTypes: true })) {
    if (!entry.isFile() || !entry.name.endsWith('.ts') || entry.name === 'write.ts') continue;
    const path = join(entry.parentPath ?? entry.path, entry.name);
    const source = await readFile(path, 'utf8');
    if (source.includes('authenticatedWrite(')) {
      found.push(path.slice(features.length).replaceAll('\\', '/'));
    }
  }
  assert.deepEqual(found.filter((file) => !exemptions.has(file)), []);
});
