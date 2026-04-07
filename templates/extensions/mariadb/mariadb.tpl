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
  rootPasswordSecretKeyRef:
    name: {{ .rootPasswordSecretName | default (printf "%s-mariadb-root" $.Release.Name) }}
    key: root-password
    generate: true

  image: {{ .imageName | default "mariadb:11.4" }}
  replicas: {{ .replicas | default 1 }}
  database: {{ .dbName | default "netlockrmm" }}

  # On some versions, CPU/Memory are top-level fields in spec
  resources:
    {{- toYaml .resources | nindent 4 }}

  # This tells the operator to handle the Service creation
  service:
    type: ClusterIP
    headless: true

  storage:
    size: {{ .size | default "25Gi" }}
    storageClassName: {{ .storageClassName }}
    pvcRetentionPolicy:
      whenDeleted: Delete
      whenScaled: Delete

  # Any custom DB logic goes here
  myCnf: |
    [mariadb]
    bind-address=0.0.0.0
    default_storage_engine=InnoDB
    binlog_format=ROW
---
{{- end }}
{{- end }}
{{- end }}