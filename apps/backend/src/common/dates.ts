const WIB_OFFSET_MS = 7 * 60 * 60 * 1000;

/** Today's calendar date (YYYY-MM-DD) on the farm, which runs on Asia/Jakarta time. */
export const jakartaDate = (now: number) => new Date(now + WIB_OFFSET_MS).toISOString().slice(0, 10);
