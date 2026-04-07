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
  # --- Identity & Image ---
  image: {{ .imageName | default "mariadb:11.4" }}
  replicas: {{ .replicas | default 1 }}
  database: {{ .dbName | default $.Release.Name }}

  # --- Auth Strategy ---
  rootPasswordSecretKeyRef:
    name: {{ .rootPasswordSecretName | default (printf "%s-mariadb-root" $.Release.Name) }}
    key: root-password
    generate: true

  # --- Networking ---
  service:
    type: ClusterIP

  # --- Workload Resources ---
  resources:
    {{- toYaml .resources | nindent 4 }}

  # --- Storage ---
  storage:
    storageClassName: {{ .storageClassName }}
    size: {{ .size | default "25Gi" }}
    {{- if .pvcRetentionPolicy }}
    pvcRetentionPolicy:
      whenDeleted: {{ .pvcRetentionPolicy.whenDeleted | default "Delete" }}
      whenScaled: {{ .pvcRetentionPolicy.whenScaled | default "Delete" }}
    {{- end }}

  # --- Recovery & Bootstrap ---
  {{- if .recovery.enabled }}
  bootstrapFrom:
    s3:
      bucket: {{ .s3.bucket }}
      endpoint: {{ .s3.endpoint }}
      region: {{ .s3.region | default "garage" }}
      credentialsSecretRef:
        name: {{ .s3.secretName }}
  {{- end }}

  # --- Database Configuration ---
  myCnf: |
    [mariadb]
    bind-address=0.0.0.0
    default_storage_engine=InnoDB
    binlog_format=ROW
---
{{- end }}
{{- end }}
{{- end }}