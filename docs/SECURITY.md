# Security baseline

M1 exposes only a status endpoint. Device writes are disabled by default in edge configuration and no protocol adapter or command endpoint is present. Development Compose binds web and API ports to localhost. Example passwords are development placeholders and must be replaced before any shared deployment.

## Required production controls

Use an identity provider or equivalent MFA-capable login, short-lived sessions, organization memberships and per-action authorization. Enforce tenant scope at query and message boundaries. Authenticate gateways with rotated certificates; encrypt API, MQTT and WebSocket traffic. Store secrets in a secret manager, never source control. Apply network allowlists and segmentation between gateways and building controllers. Commands need two independent checks: cloud policy and edge allowlist, with expiry, bounds and audit trail. Treat telemetry and gateway messages as untrusted input. Review dependencies, sign images, run vulnerability scans and establish incident response, backup encryption and restore drills before production.
