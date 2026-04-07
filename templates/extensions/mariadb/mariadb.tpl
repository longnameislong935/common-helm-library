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
  # This is the instruction for the Operator to auto-generate the password
  rootPasswordSecretKeyRef:
    name: {{ .rootPasswordSecretName | default (printf "%s-mariadb-root" $.Release.Name) }}
    key: root-password
    generate: true

  image: {{ .imageName | default "mariadb:11.4" }}
  replicas: {{ .replicas | default 1 }}
  database: {{ .dbName | default "netlockrmm" }}

  # Resources are typically top-level in the v1alpha1 spec
  resources:
    {{- toYaml .resources | nindent 4 }}

  # Since you have a separate storage.tpl, ensure your MariaDB CR 
  # references the existing volume or uses the same storageClassName.
  storage:
    storageClassName: {{ .storageClassName }}
    size: {{ .size | default "25Gi" }}

  myCnf: |
    [mariadb]
    bind-address=0.0.0.0
    default_storage_engine=InnoDB
    binlog_format=ROW
---
{{- end }}
{{- end }}
{{- end }}