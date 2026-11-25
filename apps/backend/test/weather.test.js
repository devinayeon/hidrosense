// Permintaan pemilik (2026-11-23): lokasi cuaca hanya tiga pilihan tetap. Lokasi harus bisa dipilih
// dari seluruh wilayah Indonesia dan mengikuti lokasi pengguna, dengan prakiraan BMKG per desa.
// Bentuk jawaban layanan luar di sini disalin dari jawaban nyata wilayah.id, Nominatim dan BMKG
// (diperiksa langsung 2026-11-23): kode wilayah bertitik, dan Nominatim sering tanpa kecamatan.
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { bearer, fixture } from '../test-support/fixture.js';

const WILAYAH = 'https://wilayah.id/api/';
const BMKG = 'https://api.bmkg.go.id/publik/prakiraan-cuaca';

const wilayah = {
  'provinces.json': [{ code: '35', name: 'Jawa Timur' }, { code: '33', name: 'Jawa Tengah' }],
  'regencies/35.json': [
    { code: '35.09', name: 'Kabupaten Jember' },
    { code: '35.73', name: 'Kota Malang' },
  ],
  'districts/35.09.json': [
    { code: '35.09.12', name: 'Ambulu' },
    { code: '35.09.13', name: 'Wuluhan' },
  ],
  'districts/35.73.json': [{ code: '35.73.01', name: 'Kedungkandang' }],
  'villages/35.09.12.json': [
    { code: '35.09.12.2001', name: 'Karang Anyar' },
    { code: '35.09.12.2002', name: 'Sabrang' },
    { code: '35.09.12.2003', name: 'Sumberejo' },
  ],
  'villages/35.09.13.json': [
    { code: '35.09.13.2001', name: 'Dukuhdempok' },
    { code: '35.09.13.2002', name: 'Sumberejo' },
  ],
  'villages/35.73.01.json': [{ code: '35.73.01.1001', name: 'Kotalama' }],
};

// Titik pusat desa menurut BMKG (lat, lon), dipakai memilih desa kembar yang terdekat.
const points = {
  '35.09.12.2001': [-8.40, 113.60],
  '35.09.12.2002': [-8.4007, 113.6089],
  '35.09.12.2003': [-8.43, 113.58],
  '35.09.13.2001': [-8.33, 113.55],
  '35.09.13.2002': [-8.3667, 113.5611],
};

function bmkgBody(adm4) {
  const [lat, lon] = points[adm4] ?? [0, 0];
  return {
    lokasi: { adm4, desa: 'Sabrang', kecamatan: 'Ambulu', kotkab: 'Kab. Jember', lat, lon, timezone: 'Asia/Jakarta' },
    data: [{ lokasi: { adm4 }, cuaca: [[{ local_datetime: '2026-09-30 07:00:00', t: 27, hu: 80, tp: 0, weather_desc: 'Cerah', ws: 5, wd: 'N' }]] }],
  };
}

function upstream({ nominatim = {}, bmkgFails = false, bmkgAdm4 } = {}) {
  const calls = [];
  const state = { bmkgFails };
  const fetch = async (url, init = {}) => {
    const href = String(url);
    calls.push(href);
    const json = (body, status = 200) => new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });
    if (href.startsWith(WILAYAH)) {
      const rows = wilayah[href.slice(WILAYAH.length)];
      return rows ? json({ data: rows }) : json({ message: 'not found' }, 404);
    }
    if (href.startsWith('https://nominatim.openstreetmap.org/reverse')) {
      assert.ok(init.headers?.['User-Agent'], 'Nominatim requires an identifying User-Agent');
      return json(nominatim);
    }
    if (href.startsWith(BMKG)) {
      if (state.bmkgFails) return json({ message: 'down' }, 503);
      const adm4 = new URL(href).searchParams.get('adm4');
      return json(bmkgBody(bmkgAdm4 ?? adm4));
    }
    return json({}, 404);
  };
  return { fetch, calls, state };
}

async function setup(t, options) {
  const up = upstream(options);
  const f = await fixture(t, { weather: { fetch: up.fetch } });
  const petani = bearer((await f.login('petani')).json().data.access_token);
  const pegawai = bearer((await f.login('pegawai')).json().data.access_token);
  const get = (headers, url) => f.app.inject({ url: `/api/v1/weather${url}`, headers });
  return { ...f, ...up, petani, pegawai, get };
}

const locate = async (t, address, at = '-8.4007&lon=113.6089') => {
  const f = await setup(t, { nominatim: { address: { country_code: 'id', state: 'Jawa Timur', ...address } } });
  return { f, response: await f.get(f.petani, `/locate?lat=${at}`) };
};

