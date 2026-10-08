import assert from 'node:assert/strict';
import { test } from 'node:test';
import { fixture, bearer } from '../test-support/fixture.js';

test('inventory listing preserves strict pagination boundaries', async (t) => {
  const f = await fixture(t);
  const headers = bearer((await f.login()).json().data.access_token);
  for (const [query, limit] of [['', 20], ['?limit=100', 100]]) {
    const response = await f.app.inject({ url: `/api/v1/inventaris${query}`, headers });
    assert.equal(response.statusCode, 200, response.body);
    assert.equal(response.json().meta.limit, limit);
  }
  for (const limit of ['101', '0', '-1', '1.5', '999999', '01', '1%0A']) {
    const response = await f.app.inject({ url: `/api/v1/inventaris?limit=${limit}`, headers });
    assert.equal(response.statusCode, 400, response.body);
    assert.equal(response.json().error.code, 'VALIDATION_ERROR');
  }
});
