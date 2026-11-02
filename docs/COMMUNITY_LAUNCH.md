# Invite the first contributors

Share the public repository and a small set of ready issues. Start with a few contributors whose environments match those tasks. Keep research questions in Discussions and implementation work in issues/PRs so useful answers stay discoverable.

The invitation below is prepared for the maintainer to post in a relevant community. It has not been sent to anyone by this project setup.

## Copyable invitation

> We're building MSDK iOS Lab, an open-source experiment toward native iPhone support for a useful subset of DJI MSDK 5.18.0 capabilities. The first target is iPhone 15 Pro Max + RC-N3 + Mini 4 Pro. Native compatibility is still research, and no hardware capability is qualified yet.
>
> You do not need a drone to contribute. Bring your own coding assistant or work manually: we have original Swift contracts, synthetic replay tests, small research tasks and a documented handoff. Linux/cloud contributors can work on portable software; Mac contributors can help with Apple-platform checks.
>
> You submit a focused PR and reproducible evidence. The maintainer reviews it and runs eligible device experiments locally, then returns shareable observations that can become regression tests. There is no account sharing, required agent brand or remote access to the aircraft.
>
> Start here: https://github.com/bibek849/msdk-ios-lab
>
> Read the AI contributor workflow, choose a ready issue, and comment with the task you want to tackle and the environment you have. Small, well-tested contributions and useful negative findings are welcome.

## Good first exchanges

| Contributor interest | Suggested starting point | Useful first deliverable |
|---|---|---|
| Swift + tests | LAB-004 | One missing boundary case with a deterministic fixture |
| Video / protocol design | LAB-005 | A small synthetic metadata proposal with clear clock semantics |
| Apple-platform research | LAB-002 | One cited transport hypothesis and its unresolved access requirements |

Avoid starting multiple contributors on the same implementation without coordination. An agent can help inspect the repository and propose a small slice before anyone commits substantial time.

## What to measure as the community grows

Track completed, reproducible contributions; unresolved shared blockers; reviewer effort; and waiting hardware experiments. Keep the public compatibility ledger tied to actual evidence. Stars, generated lines and agent spending do not demonstrate native support or maintainability.

For the first contributor, make the end-to-end experience work: baseline reproduced, scope understood, focused PR reviewed, usable feedback returned, contribution credited. Improve the process from that experience before adding more automation.
