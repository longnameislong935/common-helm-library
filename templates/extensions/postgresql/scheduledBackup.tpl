{{- define "common-helm-library.extensions.postgres.scheduledBackup" }}
{{- if and .Values.postgres.enabled .Values.postgres.scheduledBackup.enabled }}
{{- with .Values.postgres }}
apiVersion: postgresql.cnpg.io/v1
kind: ScheduledBackup
metadata:
  name: {{ $.Release.Name }}-daily-backup
  annotations:
    {{- if .recovery.enabled }}
    # Higher than cluster (default 3) to prevent race conditions
    argocd.argoproj.io/sync-wave: {{ .scheduledBackup.syncWave | default "4" | quote }}
    {{- else }}
    argocd.argoproj.io/sync-wave: "1"
    {{- end }}
spec:
  schedule: {{ .scheduledBackup.schedule | default "0 0 0 * * *" }}
  immediate: {{ if (hasKey .scheduledBackup "immediate") }}{{ .scheduledBackup.immediate }}{{ else }}true{{ end }}
  backupOwnerReference: self
  method: {{ .backup.method | default "plugin" }}
  {{- if .backup.pluginConfiguration }}
  pluginConfiguration:
    name: {{ .backup.pluginConfiguration.name | default "barman-cloud.cloudnative-pg.io" }}
  {{- end }}
  cluster:
    name: {{ $.Release.Name }}-cnpg
---
{{- end }}
{{- end }}
{{- end }}