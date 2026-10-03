import assert from 'node:assert/strict';
import test from 'node:test';
import { fromMinor, MAX_QUANTITY_MINOR, positiveDecimalSchema, toMinor } from '../src/common/quantities.ts';
import { createStockSchema, emptyQuerySchema, historyQuerySchema, idParamSchema, parseInput,
  reverseStockSchema } from '../src/features/stock/contracts.ts';

const line = (id = '1', jumlah = '0.01', satuan = ' ml ') => ({ id_inventaris: id, jumlah, satuan });
const create = (details = [line()], fields = {}) => ({ jenis_stok: 'masuk', details, ...fields });

test('scale-100 quantities preserve exact repeated fractions and bounds', () => {
  assert.equal(toMinor('0.1') + toMinor('0.2'), 30n);
  let balance = 0n;
  for (let i = 0; i < 1000; i++) balance += toMinor('0.01');
  assert.equal(fromMinor(balance), '10');
  for (let i = 0; i < 1000; i++) balance -= toMinor('0.01');
  assert.equal(fromMinor(balance), '0');
  assert.equal(toMinor('9999999999.99'), MAX_QUANTITY_MINOR);
  assert.equal(fromMinor(MAX_QUANTITY_MINOR.toString()), '9999999999.99');
  assert.equal(toMinor('0000000000.01'), 1n);
  for (const [raw, expected] of [['0010.50', '10.5'], ['1.00', '1'], ['0.10', '0.1'], ['0.01', '0.01']]) {
    assert.equal(positiveDecimalSchema.parse(raw), expected);
  }
});

test('quantity boundary rejects floating point transport and unsupported precision without throwing in schemas', () => {
  for (const raw of [0.01, null, '', '0', '0.00', '-1', '+1', ' 1', '1 ', '1\n', '1\r\n', '1e2', '1,2', '.1',
    '1.', '1.000', '10000000000', '00000000000.01', 'NaN', 'Infinity']) {
    assert.equal(positiveDecimalSchema.safeParse(raw).success, false, String(raw));
  }
  for (const raw of ['-1', '1.000', '10000000000', '1e2']) assert.throws(() => toMinor(raw), RangeError);
  for (const raw of [-1n, MAX_QUANTITY_MINOR + 1n, '-1', '1.1', '1e2', '1\n', '']) {
    assert.throws(() => fromMinor(raw), RangeError);
  }
});

test('stock payload canonicalizes reasons, unit labels and numeric signed64 line order', () => {
  const input = create([line('9223372036854775807', '0010.50'), line('10'), line('2')]);
  const result = parseInput(createStockSchema, input);
  assert.deepEqual(result.details.map((v) => v.id_inventaris), ['2', '10', '9223372036854775807']);
  assert.equal(result.details[2].jumlah, '10.5');
  assert.equal(result.details[0].satuan, 'ml');
  assert.equal(result.keterangan, null);
  assert.equal(createStockSchema.parse(create([line()], { keterangan: null })).keterangan, null);
  assert.equal(createStockSchema.parse(create([line()], { keterangan: ' receipt ' })).keterangan, 'receipt');
  assert.equal(reverseStockSchema.parse({ keterangan: ' correction ' }).keterangan, 'correction');
});

test('strict stock payload rejects duplicate, invalid, oversized and forged domain fields', () => {
  const invalid = [create([]), create([line(), line()]),
    create(Array.from({ length: 101 }, (_, i) => line(String(i + 1)))),
    create([line('01')]), create([line('9223372036854775808')]), create([line('1', '1', ' ')]),
    create([line('1', '1', 'a'.repeat(31))]), create([line('1', '1', 'ml')], { jenis_stok: 'other' }),
    create([line()], { keterangan: ' ' }), create([line()], { keterangan: 'a'.repeat(1001) }),
    create([line()], { id_user: '2' }), create([line()], { id_penyemaian: '2' }),
    create([line()], { id_perawatan: '2' }), create([{ ...line(), saldo: '10' }])];
  for (const value of invalid) assert.equal(createStockSchema.safeParse(value).success, false);
  assert.equal(createStockSchema.safeParse(create(Array.from({ length: 100 }, (_, i) => line(String(i + 1))))).success, true);
  for (const value of [{}, { keterangan: null }, { keterangan: ' ' }, { keterangan: 'why', details: [] }]) {
    assert.equal(reverseStockSchema.safeParse(value).success, false);
  }
  assert.throws(() => parseInput(createStockSchema, invalid[0]), { code: 'VALIDATION_ERROR', statusCode: 400 });
});

test('history and item query contracts retain existing pagination and exact ID boundaries', () => {
  assert.deepEqual(historyQuerySchema.parse({}), { page: 1, limit: 20 });
  assert.deepEqual(historyQuerySchema.parse({ page: '2', limit: '100', id_inventaris: '9223372036854775807',
    jenis_stok: 'keluar' }), { page: 2, limit: 100, id_inventaris: '9223372036854775807', jenis_stok: 'keluar' });
  for (const value of [{ page: '0' }, { page: 1 }, { limit: '101' }, { limit: '01' },
    { id_inventaris: '9223372036854775808' }, { jenis_stok: 'other' }, { status_aktif: '1' }]) {
    assert.equal(historyQuerySchema.safeParse(value).success, false);
  }
  assert.equal(emptyQuerySchema.safeParse({}).success, true);
  assert.equal(emptyQuerySchema.safeParse({ page: '1' }).success, false);
  assert.deepEqual(idParamSchema.parse({ id: '9007199254740993' }), { id: '9007199254740993' });
  assert.equal(idParamSchema.safeParse({ id: '9223372036854775808' }).success, false);
});
