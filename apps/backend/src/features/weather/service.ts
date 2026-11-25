import { ApiError } from '../../common/errors.js';

/** Hanya `fetch` yang bisa diganti; pengujian menyuntikkan jawaban palsu supaya tidak memanggil internet. */
export interface WeatherDeps { fetch?: typeof fetch }

/** Daftar wilayah dengan kode Kemendagri bertitik (35.09.12.2002), sama dengan `adm4` BMKG. */
const WILAYAH = 'https://wilayah.id/api/';
const NOMINATIM = 'https://nominatim.openstreetmap.org/reverse';
const BMKG = 'https://api.bmkg.go.id/publik/prakiraan-cuaca';
const USER_AGENT = 'HidroSense-Backend/1.0 (weather-region-lookup)';

const REGION_TTL_MS = 24 * 60 * 60 * 1000;
const GEOCODE_TTL_MS = 24 * 60 * 60 * 1000;
const FORECAST_TTL_MS = 10 * 60 * 1000;
/** Prakiraan lama masih berguna daripada layar kosong saat BMKG gangguan, tetapi tidak selamanya. */
const FORECAST_STALE_MS = 6 * 60 * 60 * 1000;
/** Nama desa sering kembar di satu kabupaten; paling banyak sekian kandidat dibandingkan jaraknya. */
const MAX_CANDIDATES = 6;
const SCAN_CONCURRENCY = 6;

export type RegionLevel = 'province' | 'regency' | 'district' | 'village';
export interface Region { id: string; name: string; adm4?: string }

/** Panjang kode induk: provinsi `35`, kabupaten `35.09`, kecamatan `35.09.12`. */
export const parentLength: Record<Exclude<RegionLevel, 'province'>, number> = { regency: 2, district: 5, village: 8 };

const noise = new Set(['kabupaten', 'kab', 'kota', 'administrasi', 'adm', 'kecamatan', 'kec', 'desa', 'kelurahan', 'kel', 'provinsi', 'prov']);
function normalize(name: string): string {
  return name.toLowerCase().replace(/[^a-z0-9\s]/g, ' ').split(/\s+/).filter((word) => word && !noise.has(word)).join(' ');
}

const usable = (candidates: unknown[]) => candidates.filter((value): value is string => typeof value === 'string')
  .map(normalize).filter((value) => value.length >= 3);

/** Cocok persis dulu, lalu saling memuat; kandidat kosong atau terlalu pendek tidak dipakai. */
function match(regions: Region[], candidates: unknown[]): Region | undefined {
  const wanted = usable(candidates);
  for (const want of wanted) {
    const exact = regions.find((region) => normalize(region.name) === want);
    if (exact) return exact;
  }
  for (const want of wanted) {
    const loose = regions.find((region) => {
      const name = normalize(region.name);
      return name.length >= 4 && (name.includes(want) || want.includes(name));
    });
    if (loose) return loose;
  }
  return undefined;
}

