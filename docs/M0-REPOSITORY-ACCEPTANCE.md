# M0 — Repository and development environment acceptance

Status: **Accepted — 2026-09-25**

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

The current script runs four canonical repository checks in sequence:

1. `swift build -Xswiftc -warnings-as-errors`
2. `swift build -c release -Xswiftc -warnings-as-errors`
3. `swift test -Xswiftc -warnings-as-errors`
4. `swift run -Xswiftc -warnings-as-errors wheel-demo`

A failure in any command fails the demonstration.

## Acceptance evidence

M0 was accepted after:

- the `main` CI baseline passed;
- [PR #23](https://github.com/gogolumo/Wheel/pull/23) added the reproducible bootstrap command;
- a genuinely fresh clone completed the script with the final line
  `M0 bootstrap check PASS` on 2026-09-25;
- the result was recorded against the M0 project milestone.

Later hardening may add checks to the same script. Those changes strengthen the
ongoing clean-clone contract; they do not retroactively claim that a later
milestone or native macOS feasibility gate has passed.

This milestone does not claim that native input, the menu-bar application, application capture, restoration, signing, or distribution are complete. Those belong to later milestones.