test('provinces are listed from the whole country, not a fixed list of three', async (t) => {
  const f = await setup(t);
  const response = await f.get(f.petani, '/regions?level=province');
  assert.equal(response.statusCode, 200, response.body);
  assert.deepEqual(response.json().data, [
    { id: '33', name: 'Jawa Tengah' },
    { id: '35', name: 'Jawa Timur' },
  ]);
});

test('regions walk down to a village whose code is the BMKG adm4', async (t) => {
  const f = await setup(t);
  assert.deepEqual((await f.get(f.petani, '/regions?level=regency&parent=35')).json().data, [
    { id: '35.09', name: 'Kabupaten Jember' },
    { id: '35.73', name: 'Kota Malang' },
  ]);
  assert.deepEqual((await f.get(f.petani, '/regions?level=district&parent=35.09')).json().data, [
    { id: '35.09.12', name: 'Ambulu' },
    { id: '35.09.13', name: 'Wuluhan' },
  ]);
  const villages = (await f.get(f.petani, '/regions?level=village&parent=35.09.12')).json().data;
  assert.deepEqual(villages.map((row) => [row.name, row.adm4]), [
    ['Karang Anyar', '35.09.12.2001'],
    ['Sabrang', '35.09.12.2002'],
    ['Sumberejo', '35.09.12.2003'],
  ]);
});

test('region lists are cached so the free upstream is not hit on every tap', async (t) => {
  const f = await setup(t);
  await f.get(f.petani, '/regions?level=province');
  await f.get(f.petani, '/regions?level=province');
  assert.equal(f.calls.filter((url) => url.endsWith('provinces.json')).length, 1);
  f.advance(25 * 60 * 60 * 1000);
  const fresh = bearer((await f.login('petani')).json().data.access_token);
  await f.get(fresh, '/regions?level=province');
  assert.equal(f.calls.filter((url) => url.endsWith('provinces.json')).length, 2);
});

test('a GPS position with district and village resolves to the exact adm4', async (t) => {
  const { response } = await locate(t, { county: 'Kabupaten Jember', municipality: 'Kecamatan Ambulu', village: 'Sabrang' });
  assert.equal(response.statusCode, 200, response.body);
  assert.deepEqual(response.json().data, {
    adm4: '35.09.12.2002',
    province: 'Jawa Timur',
    regency: 'Kabupaten Jember',
    district: 'Ambulu',
    village: 'Sabrang',
    approximate: false,
  });
});

test('real Nominatim answers have no kecamatan: the village is found across the regency', async (t) => {
  // Persis bentuk jawaban nyata: county "Jember" tanpa "Kabupaten", tanpa municipality.
  const { response } = await locate(t, { county: 'Jember', village: 'Sabrang', hamlet: 'Krajan Kidul' });
  assert.equal(response.statusCode, 200, response.body);
  const data = response.json().data;
  assert.equal(data.adm4, '35.09.12.2002');
  assert.equal(data.district, 'Ambulu');
  assert.equal(data.approximate, false);
});

test('twin village names are told apart by distance to the user', async (t) => {
  // "Sumberejo" ada di Ambulu dan Wuluhan; posisi pengguna dekat yang di Wuluhan.
  const near = await locate(t, { county: 'Jember', village: 'Sumberejo' }, '-8.3667&lon=113.5611');
  assert.equal(near.response.json().data.adm4, '35.09.13.2002');
  assert.equal(near.response.json().data.district, 'Wuluhan');
  const other = await locate(t, { county: 'Jember', village: 'Sumberejo' }, '-8.43&lon=113.58');
  assert.equal(other.response.json().data.adm4, '35.09.12.2003');
  assert.equal(other.response.json().data.district, 'Ambulu');
});

test('OpenStreetMap and Kemendagri spell a village slightly differently', async (t) => {
  // Jawaban nyata Nominatim memberi "Sumberrejo"; daftar resmi menulis "Sumberejo".
  const { response } = await locate(t, { county: 'Jember', village: 'Sumberrejo' }, '-8.3667&lon=113.5611');
  assert.equal(response.statusCode, 200, response.body);
  assert.equal(response.json().data.adm4, '35.09.13.2002');
});

test('short names are never matched loosely', async (t) => {
  const { response } = await locate(t, { county: 'Jember', village: 'Sabrung' });
  assert.equal(response.json().data.adm4, '35.09.12.2002'); // 7 huruf, selisih satu: boleh
  const other = await locate(t, { county: 'Jember', village: 'Kota' });
  assert.equal(other.response.statusCode, 404);
});

