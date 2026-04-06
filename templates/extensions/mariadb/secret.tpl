{{- define "common-helm-library.extensions.mariadb.secret" }}
{{- if .Values.mariadb.enabled }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ .Values.mariadb.rootPasswordSecretName | default (printf "%s-mariadb-root" $.Release.Name) }}
  annotations:
    argocd.argoproj.io/sync-wave: "1"
type: Opaque
data: {} # The operator will fill this automatically
---
{{- end }}
{{- end }}