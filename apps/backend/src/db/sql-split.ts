/**
 * Batas ukuran satu request migrasi. Turso membalas HTTP 502 untuk 0026 (~413 KB) yang dikirim
 * utuh, sedangkan migrasi ~12 KB lolos. 32 KiB memberi ruang aman dengan jumlah request kecil.
 */
export const DEFAULT_MAX_REQUEST_BYTES = 32 * 1024;

const bytes = (text: string) => Buffer.byteLength(text, 'utf8');
const isWordChar = (ch: string) => /[A-Za-z0-9_$]/.test(ch);
const closeQuote: Record<string, string> = { "'": "'", '"': '"', '`': '`', '[': ']' };

/**
 * Memecah skrip SQL menjadi pernyataan utuh. Titik koma di dalam string, identifier berkutip,
 * komentar, dan badan trigger (BEGIN ... END, termasuk CASE ... END di dalamnya) tidak memotong.
 */
export function splitStatements(sql: string): string[] {
  const statements: string[] = [];
  let start = 0;
  let depth = 0;
  let i = 0;
  while (i < sql.length) {
    const ch = sql[i];
    if (ch === '-' && sql[i + 1] === '-') {
      const end = sql.indexOf('\n', i);
      i = end === -1 ? sql.length : end + 1;
    } else if (ch === '/' && sql[i + 1] === '*') {
      const end = sql.indexOf('*/', i + 2);
      i = end === -1 ? sql.length : end + 2;
    } else if (ch in closeQuote) {
      // Kutip ganda di dalam string ('it''s') sama dengan menutup lalu membuka lagi.
      const end = sql.indexOf(closeQuote[ch], i + 1);
      i = end === -1 ? sql.length : end + 1;
    } else if (isWordChar(ch)) {
      let j = i;
      while (j < sql.length && isWordChar(sql[j])) j++;
      const word = sql.slice(i, j).toUpperCase();
      if (word === 'BEGIN') depth++;
      else if (word === 'CASE' && depth > 0) depth++;
      else if (word === 'END' && depth > 0) depth--;
      i = j;
    } else if (ch === ';' && depth === 0) {
      statements.push(sql.slice(start, i + 1));
      start = i + 1;
      i++;
    } else {
      i++;
    }
  }
  const rest = sql.slice(start);
  if (stripComments(rest).trim()) statements.push(rest);
  return statements;
}

function stripComments(text: string) {
  return text.replace(/--[^\n]*/g, '').replace(/\/\*[\s\S]*?\*\//g, '');
}

/**
 * Mengelompokkan pernyataan supaya tiap request paling besar `maxBytes`. Skrip yang sudah kecil
 * dikirim apa adanya. Satu pernyataan yang lebih besar dari batas tetap dikirim sendirian.
 */
export function chunkSql(sql: string, maxBytes = DEFAULT_MAX_REQUEST_BYTES): string[] {
  if (bytes(sql) <= maxBytes) return [sql];
  const chunks: string[] = [];
  let current = '';
  for (const statement of splitStatements(sql)) {
    if (current && bytes(current) + bytes(statement) > maxBytes) {
      chunks.push(current);
      current = '';
    }
    current += statement;
  }
  if (current) chunks.push(current);
  return chunks;
}
