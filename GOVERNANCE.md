# Project governance

MSDK iOS Lab is an experimental, maintainer-led open-source project. The initial maintainer is [@bibek849](https://github.com/bibek849). Contributors can propose code, research, documentation and tests without owning DJI hardware or buying a particular AI tool.

## Decisions and review

Small changes use an issue and focused PR. Larger changes first propose the problem, alternatives, evidence and tradeoffs in a discussion or issue. Record accepted architecture changes in a short dated document under `docs/decisions/` when needed. The maintainer makes the final scope and merge decision, explains disputed decisions and welcomes evidence that changes them.

Human contributors are accountable for submitted code, regardless of tool assistance. Reviewers assess correctness, evidence, maintainability and provenance. Agent output is not an independent review simply because a second prompt calls it a review. Maintainers may use independent agent reviews as input and still own the decision.

`main` is the shared integration branch. Changes go through a PR and the required software checks. Code owners route review; they do not certify device behavior. While there is one maintainer, GitHub does not require another person's approval of that maintainer's own PR. Review evidence is still recorded; add a mandatory independent approval rule when a second active maintainer can sustain it.

### Configured GitHub controls

Verified 2026-11-02 through the repository API:

- `main` requires a pull request, resolved review conversations and an up-to-date branch with three successful checks: `Swift 6.0.3 synthetic tests`, `Local document links and JSON`, and `Contribution handoff tests`.
- Required checks are bound to the GitHub Actions app. Rules apply to administrators; force pushes and branch deletion are disabled.
- Mandatory external approval count is zero for the current single-maintainer setup. Code-owner approval is not enforced; human review remains the maintainer's responsibility.
- Discussions and private vulnerability reporting are enabled. Lifecycle and hardware-lane labels classify the starter issues.
- Default workflow token access is read-only; workflows cannot approve PR reviews. The existing first-time-contributor fork-run approval policy remains in place.

Recheck settings when administration changes. These controls follow GitHub's [protected-branch model](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches); they do not turn hosted software checks into hardware authorization.

## Evidence and hardware authority

Software correctness, iOS compilation and physical behavior are separate claims. A merged implementation can remain unavailable/experimental. Only the applicable hardware evidence can close a device capability gate. Physical testing, signing assets and authority to operate the owner's equipment remain with the local maintainer.

The [maintainer playbook](docs/MAINTAINER_PLAYBOOK.md) defines the queue and feedback loop. No contribution or donation promises a hardware slot or a response deadline. Test capacity and unresolved prerequisites are visible in the issue state.

## Releases and credit

There is no stable hardware SDK release today. A future tag needs release notes naming the source commit, supported software environment, compatibility matrix, known limitations and exact validation evidence. Mark research previews as prereleases; never promote synthetic success into a supported-aircraft claim. Version changes must explain contract compatibility and migration, with fixtures updated together.

Credit authors in Git history and relevant release notes, including tests, documentation and negative research findings. Judge contributions by useful evidence, not generated line count, agent brand, token spending or paid subscription tier. Contributors retain the authorship and rights described by the [MIT license](LICENSE) and [contribution terms](CONTRIBUTING.md).

The [community launch guide](docs/COMMUNITY_LAUNCH.md) contains an invitation and a small first-contributor plan. It is a draft for the maintainer to share, not evidence of external outreach.

## Becoming a maintainer

Regular contributors can propose a larger role after sustained, well-reviewed work and reliable communication. Access is granted explicitly for a defined responsibility. Contribution history does not automatically grant signing keys, aircraft access, publishing credentials or administration privileges.
