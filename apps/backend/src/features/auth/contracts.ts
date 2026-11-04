import { z } from 'zod';
import { tokenPattern } from '../../common/sessions.js';

export const loginSchema = z.strictObject({
  username: z.string().min(1).max(50).regex(/\S/),
  password: z.string().min(1).max(128),
});

export const refreshSchema = z.strictObject({
  refresh_token: z.string().regex(new RegExp(tokenPattern)),
});
