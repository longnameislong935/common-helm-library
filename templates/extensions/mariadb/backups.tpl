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
    name: {{ $.Release.Name }}-mariadb
  schedule:
    cron: {{ .backup.schedule | default "0 3 * * *" }}
  maxRetention: {{ printf "%dd" (int (.backup.retentionDays | default 30)) }}
  storage:
    s3:
      bucket: {{ .s3.bucket }}
      # endpoint must be a bare host:port (NO http:// scheme) for the operator.
      endpoint: {{ .s3.endpoint }}
      region: {{ .s3.region | default "garage" }}
      {{- if .s3.prefix }}
      prefix: {{ .s3.prefix }}
      {{- end }}
      accessKeyIdSecretKeyRef:
        name: {{ .s3.secretName }}
        key: {{ .s3.accessKeyIdKey | default "accessKeyId" }}
      secretAccessKeySecretKeyRef:
        name: {{ .s3.secretName }}
        key: {{ .s3.secretAccessKeyKey | default "secretAccessKey" }}
      tls:
        enabled: {{ .s3.tls | default false }}
---
{{- end }}
{{- end }}
{{- end }}