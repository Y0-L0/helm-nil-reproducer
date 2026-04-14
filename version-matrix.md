# Version Matrix: Helm Nil Value Behaviors

## The Behaviors

Pre-existing (working in 3.19.5):

- **A** — Subchart nil defaults are cleaned during coalescing (`keyMappingA: {password: null}` → `keyMappingA: {}`)
- **B** — `pluck` falls through subchart nil defaults to global values

Fixed between 3.17 and 3.19.5 (broken in 3.17, working in 3.19.5):

- **C** — `--values null` in a parent override file erases a subchart's default key
- **D** — User-supplied `null` in `--values` is preserved when the chart default is `{}` (fixing the original bug #31643)

---

## Version Matrix

| Behavior | 3.17.0 | 3.19.5 | 3.20.1 | 4.1.3 | main (4.1.5) |
|---|---|---|---|---|---|
| **A** Subchart nil defaults cleaned | ✅ | ✅ | ❌ | ❌ | partial/unclear |
| **B** `pluck` falls through to global | ✅ | ✅ | ❌ | ❌ | partial/unclear |
| **C** `--values null` erases subchart default | ❌ | ✅ | ✅ | ✅ | ✅ |
| **D** User `null` preserved over `{}` default | ❌ | ✅ | ✅ | ✅ | ✅ |

All behaviors confirmed by `compare-versions.sh` across all five binaries.

---

## Regression boundaries

**A and B regressed at 3.19.5 → 3.20.1**.
Introduced by PR #31644 (backported to v3 via #31829).

**C and D were broken / just not implemented in 3.17 and fixed before 3.19.5.**
A separate, earlier change. Not caused by #31644.

**main (4.1.5) seems to not fix A and B completely (yet) 4.1.3.**
My PR on main fixed the real-world regression from my team (bitnami common.secrets.key) and from the gitlab chart.
But it does not fix this reproducer, or at least not completely. I'll have to look into that in more depth.

---

## Observable values per behavior

| Behavior | key | passing value | failing value |
|---|---|---|---|
| A | `keyMappingA_debug` | `"{}"` | `"{\"password\":null}"` |
| B | `pluck_result` | `"true"` | `""` |
| C | `keyMappingC_debug` | `"null"` | `"{\"password\":null}"` |
| D | `extraConfig_debug` | `"null"` | `"{}"` |
