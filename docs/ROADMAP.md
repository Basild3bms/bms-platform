# Roadmap

M2.1F Stage 1 added authenticated organization discovery, and Stage 2 validated local public API connectivity. Stage 3 mobile login, session restoration, protected navigation, and organization selection are implemented. M2.2A adds the secured buildings API; M2.2B integrates read-only Buildings list and detail in Flutter. M2.2C Stage 1 adds the floors and zones backend, now exercised through authenticated local HTTP; client screens, rooms, and later inventory work remain pending. Windows Android validation of commit `66fcbbe` confirmed authenticated local Buildings list and detail. Manual pull-to-refresh and switching between two distinct organizations remain pending. Local HTTP replay of a revoked bearer token returned 401; Flutter secure-storage failure handling remains a release blocker.

| Milestone | Outcome | Exit gate |
|---|---|---|
| M1 foundation | Monorepo, API/schema, web/mobile/edge shells, local Compose, CI and docs | Component checks and limitations recorded in `PROGRESS.md`. |
| M2 identity and inventory | Authentication, tenant membership, roles, spatial hierarchy and inventory APIs | Cross-tenant and role tests pass. |
| M3 telemetry | Simulated BACnet/Modbus reads, MQTT transport, buffering, history and live web updates | Replay, quality and load tests pass without live equipment. |
| M4 operations | Alarms, maintenance and notifications | End-to-end simulator scenarios pass. |
| M5 controlled actions | Command authorization, edge safety, automation and schedules | Safety review and independent simulator tests pass. |
| M6 analytics and release | Energy reporting, mobile workflows, monitoring, backup and deployment hardening | Restore, security and performance gates pass. |

M2.1F added the Flutter platform and architecture foundation after M2.1. Organization discovery supplies the membership contract used by the Stage 3 mobile selector. Stage 3 itself added no building data or equipment control; M2.2B subsequently added read-only Buildings. M2.2C Stage 1 added the backend; M2.2C.3 adds read-only Flutter Floors and Zones browsing on a feature branch. Android/iOS runtime validation and release security work remain open. M2.2–M2.4 follow the sequence in `M2_IMPLEMENTATION_PLAN.md`; later milestones require their own implementation and review. The Flutter phase plan is in `M2_1F_IMPLEMENTATION_PLAN.md`.
