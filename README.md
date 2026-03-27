> **Disclaimer:** This repo was vibe-coded with Claude.

# Helm Nil SubPath Reproducer

Minimal reproducer demonstrating a nil value handling issue in Helm 3.20.1+ and 4.1.3+.

## The Problem

When a Helm subchart has explicit `null` values in its defaults (like `keyMapping: {password: null}`), and the parent chart doesn't override these values, the `index` function returns `nil` instead of failing to find the key. When this `nil` is passed to `printf "%s"`, it outputs `%!s(<nil>)`.

This breaks volume mounts that use `subPath`, causing Kubernetes to mount the entire secret as a directory instead of a single key file.

## Related Helm Issues

| Issue | Description | Relation |
|-------|-------------|----------|
| [#31644](https://github.com/helm/helm/pull/31644) | Changed nil value handling during merge | Root cause PR |
| [#31919](https://github.com/helm/helm/issues/31919) | Null values not erasing child values | Similar merge issue |
| [#31971](https://github.com/helm/helm/issues/31971) | Nil values shadow global values with pluck | Same root cause |

## Structure

```
helm-nil-reproducer/
├── Chart.yaml                           # Depends on subchart
├── values.yaml                          # Parent values (doesn't set keyMapping)
├── templates/
│   ├── _helpers.tpl                     # Broken vs Fixed helper implementations
│   └── secret.yaml                      # Demonstrates the issue with all three helpers
└── charts/
    └── subchart/
        ├── Chart.yaml                   # Depends on Bitnami common
        ├── values.yaml                  # Subchart defaults with null keyMapping
        ├── charts/
        │   └── common-2.37.0.tgz       # Bitnami common chart
        └── templates/
            └── secret.yaml             # Shows merged values with Bitnami helper
```

## Reproduction

```bash
# Test with different Helm versions
./helm-bin/helm-3.17.0 template ./helm-nil-reproducer | grep password_key
./helm-bin/helm-3.20.1 template ./helm-nil-reproducer | grep password_key
./helm-bin/helm-4.1.3 template ./helm-nil-reproducer | grep password_key
```

## Expected vs Actual Output

**Template code:**
```yaml
subPath: {{ include "common.secrets.key" (dict "existingSecret" .Values.existingSecret "key" "password") | quote }}
```

**Expected** (when keyMapping.password is missing or guard fails):
```yaml
subPath: "password"
```

**Actual** (when keyMapping.password is explicitly null):
```yaml
subPath: "%!s(<nil>)"
```

## Why the Helpers Differ

### Broken Helper (Bitnami `common.secrets.key`)

```go-template
{{- if .existingSecret.keyMapping -}}           # {password: null} is truthy (non-empty map)
  {{- $key = index .existingSecret.keyMapping $.key -}}  # Returns nil (the value is null)
{{- end -}}
{{- printf "%s" $key -}}                         # Outputs %!s(<nil>)
```

### Fixed Helper

```go-template
{{- $customKey := get ( default dict (.existingSecret).keyMapping ) .key -}}
{{- if $customKey -}}                            # nil/null is falsy, guard fails
{{- $customKey -}}
{{- else -}}
{{- .key -}}                                     # Falls through to default: "password"
{{- end -}}
```