/** Jarak sunting dua nama; cukup kecil untuk nama desa. */
function editDistance(a: string, b: string): number {
  let previous = Array.from({ length: b.length + 1 }, (_, index) => index);
  for (let i = 1; i <= a.length; i++) {
    const row = [i];
    for (let j = 1; j <= b.length; j++) {
      row[j] = Math.min(previous[j] + 1, row[j - 1] + 1, previous[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
    }
    previous = row;
  }
  return previous[b.length];
}

/**
 * Ejaan OpenStreetMap dan daftar Kemendagri sering berbeda satu-dua huruf ("Sumberrejo" dan "Sumberejo").
 * Nama pendek tidak dilonggarkan supaya "Kota" dan "Kuta" tidak tertukar.
 */
function nearlyEqual(a: string, b: string): boolean {
  if (Math.min(a.length, b.length) < 6) return false;
  return editDistance(a, b) <= (Math.max(a.length, b.length) >= 11 ? 2 : 1);
}

/** Semua yang cocok dengan kandidat pertama (urutan prioritas) yang punya kecocokan; `near` melonggarkan ejaan. */
function matchAll(regions: Region[], candidates: unknown[], near = false): Region[] {
  for (const want of usable(candidates)) {
    const found = regions.filter((region) => near ? nearlyEqual(normalize(region.name), want) : normalize(region.name) === want);
    if (found.length) return found;
  }
  return [];
}

const upstreamDown = () => new ApiError(502, 'WEATHER_UPSTREAM_UNAVAILABLE', 'Layanan data wilayah atau cuaca sedang tidak tersedia.');

const toRadians = (degrees: number) => degrees * Math.PI / 180;
function distanceKm(aLat: number, aLon: number, bLat: number, bLon: number) {
  const dLat = toRadians(bLat - aLat);
  const dLon = toRadians(bLon - aLon);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(toRadians(aLat)) * Math.cos(toRadians(bLat)) * Math.sin(dLon / 2) ** 2;
  return 6371 * 2 * Math.asin(Math.sqrt(h));
}

export function createWeatherService(clock: () => number, deps: WeatherDeps = {}) {
  const doFetch = deps.fetch ?? fetch;
  const cache = new Map<string, { at: number; value: unknown }>();

  async function getJson(url: string, headers: Record<string, string> = {}): Promise<unknown> {
    let response: Response;
    try {
      response = await doFetch(url, { headers: { accept: 'application/json', ...headers }, signal: AbortSignal.timeout(8000) });
    } catch { throw upstreamDown(); }
    if (!response.ok) throw upstreamDown();
    try { return await response.json(); } catch { throw upstreamDown(); }
  }

  async function cached<T>(key: string, ttl: number, load: () => Promise<T>): Promise<T> {
    const hit = cache.get(key);
    if (hit && clock() - hit.at < ttl) return hit.value as T;
    const value = await load();
    cache.set(key, { at: clock(), value });
    return value;
  }

  async function regions(level: RegionLevel, parent?: string): Promise<Region[]> {
    const path = level === 'province' ? 'provinces.json'
      : `${level === 'regency' ? 'regencies' : level === 'district' ? 'districts' : 'villages'}/${parent}.json`;
    return cached(`region:${path}`, REGION_TTL_MS, async () => {
      const body = await getJson(WILAYAH + path) as { data?: unknown };
      if (!body || !Array.isArray(body.data)) throw upstreamDown();
      const rows: Region[] = [];
      for (const row of body.data) {
        if (!row || typeof row.code !== 'string' || typeof row.name !== 'string') throw upstreamDown();
        rows.push(level === 'village' ? { id: row.code, name: row.name, adm4: row.code } : { id: row.code, name: row.name });
      }
      return rows.sort((a, b) => a.name.localeCompare(b.name, 'id'));
    });
  }

  /** Prakiraan BMKG satu desa. Disimpan 10 menit; saat BMKG gangguan, yang terakhir (maks. 6 jam) disajikan dengan tanda `stale`. */
  async function forecast(adm4: string) {
    const key = `forecast:${adm4}`;
    const hit = cache.get(key);
    const now = clock();
    if (hit && now - hit.at < FORECAST_TTL_MS) {
      return { body: hit.value, stale: false, fetchedAt: hit.at };
    }
    try {
      const body = await getJson(`${BMKG}?adm4=${encodeURIComponent(adm4)}`) as { lokasi?: { adm4?: unknown }; data?: unknown };
      // Jawaban untuk desa lain dari yang diminta berarti kode salah atau data tertukar: jangan disimpan.
      if (!body || typeof body !== 'object' || body.lokasi?.adm4 !== adm4 || !Array.isArray(body.data)) throw upstreamDown();
      cache.set(key, { at: now, value: body });
      return { body, stale: false, fetchedAt: now };
    } catch (error) {
      if (hit && now - hit.at < FORECAST_STALE_MS) return { body: hit.value, stale: true, fetchedAt: hit.at };
      throw error;
    }
  }

  /** Koordinat desa menurut BMKG; null bila BMKG tidak menjawab atau tidak memberi koordinat. */
  async function villagePoint(adm4: string): Promise<{ lat: number; lon: number } | null> {
    try {
      const { body } = await forecast(adm4);
      const lokasi = (body as { lokasi?: { lat?: unknown; lon?: unknown } }).lokasi;
      const lat = Number(lokasi?.lat);
      const lon = Number(lokasi?.lon);
      return Number.isFinite(lat) && Number.isFinite(lon) ? { lat, lon } : null;
    } catch { return null; }
  }

  /** Dari beberapa desa kembar, yang koordinatnya paling dekat dengan posisi pengguna. */
  async function nearest<T extends { village: Region }>(candidates: T[], lat: number, lon: number): Promise<T> {
    const limited = candidates.slice(0, MAX_CANDIDATES);
    const points = await Promise.all(limited.map((candidate) => villagePoint(candidate.village.id)));
    let best = limited[0];
    let bestDistance = Infinity;
    limited.forEach((candidate, index) => {
      const point = points[index];
      if (!point) return;
      const distance = distanceKm(lat, lon, point.lat, point.lon);
      if (distance < bestDistance) { best = candidate; bestDistance = distance; }
    });
    return best;
  }

  async function inBatches<T, R>(items: T[], size: number, work: (item: T) => Promise<R>): Promise<R[]> {
    const results: R[] = [];
    for (let start = 0; start < items.length; start += size) {
      results.push(...await Promise.all(items.slice(start, start + size).map(work)));
    }
    return results;
  }

  /**
   * Posisi GPS ke desa/kelurahan. Nominatim (OpenStreetMap) memberi nama wilayah, tetapi sering tanpa kecamatan,
   * jadi desa dicari dari nama di kecamatan yang cocok atau, bila kecamatannya tidak ada, di seluruh kabupaten.
   * Kode `adm4` selalu datang dari daftar resmi, tidak pernah ditebak.
   */
  async function locate(lat: number, lon: number) {
    const key = `geo:${lat.toFixed(3)},${lon.toFixed(3)}`;
    const body = await cached(key, GEOCODE_TTL_MS, () => getJson(
      `${NOMINATIM}?format=jsonv2&addressdetails=1&zoom=18&accept-language=id&lat=${lat}&lon=${lon}`,
      { 'User-Agent': USER_AGENT },
    )) as { address?: Record<string, unknown> };
    const address = body?.address;
    const notFound = () => new ApiError(404, 'LOCATION_NOT_FOUND', 'Lokasi tidak dikenali. Pilih wilayah secara manual.');
    if (!address || address.country_code !== 'id') throw notFound();

    const province = match(await regions('province'), [address.state]);
    if (!province) throw notFound();
    const regency = match(await regions('regency', province.id), [address.county, address.city, address.regency, address.state_district, address.town]);
    if (!regency) throw notFound();
    const districts = await regions('district', regency.id);
    const district = match(districts, [address.municipality, address.city_district, address.district]);
    const villageNames = [address.village, address.suburb, address.neighbourhood, address.quarter, address.hamlet];

    type Found = { district: Region; village: Region };
    let found: Found | undefined;
    let approximate = false;
    if (district) {
      const villages = await regions('village', district.id);
      const exact = matchAll(villages, villageNames);
      const named = exact.length ? exact : matchAll(villages, villageNames, true);
      if (named.length) {
        found = await nearest(named.map((village) => ({ district, village })), lat, lon);
      } else if (villages.length) {
        // Kecamatan dikenal tetapi desanya tidak: desa terdekat di kecamatan itu.
        found = await nearest(villages.map((village) => ({ district, village })), lat, lon);
        approximate = true;
      }
    } else {
      const scanned = await inBatches(districts, SCAN_CONCURRENCY, async (item) => ({
        district: item,
        villages: await regions('village', item.id),
      }));
      const pick = (near: boolean) => scanned.flatMap(({ district: item, villages }) =>
        matchAll(villages, villageNames, near).map((village) => ({ district: item, village })));
      // Ejaan persis di seluruh kabupaten didahulukan; ejaan mirip hanya bila tidak ada yang persis.
      const candidates = pick(false);
      const chosen = candidates.length ? candidates : pick(true);
      if (chosen.length) found = await nearest(chosen, lat, lon);
    }
    if (!found?.village.adm4) throw notFound();
    return {
      adm4: found.village.adm4,
      province: province.name,
      regency: regency.name,
      district: found.district.name,
      village: found.village.name,
      approximate,
    };
  }

  return { regions, locate, forecast };
}

export type WeatherService = ReturnType<typeof createWeatherService>;
