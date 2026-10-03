import { z } from 'zod';

export const MAX_QUANTITY_MINOR = 999999999999n;
const decimalPattern = /^\d{1,10}(\.\d{1,2})?$(?![\s\S])/;

/** Convert an exact decimal string to scale-100 atoms without rounding. */
export function toMinor(value: string): bigint {
  if (!decimalPattern.test(value)) throw new RangeError('Quantity must be an exact scale-100 decimal string.');
  const [whole, fraction = ''] = value.split('.');
  const minor = BigInt(whole) * 100n + BigInt(fraction.padEnd(2, '0'));
  if (minor > MAX_QUANTITY_MINOR) throw new RangeError('Quantity exceeds the stock bound.');
  return minor;
}

/** Render a bounded nonnegative balance or quantity read as SQL TEXT. */
export function fromMinor(value: bigint | string): string {
  if (typeof value === 'string' && !/^\d+$(?![\s\S])/.test(value)) {
    throw new RangeError('Minor quantity must be a nonnegative integer.');
  }
  const minor = BigInt(value);
  if (minor < 0n || minor > MAX_QUANTITY_MINOR) throw new RangeError('Minor quantity exceeds the stock bound.');
  const whole = minor / 100n;
  const fraction = (minor % 100n).toString().padStart(2, '0').replace(/0+$/, '');
  return fraction ? `${whole}.${fraction}` : whole.toString();
}

export const positiveDecimalSchema = z.string().regex(decimalPattern)
  .pipe(z.string().refine((value) => toMinor(value) > 0n))
  .transform((value) => fromMinor(toMinor(value)));
