{{- define "common-helm-library.extensions.mariadb.secret" }}
{{- if .Values.mariadb.enabled }}
{{- with .Values.mariadb }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ .rootPasswordSecretName | default (printf "%s-mariadb-root" $.Release.Name) }}
  namespace: {{ $.Release.Namespace }}
  annotations:
    argocd.argoproj.io/sync-wave: "1"
type: Opaque
# We leave 'data' or 'stringData' empty. 
# This allows the MariaDB Operator to 'own' the lifecycle of the actual password string.
data: {} 
---
{{- end }}
{{- end }}
{{- end }}