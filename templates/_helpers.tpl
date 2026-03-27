{{/*
BROKEN: Bitnami's common.secrets.key - does NOT handle nil values correctly
When keyMapping.password is nil, index returns nil, and printf "%s" nil = "%!s(<nil>)"
*/}}
{{- define "broken.secrets.key" -}}
{{- $key := .key -}}
{{- if .existingSecret -}}
  {{- if not (typeIs "string" .existingSecret) -}}
    {{- if .existingSecret.keyMapping -}}
      {{- $key = index .existingSecret.keyMapping $.key -}}
    {{- end -}}
  {{- end }}
{{- end -}}
{{- printf "%s" $key -}}
{{- end -}}


{{/*
FIXED: nubus-common.secrets.key - handles nil values correctly
Uses `get` with default dict, and checks truthiness before using custom key
*/}}
{{- define "fixed.secrets.key" -}}
{{- $customKey := get ( default dict (.existingSecret).keyMapping ) .key -}}
{{- if $customKey -}}
{{- $customKey -}}
{{- else -}}
{{- .key -}}
{{- end -}}
{{- end -}}
