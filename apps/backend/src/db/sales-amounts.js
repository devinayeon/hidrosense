export const MAX_SALE_WEIGHT_MINOR = 9999999999n;
export const MAX_SALE_PRICE_MINOR = 999999999999n;

export function parseMoney(value) {
  if (typeof value !== 'string' || !/^[0-9]{1,10}(?:\.[0-9]{1,2})?$(?![\s\S])/.test(value)) {
    throw new Error('Invalid exact sale price');
  }
  const [whole, fraction = ''] = value.split('.');
  const minor = BigInt(whole) * 100n + BigInt(fraction.padEnd(2, '0'));
  if (minor > MAX_SALE_PRICE_MINOR) throw new Error('Sale price exceeds range');
  return minor;
}

export function formatMoney(minor) {
  return `${minor / 100n}.${String(minor % 100n).padStart(2, '0')}`;
}

export function saleLineTotal(quantityMinor, priceMinor) {
  return (quantityMinor * priceMinor + 50n) / 100n;
}
