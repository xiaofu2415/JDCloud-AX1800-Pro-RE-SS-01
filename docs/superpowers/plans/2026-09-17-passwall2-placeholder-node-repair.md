# PassWall2 placeholder-node repair plan

## Goal

Make the RE-SS-01 PassWall2 policy self-heal the stock `examplenode` fallback
when a user has exactly one configured, non-placeholder node, while preserving
explicit direct rules and refusing to guess when several real nodes exist.
Also make boot ordering and runtime checks reflect the actual Xray process and
generated ACL instead of trusting only the init script exit status.

## Evidence

- The live `rulenode.default_node` was `examplenode` even though the user had a
  valid Reality node (`08iyICrG`).
- After selecting Reality and restarting PassWall2, Core stayed running and
  Baidu/Google/GitHub checks succeeded; the activity log changed from
  `default:Example` to `default:Reality`.
- The existing policy only normalizes `DirectFront` and `DirectGame`, and its
  boot helper can run after the stock `passwall2` init entry.

## Implementation steps

1. Extend `tests/test-passwall2-policy.sh` with a failing contract for
   placeholder fallback selection, ambiguous-node refusal, and a real-core
   readiness check.
2. Run the focused test and record the expected failure before changing the
   policy implementation.
3. Update `re-ss-01-passwall2-sync` to:
   - enumerate PassWall2 `nodes` sections through UCI;
   - replace `default_node=examplenode` only when exactly one non-placeholder
     node is present;
   - leave an explicit real node unchanged and warn instead of guessing when
     there are multiple candidates;
   - verify `pidof xray` plus a non-empty generated ACL when deciding whether
     the service is actually healthy, with an init-status fallback if `pidof`
     is unavailable;
   - commit only changed policy values and remain default-off when the global
     switch is disabled.
4. Change the companion init entry to run before the stock `passwall2` entry so
   mapping repair happens before a boot-time core start.
5. Rerun focused tests and the complete builder/manifest test suite.
6. Bump the iStore beta version, update release documentation, commit and push
   the isolated feature branch, then launch the manual iStore cloud build.
7. Inspect the produced manifest and release assets; only then report the build
   as successful. Device-side 30-minute Reality/Hysteria2 OOM and reboot tests
   remain acceptance gates after flashing.

## Acceptance checks

- One real node + `examplenode` maps `rulenode.default_node` to that node.
- Multiple real nodes do not get silently reordered or replaced.
- `DirectFront` and `DirectGame` remain `_direct`.
- Disabled PassWall2 never starts a core.
- Enabled PassWall2 starts when either init status or the real Xray/ACL check
  shows it is not healthy.
- Live activity logs show `default:Reality` (or the user-selected real node),
  Core remains running, and the three LuCI connectivity checks complete.
