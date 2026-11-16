# API contract

Base path is `/api/v1`; JSON uses UTF-8. The M1 endpoint `GET /api/v1/status` returns `{"service":"bms-api","version":"0.1.0","status":"ok"}` with HTTP 200. It signals process responsiveness, not PostgreSQL, Redis or gateway readiness. The machine-readable contract is `packages/contracts/openapi.yaml`.

Future endpoints will require authentication and tenant-scoped authorization. Collections will use cursor pagination and bounded filters. Mutations will validate input, use idempotency keys where retries can cause effects, return stable error codes, and create audit events. Telemetry will include source timestamp, quality and unit; command responses will distinguish accepted, executed and observed outcomes. WebSocket channels and MQTT topics will be tenant scoped and separately authorized. No control endpoint exists in M1.
