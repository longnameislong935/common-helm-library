{{- define "common-helm-library.extensions.mariadb.pitr" }}
{{- if and .Values.mariadb.enabled .Values.mariadb.pitr.enabled }}
{{- with .Values.mariadb }}
apiVersion: k8s.mariadb.com/v1alpha1
kind: PointInTimeRecovery
metadata:
  name: {{ $.Release.Name }}-pitr
  annotations:
    argocd.argoproj.io/sync-wave: {{ .pitr.syncWave | default "11" | quote }}
spec:
  # Base snapshots that the archived binlogs extend from.
  physicalBackupRef:
    name: {{ $.Release.Name }}-physicalbackup
  compression: {{ .pitr.compression | default "gzip" }}
  # How often binary logs are flushed to S3 -> roughly the recovery-point gap.
  archiveTimeout: {{ .pitr.archiveTimeout | default "5m" }}
  strictMode: {{ .pitr.strictMode | default false }}
  storage:
    s3:
      bucket: {{ .s3.bucket }}
      prefix: {{ .pitr.prefix | default "binlog" }}
      endpoint: {{ .s3.endpoint }}
      region: {{ .s3.region | default "garage" }}
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
