# MSDK iOS Lab contributor guidance

- Read README.md, docs/FEASIBILITY.md and the relevant docs/ROADMAP.md gate before changing code.
- Preserve the native iPhone research goal. Android reference or relay success never proves a native port.
- Target MSDK 5.18.0 explicitly. Keep upstream artifact versions, source commits and license boundaries in docs/SOURCES.md and provenance.json.
- This is independent original work. Do not copy Skywarden source, secrets, media, private hardware reports or Git history.
- Keep MOCK, REPLAY and LIVE explicit. Unknown values, units, sessions, sequence and locally measured freshness must remain meaningful. Synthetic tests do not qualify DJI behavior.
- Native accessory access, independent cold start, telemetry, video, camera/gimbal and flight are separate gates. The confirmed target is iPhone 15 Pro Max; its OS build is still pending.
- Resolve rights and publication constraints before using proprietary SDK material or releasing SDK-derived evaluations. No keys, SDK binaries, radio-region changes or authentication bypasses.
- No aircraft commands before the explicit hardware gate and local operator agreement. Pairing/reconnect cannot grant control; eventual RC takeover must latch revocation.
- Keep device installation, signing and physical execution with the local maintainer. Test contributor changes in synthetic/host environments first.
- Record exact commands and limitations in docs/TEST_RESULTS.md. Mark hardware and iOS device tests NOT RUN when they were not performed.
- Test at the changed layer. Preserve independent changes. Do not change or deploy other projects as part of this repository.
- For contributor tasks, read docs/AI_CONTRIBUTOR_WORKFLOW.md and use docs/templates/AGENT_TASK.md. Keep one task's acceptance criteria and scope explicit; ask before expanding that task.
- Return a concise evidence handoff: changed behavior, exact commands/results, full source revision, uncertainty and next experiment. Do not export private conversations, credentials or hidden reasoning traces.
- Agent-generated code has the same provenance, testing and human review requirements as any other contribution. Never turn a CI pass or a handoff manifest into hardware approval.
- Run Python handoff tests when changing workflow tooling. Treat experiment commands as untrusted data; the packaging tool must never execute them.
