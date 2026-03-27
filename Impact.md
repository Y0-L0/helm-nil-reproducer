> **Disclaimer:** This document was vibe-coded with Claude.

# Impact Analysis: Helm Nil Value Preservation Regression

## Table of Contents

- [Timeline](#timeline)
- [Root Cause](#root-cause)
- [Affected Versions](#affected-versions)
- [Impact Vectors](#impact-vectors)
  - [Bitnami `common.secrets.key`](#1-bitnami-commonsecretskey--snil-in-subpath)
  - [`pluck`-based fallback patterns](#2-pluck-based-fallback-patterns--silent-value-shadowing)
  - [Parent `--values` null override](#3-parent---values-null-override--failure-to-erase)
- [Current Status](#current-status)
- [References](#references)

## Timeline

| Date | Event |
|------|-------|
| 2025-12-12 | [#31643](https://github.com/helm/helm/issues/31643) filed: nil values in user overrides dropped when chart default is `{}` |
| 2026-01-31 | [#31644](https://github.com/helm/helm/pull/31644) merged into Helm v4: preserves nil values when chart default is empty map |
| 2026-02-11 | [#31829](https://github.com/helm/helm/pull/31829) backports #31644 to Helm v3 |
| 2026-03-10 | [#31919](https://github.com/helm/helm/issues/31919) filed: null merging between parent chart values and `--values` broken |
| 2026-03-27 | [#31971](https://github.com/helm/helm/issues/31971) filed: subchart default nils shadow global values via `pluck` |

## Root Cause

PR [#31644](https://github.com/helm/helm/pull/31644) fixed a bug where user-supplied `null` values were incorrectly deleted during value coalescing when the chart default was an empty map `{}`. The fix made the nil-deletion logic more conservative, but as a side effect it also preserves nil values originating from **chart defaults** — not just user overrides.

When a subchart declares defaults like `keyMapping: {password: null}` and the parent chart doesn't override `keyMapping`, the nil value now survives into the final merged values. Previously it would have been cleaned up.

## Affected Versions

- **3.20.1** — backport of #31644 via [#31829](https://github.com/helm/helm/pull/31829)
- **4.1.3** — [#31919](https://github.com/helm/helm/issues/31919) confirmed not fixed (note: the `pluck` issue from [#31971](https://github.com/helm/helm/issues/31971) does not reproduce on v4, likely due to a different code path)

## Impact Vectors

### 1. Bitnami `common.secrets.key` — `%!s(<nil>)` in subPath

**Affected pattern:** Any chart using Bitnami's `common.secrets.key` helper with `keyMapping` defaults containing `null`.

```go-template
{{- $key = index .existingSecret.keyMapping $.key -}}
{{- printf "%s" $key -}}
```

When `keyMapping.password` is `null` (preserved by the regression), `index` returns `nil` and `printf "%s"` outputs the literal string `%!s(<nil>)`.

**Consequence:** Volume mounts using `subPath` get the value `%!s(<nil>)` instead of a valid secret key name. Kubernetes then mounts the entire secret as a directory rather than a single file, silently breaking applications that expect to read a file at that path.

**Blast radius:** Large. The Bitnami common chart is one of the most widely used library charts. Any chart that uses `common.secrets.key` with nullable `keyMapping` defaults is affected.

### 2. `pluck`-based fallback patterns — silent value shadowing

**Affected pattern:** Charts using Sprig's `pluck` for local-then-global-then-default value resolution.

```go-template
{{- pluck "configureCertmanager" .Values.ingress .Values.global.ingress (dict "configureCertmanager" false) | first -}}
```

When a subchart's `values.yaml` declares `ingress.configureCertmanager:` (nil) and the parent sets `global.ingress.configureCertmanager: true`, `pluck` returns the nil as the first match instead of falling through to the global value.

**Consequence:** `nil` is falsy, so `if` guards silently evaluate to false. Features like cert-manager annotations are dropped without any error or warning.

**Blast radius:** Large. This pattern is used by GitLab's Helm chart ([gitlab-org/charts/gitlab#6366](https://gitlab.com/gitlab-org/charts/gitlab/-/work_items/6366)) and likely many other complex umbrella charts.

### 3. Parent `--values` null override — failure to erase

**Affected pattern:** Passing a values file with `null` to erase a value defined in a child chart.

```yaml
# --values override.yaml
child:
  someKey: null  # intended to erase child's default
```

The `null` is retained in the merged values instead of erasing the child's default, changing the semantics of the override.

**Consequence:** Users who relied on `null` to delete subchart defaults can no longer do so. The [Helm documentation](https://helm.sh/docs/chart_template_guide/values_files/#deleting-a-default-key) explicitly describes this as supported behavior.

## Current Status

- **#31643** (the original bug): CLOSED, fixed by #31644
- **#31919** (null merging regression): OPEN, confirmed as a bug, not fixed by 3.20.1 or 4.1.3
- **#31971** (`pluck` shadowing regression): OPEN, filed 2026-03-27, affects 3.20.1 only (v4 unaffected)
- No fix PR has been opened yet for #31919 or #31971

## References

- [Helm docs: Deleting a Default Key](https://helm.sh/docs/chart_template_guide/values_files/#deleting-a-default-key)
- [Bitnami common `_secrets.tpl`](https://github.com/bitnami/charts/blob/main/bitnami/common/templates/_secrets.tpl#L47-L65)
- [agoose77 reproducer repo](https://github.com/agoose77/reproducer-helm-merge-changes)
- [GitLab downstream issue](https://gitlab.com/gitlab-org/charts/gitlab/-/work_items/6366)
