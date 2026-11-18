# Roadmap

M2.1F Stage 1 adds authenticated organization discovery, and Stage 2 prepares the mobile client's local API connectivity. Mobile login and organization selection remain separate future implementation work; M2.2 has not started.

| Milestone | Outcome | Exit gate |
|---|---|---|
| M1 foundation | Monorepo, API/schema, web/mobile/edge shells, local Compose, CI and docs | Component checks and limitations recorded in `PROGRESS.md`. |
| M2 identity and inventory | Authentication, tenant membership, roles, spatial hierarchy and inventory APIs | Cross-tenant and role tests pass. |
| M3 telemetry | Simulated BACnet/Modbus reads, MQTT transport, buffering, history and live web updates | Replay, quality and load tests pass without live equipment. |
| M4 operations | Alarms, maintenance and notifications | End-to-end simulator scenarios pass. |
| M5 controlled actions | Command authorization, edge safety, automation and schedules | Safety review and independent simulator tests pass. |
| M6 analytics and release | Energy reporting, mobile workflows, monitoring, backup and deployment hardening | Restore, security and performance gates pass. |

M2.1F adds the Flutter platform and architecture foundation after M2.1. Organization discovery now supplies the membership contract for a future mobile selector; the mobile authentication phase remains held for review. M2.2–M2.4 follow the sequence in `M2_IMPLEMENTATION_PLAN.md`; later milestones require their own implementation and review. The Flutter phase plan is in `M2_1F_IMPLEMENTATION_PLAN.md`.
