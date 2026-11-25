import type { Client } from '@libsql/client';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { requirePermission } from '../../common/authorization.js';
import { parseInput } from '../../common/validation.js';
import { createWeatherService, parentLength, type WeatherDeps } from './service.js';

const regionsQuery = z.strictObject({
  level: z.enum(['province', 'regency', 'district', 'village']),
  parent: z.string().regex(/^\d{2}(\.\d{2}){0,2}$/).optional(),
}).refine((query) => query.level === 'province'
  ? query.parent === undefined
  : query.parent?.length === parentLength[query.level]);

const coordinate = (limit: number) => z.string().regex(/^-?\d{1,3}(\.\d{1,10})?$/)
  .transform(Number).refine((value) => Math.abs(value) <= limit);
const locateQuery = z.strictObject({ lat: coordinate(90), lon: coordinate(180) });
const forecastQuery = z.strictObject({ adm4: z.string().regex(/^\d{2}\.\d{2}\.\d{2}\.\d{4}$/) });

/**
 * Cuaca per wilayah. Daftar wilayah (provinsi sampai desa) dan kode BMKG `adm4` datang dari daftar resmi Kemendagri
 * lewat sumber terbuka; posisi GPS diterjemahkan ke desa lewat OpenStreetMap; prakiraan datang dari API publik BMKG.
 * Semuanya disimpan sementara di server supaya batas permintaan layanan gratis itu tidak habis oleh banyak perangkat.
 */
export function registerWeather(app: FastifyInstance, db: Client, clock: () => number, deps: WeatherDeps = {}) {
  const service = createWeatherService(clock, deps);
  const read = requirePermission(db, 'cuaca:read', clock);

  app.get('/api/v1/weather/regions', { preHandler: read }, async (request) => {
    const { level, parent } = parseInput(regionsQuery, request.query);
    return { data: await service.regions(level, parent) };
  });

  app.get('/api/v1/weather/locate', { preHandler: read }, async (request) => {
    const { lat, lon } = parseInput(locateQuery, request.query);
    return { data: await service.locate(lat, lon) };
  });

  app.get('/api/v1/weather/forecast', { preHandler: read }, async (request) => {
    const { adm4 } = parseInput(forecastQuery, request.query);
    const result = await service.forecast(adm4);
    return { data: result.body, meta: { stale: result.stale, fetched_at: new Date(result.fetchedAt).toISOString() } };
  });
}
