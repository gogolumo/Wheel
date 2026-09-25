# M0 — Repository and development environment acceptance

Status: **Ready for clean-clone demonstration**

M0 exists to prove that Wheel can be cloned, built, tested, and understood without undocumented local setup.

## Automated baseline

The repository contains:

- a SwiftPM package with `WheelDomain`, `WheelCore`, tests, and `wheel-demo`;
- macOS GitHub Actions CI that runs build, tests, and the domain demo;
- issue forms and a pull-request template;
- `CONTRIBUTING.md`, architecture, roadmap, and privacy documentation;
- no signing credentials or release secrets in the repository.

The `main` CI baseline must be green before M0 is accepted.

## Clean-clone demonstration

Run this outside an existing Wheel checkout:

```bash
cd "$(mktemp -d)"
git clone https://github.com/gogolumo/Wheel.git
cd Wheel
bash scripts/bootstrap-check.sh
```

Expected final line:

```text
M0 bootstrap check PASS
```

The script deliberately runs the three canonical M0 checks in sequence:

1. `swift build`
2. `swift test`
3. `swift run wheel-demo`

A failure in any command fails the demonstration.

## Acceptance evidence

M0 may be marked complete when:

- the latest `main` CI is green;
- a clean clone completes `scripts/bootstrap-check.sh` successfully;
- the result is recorded on the M0 Trello card or linked PR.

This milestone does not claim that native input, the menu-bar application, application capture, restoration, signing, or distribution are complete. Those belong to later milestones.
