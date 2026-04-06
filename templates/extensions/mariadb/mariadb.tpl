{{- define "common-helm-library.extensions.mariadb.instance" }}
{{- if .Values.mariadb.enabled }}
{{- with .Values.mariadb }}
apiVersion: k8s.mariadb.com/v1alpha1
kind: MariaDB
metadata:
  name: {{ $.Release.Name }}
  annotations:
    argocd.argoproj.io/sync-wave: {{ .recovery.syncWave | default "10" | quote }}
spec:
  # Root password handled by the operator (Randomized in the Secret)
  rootPasswordSecretKeyRef:
    name: {{ .rootPasswordSecretName | default (printf "%s-mariadb-root" $.Release.Name) }}
    key: root-password
    generate: true

  image: {{ .imageName | default "mariadb:11.4" }}
  replicas: {{ .replicas | default 1 }}

  # Enable Prometheus metrics sidecar (Port 9104)
  metrics:
    enabled: true

  {{- if .recovery.enabled }}
  # Bootstrap logic for S3 recovery
  bootstrapFrom:
    s3:
      bucket: {{ .s3.bucket }}
      endpoint: {{ .s3.endpoint }}
      region: {{ .s3.region | default "garage" }}
      credentialsSecretRef:
        name: {{ .s3.secretName }}
  {{- end }}

  # Storage configuration with CNPG-style cleanup
  storage:
    size: {{ .size | default "25Gi" }}
    storageClassName: {{ .storageClassName }}
    pvcRetentionPolicy:
      whenDeleted: Delete
      whenScaled: Delete

  resources:
    {{- toYaml .resources | nindent 4 }}

  # Standard MariaDB configuration for containerised environments
  myCnf: |
    [mariadb]
    bind-address=0.0.0.0
    default_storage_engine=InnoDB
    binlog_format=ROW
---
{{- end }}
{{- end }}
{{- end }}