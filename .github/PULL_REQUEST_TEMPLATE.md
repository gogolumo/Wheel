## Summary

Describe the change and why it belongs in Wheel.

## Linked work

- GitHub issue:
- Trello card:

## Validation

- [ ] `swift test`
- [ ] Relevant executable/demo runs successfully
- [ ] GitHub Actions is green
- [ ] Manual macOS validation completed when the change touches input, permissions, windows, or system APIs

## Product invariants

- [ ] LEFT means previous and RIGHT means next
- [ ] The change does not silently suppress or rewrite native input unless explicitly designed and documented
- [ ] Privacy impact has been reviewed; no unnecessary titles, URLs, paths, typed content, or raw event history are persisted
- [ ] Failure and recovery behavior is documented for risky system integrations

## Evidence

Add concise test results, screenshots, logs, or device observations that make the change reviewable.

## Rollback

Explain how to disable or revert the change if it causes regressions.