test('when the district is known but the village is not, the nearest village is used and flagged approximate', async (t) => {
  const { response } = await locate(t, { county: 'Kabupaten Jember', municipality: 'Ambulu', village: 'Dusun Tak Dikenal' });
  const data = response.json().data;
  assert.equal(data.district, 'Ambulu');
  assert.equal(data.approximate, true);
  assert.equal(data.adm4, '35.09.12.2002'); // pusat desa Sabrang paling dekat dengan titik uji
});

test('a city address (kota, kelurahan) resolves too', async (t) => {
  const { response } = await locate(t, { city: 'Kota Malang', city_district: 'Kedungkandang', suburb: 'Kotalama' }, '-7.99&lon=112.65');
  const data = response.json().data;
  assert.equal(data.adm4, '35.73.01.1001');
  assert.equal(data.approximate, false);
});

test('a position outside Indonesia or without a match is a clear 404', async (t) => {
  const abroad = await setup(t, { nominatim: { address: { country_code: 'my', state: 'Selangor' } } });
  const response = await abroad.get(abroad.petani, '/locate?lat=3.1&lon=101.6');
  assert.equal(response.statusCode, 404);
  assert.equal(response.json().error.code, 'LOCATION_NOT_FOUND');
  const unknown = await locate(t, { county: 'Jember', village: 'Desa Yang Tidak Ada' });
  assert.equal(unknown.response.statusCode, 404);
});

test('forecast is the BMKG forecast for the chosen village, cached for ten minutes', async (t) => {
  const f = await setup(t);
  const first = await f.get(f.petani, '/forecast?adm4=35.09.12.2002');
  assert.equal(first.statusCode, 200, first.body);
  assert.equal(first.json().data.lokasi.adm4, '35.09.12.2002');
  assert.equal(first.json().meta.stale, false);
  await f.get(f.petani, '/forecast?adm4=35.09.12.2002');
  assert.equal(f.calls.filter((url) => url.startsWith(BMKG)).length, 1);
  f.advance(11 * 60 * 1000);
  const fresh = bearer((await f.login('petani')).json().data.access_token);
  await f.get(fresh, '/forecast?adm4=35.09.12.2002');
  assert.equal(f.calls.filter((url) => url.startsWith(BMKG)).length, 2);
});

test('a BMKG outage serves the last forecast marked stale, then gives up after six hours', async (t) => {
  const f = await setup(t);
  assert.equal((await f.get(f.petani, '/forecast?adm4=35.09.12.2002')).json().meta.stale, false);
  f.state.bmkgFails = true;
  f.advance(11 * 60 * 1000);
  const later = bearer((await f.login('petani')).json().data.access_token);
  const stale = await f.get(later, '/forecast?adm4=35.09.12.2002');
  assert.equal(stale.statusCode, 200, stale.body);
  assert.equal(stale.json().meta.stale, true);
  assert.equal(stale.json().data.lokasi.adm4, '35.09.12.2002');
  f.advance(7 * 60 * 60 * 1000);
  const tooOld = bearer((await f.login('petani')).json().data.access_token);
  assert.equal((await f.get(tooOld, '/forecast?adm4=35.09.12.2002')).statusCode, 502);
});

test('with no earlier forecast an outage is a clear 502', async (t) => {
  const cold = await setup(t, { bmkgFails: true });
  const down = await cold.get(cold.petani, '/forecast?adm4=35.09.12.2002');
  assert.equal(down.statusCode, 502);
  assert.equal(down.json().error.code, 'WEATHER_UPSTREAM_UNAVAILABLE');
});

test('a forecast for another village than the one asked for is refused', async (t) => {
  const f = await setup(t, { bmkgAdm4: '31.71.01.1001' });
  const response = await f.get(f.petani, '/forecast?adm4=35.09.12.2002');
  assert.equal(response.statusCode, 502);
});

test('input, session and permission are checked', async (t) => {
  const f = await setup(t);
  for (const url of ['/regions', '/regions?level=galaksi', '/regions?level=regency', '/regions?level=regency&parent=abc',
    '/regions?level=regency&parent=35.09', '/regions?level=district&parent=35', '/regions?level=village&parent=35.09',
    '/regions?level=province&parent=35', '/locate?lat=abc&lon=1', '/locate?lat=95&lon=1', '/locate?lat=1',
    '/forecast', '/forecast?adm4=35092002', '/forecast?adm4=35.09.12.2002&x=1']) {
    assert.equal((await f.get(f.petani, url)).statusCode, 400, url);
  }
  assert.equal((await f.app.inject({ url: '/api/v1/weather/regions?level=province' })).statusCode, 401);
  // Pegawai has no weather permission.
  assert.equal((await f.get(f.pegawai, '/regions?level=province')).statusCode, 403);
});
