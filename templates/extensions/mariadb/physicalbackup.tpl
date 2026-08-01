{{- define "common-helm-library.extensions.mariadb.physicalBackup" }}
{{- if and .Values.mariadb.enabled .Values.mariadb.physicalBackup.enabled }}
{{- with .Values.mariadb }}
apiVersion: k8s.mariadb.com/v1alpha1
kind: PhysicalBackup
metadata:
  name: {{ $.Release.Name }}-physicalbackup
  annotations:
    argocd.argoproj.io/sync-wave: {{ .physicalBackup.syncWave | default "11" | quote }}
spec:
  mariaDbRef:
    name: {{ $.Release.Name }}-mariadb
    # Don't block on a replica appearing (single-node friendly).
    waitForIt: false
  # PreferReplica falls back to the primary when there is no replica.
  target: {{ .physicalBackup.target | default "PreferReplica" }}
  compression: {{ .physicalBackup.compression | default "gzip" }}
  schedule:
    cron: {{ .physicalBackup.schedule | default "0 */6 * * *" | quote }}
    immediate: {{ if (hasKey .physicalBackup "immediate") }}{{ .physicalBackup.immediate }}{{ else }}true{{ end }}
  maxRetention: {{ .physicalBackup.maxRetention | default "720h" }}
  timeout: {{ .physicalBackup.timeout | default "1h" }}
  storage:
    s3:
      bucket: {{ .s3.bucket }}
      prefix: {{ .physicalBackup.prefix | default "physical" }}
      # endpoint must be a bare host:port (NO http:// scheme) for the operator.
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
  {{- /* S3 needs a staging area; defaults to node emptyDir unless a size is set. */ -}}
  {{- if .physicalBackup.stagingSize }}
  stagingStorage:
    persistentVolumeClaim:
      resources:
        requests:
          storage: {{ .physicalBackup.stagingSize }}
      accessModes:
        - ReadWriteOnce
      {{- if .physicalBackup.stagingStorageClassName }}
      storageClassName: {{ .physicalBackup.stagingStorageClassName }}
      {{- end }}
  {{- end }}
---
{{- end }}
{{- end }}
{{- end }}
