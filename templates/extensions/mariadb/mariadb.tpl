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
  #service:
  #  type: ClusterIP

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

  # --- Metrics ---
  {{- if .metrics.enabled }}
  metrics:
    enabled: true
  {{- end }}

  # --- Point-in-time recovery (binlog archival) ---
  {{- if .pitr.enabled }}
  # Linking the PITR object makes the operator enable binary logs and run the
  # binlog-archival sidecar -> continuous, to-the-second recovery.
  pointInTimeRecoveryRef:
    name: {{ $.Release.Name }}-pitr
  {{- end }}

  # --- Recovery & Bootstrap (restore into a brand-new instance only) ---
  {{- if .recovery.enabled }}
  bootstrapFrom:
    {{- if .pitr.enabled }}
    # Restore the base PhysicalBackup and replay binlogs to targetRecoveryTime.
    pointInTimeRecoveryRef:
      name: {{ $.Release.Name }}-pitr
    {{- if .recovery.targetRecoveryTime }}
    targetRecoveryTime: {{ .recovery.targetRecoveryTime }}
    {{- end }}
    stagingStorage:
      persistentVolumeClaim:
        resources:
          requests:
            storage: {{ .recovery.stagingSize | default (.size | default "25Gi") }}
        accessModes:
          - ReadWriteOnce
    {{- else }}
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
    {{- end }}
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