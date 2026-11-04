const weightPattern = /^[0-9]{1,8}(?:\.[0-9]{1,2})?$(?![\s\S])/;
const MAX_WEIGHT_MINOR = 9999999999n;

/** Parses an exact decimal harvest weight into scale-100 atoms without rounding. */
export function parseWeight(value: unknown): bigint {
  if (typeof value !== 'string' || !weightPattern.test(value)) throw new Error('Invalid exact harvest weight');
  const [whole, fraction = ''] = value.split('.');
  const minor = BigInt(whole) * 100n + BigInt(fraction.padEnd(2, '0'));
  if (minor > MAX_WEIGHT_MINOR) throw new Error('Harvest weight exceeds range');
  return minor;
}

export function formatWeight(minor: bigint): string {
  return `${minor / 100n}.${String(minor % 100n).padStart(2, '0')}`;
}
