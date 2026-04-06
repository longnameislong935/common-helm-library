{{- define "common-helm-library.extensions.mariadb.instance" }}
{{- if .Values.mariadb.enabled }}
{{- with .Values.mariadb }}
apiVersion: k8s.mariadb.com/v1alpha1
kind: MariaDB
metadata:
  name: {{ $.Release.Name }}-mariadb
  annotations:
    argocd.argoproj.io/sync-wave: {{ .recovery.syncWave | default "10" | quote }}
spec:
  # 1. Root password lifecycle (Operator generates if empty)
  rootPasswordSecretKeyRef:
    name: {{ .rootPasswordSecretName | default (printf "%s-mariadb-root" $.Release.Name) }}
    key: root-password
    generate: true

  # 2. Map Secret to Environment (Required by the MariaDB Image Entrypoint)
  env:
    - name: MARIADB_ROOT_PASSWORD
      valueFrom:
        secretKeyRef:
          name: {{ .rootPasswordSecretName | default (printf "%s-mariadb-root" $.Release.Name) }}
          key: root-password

  image: {{ .imageName | default "mariadb:11.4" }}
  replicas: {{ .replicas | default 1 }}
  dbName: {{ .dbName | default "netlockrmm" }}

  # 3. Enable Prometheus metrics sidecar (Port 9104)
  metrics:
    enabled: true

  {{- if .recovery.enabled }}
  # 4. Bootstrap logic for S3 recovery (Garage)
  bootstrapFrom:
    s3:
      bucket: {{ .s3.bucket }}
      endpoint: {{ .s3.endpoint }}
      region: {{ .s3.region | default "garage" }}
      credentialsSecretRef:
        name: {{ .s3.secretName }}
  {{- end }}

  # 5. Storage configuration with 'Delete' policy
  storage:
    size: {{ .size | default "25Gi" }}
    storageClassName: {{ .storageClassName }}
    pvcRetentionPolicy:
      whenDeleted: Delete
      whenScaled: Delete

  resources:
    {{- toYaml .resources | nindent 4 }}

  # 6. Standard MariaDB configuration
  myCnf: |
    [mariadb]
    bind-address=0.0.0.0
    default_storage_engine=InnoDB
    binlog_format=ROW
---
{{- end }}
{{- end }}
{{- end }}