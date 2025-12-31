{{- define "common-helm-library.extensions.postgres.cluster" }}
{{- if .Values.postgres.enabled }}
{{- with .Values.postgres }}
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: {{ $.Release.Name }}
  annotations:
      argocd.argoproj.io/sync-wave: {{ .recovery.syncWave | default "3" | quote }}
      {{- if ((.skipEmptyWalArchiveCheck).enabled) }}
      cnpg.io/skipEmptyWalArchiveCheck: "enabled"
      {{- end }}
spec:
  instances: {{ .replicas | default 1 }}
  imageName: {{ .imageName }}
  plugins:
    - name: barman-cloud.cloudnative-pg.io
      {{- if ((.isWALArchiver).enabled) }}
      isWALArchiver: true
      {{- end }}
      parameters:
        barmanObjectName: {{ .recovery.s3.ObjectName | default (printf "%s-store" $.Release.Name) }}
        serverName: {{ $.Release.Name }}
  bootstrap:
    {{- if .recovery.enabled }}
    recovery:
      source: {{ $.Release.Name }}-source
      database: {{ .dbName | default $.Release.Name }}
      owner: {{ .owner | default $.Release.Name }}
    {{- else }}
    initdb:
      database: {{ .dbName | default $.Release.Name }}
      owner: {{ .owner | default $.Release.Name }}
      {{- if .secretName }}
      secret:
        name: {{ .secretName }}
      {{- end }}
    {{- end }}
  {{- if .recovery.enabled }}
  externalClusters:
    - name: {{ $.Release.Name }}-source
      plugin:
        name: {{ .recovery.plugin.Name }}
        parameters:
          barmanObjectName: {{ .recovery.s3.ObjectName }}
          serverName: {{ $.Release.Name }}
  {{- end }}
  enableSuperuserAccess: {{ .enableSuperuser | default true }}
  {{- if .superuserSecretName }}
  superuserSecret:
    name: {{ .superuserSecretName }}
  {{- end }}
  storage:
    pvcTemplate:
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: {{ .size | default "25Gi" }}
      storageClassName: {{ .storageClassName }}
      volumeMode: Filesystem
  walStorage:
    pvcTemplate:
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: {{ .walSize | default "5Gi" }}
      storageClassName: {{ .walStorageClassName | default .storageClassName }}
  primaryUpdateStrategy: unsupervised
  resources:
    requests:
      cpu: {{ .resources.requests.cpu | default "10m" }}
      memory: {{ .resources.requests.memory | default "1Gi" }}
    limits:
      memory: {{ .resources.limits.memory | default "2Gi" }}
---
{{- end }}
{{- end }}
{{- end }}
