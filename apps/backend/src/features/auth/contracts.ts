import { z } from 'zod';
import { tokenPattern } from '../../common/sessions.js';
import { canonicalUsername } from '../../common/validation.js';

export const loginSchema = z.strictObject({
  // Dibakukan, bukan ditolak: login tidak membedakan 'Budi' dan 'budi', dan tidak membocorkan aturan username.
  username: z.string().min(1).max(50).regex(/\S/).transform(canonicalUsername),
  password: z.string().min(1).max(128),
});

export const refreshSchema = z.strictObject({
  refresh_token: z.string().regex(new RegExp(tokenPattern)),
});
