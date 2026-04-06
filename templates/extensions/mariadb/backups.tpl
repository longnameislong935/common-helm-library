{{- define "common-helm-library.extensions.mariadb.backup" }}
{{- if and .Values.mariadb.enabled .Values.mariadb.backup.enabled }}
{{- with .Values.mariadb }}
apiVersion: k8s.mariadb.com/v1alpha1
kind: Backup
metadata:
  name: {{ $.Release.Name }}-s3-backup
  annotations:
    argocd.argoproj.io/sync-wave: {{ .backup.syncWave | default "11" | quote }}
spec:
  mariaDbRef:
    name: {{ $.Release.Name }}
  schedule:
    cron: {{ .backup.schedule | default "0 3 * * *" }}
  maxRetention: {{ printf "%dd" (int (.backup.retentionDays | default 30)) }}
  storage:
    s3:
      bucket: {{ .s3.bucket }}
      endpoint: {{ .s3.endpoint }}
      region: {{ .s3.region | default "us-east-1" }}
      credentialsSecretRef:
        name: {{ .s3.secretName }}
---
{{- end }}
{{- end }}
{{- end }}