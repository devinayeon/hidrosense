-- Invalidates all sessions and resets throttle counters; domain data is retained.
DROP TABLE auth_rate_limits;
DROP TABLE auth_sessions;
