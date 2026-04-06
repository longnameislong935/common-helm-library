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

  # Explicitly set to avoid the SessionAffinity loop seen in operator logs
  service:
    type: ClusterIP
    headless: true

  # The podTemplate ensures environment variables are injected into the container 
  # and used by the Kubernetes Liveness/Readiness probes.
  podTemplate:
    spec:
      env:
        - name: MARIADB_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: {{ .rootPasswordSecretName | default (printf "%s-mariadb-root" $.Release.Name) }}
              key: root-password
      resources:
        {{- toYaml .resources | nindent 8 }}
      
      # Health checks must use the password variable to avoid "Access Denied" restarts
      livenessProbe:
        exec:
          command: ["/bin/bash", "-c", "mariadb -u root -p${MARIADB_ROOT_PASSWORD} -e 'SELECT 1;'"]
        initialDelaySeconds: 30
        periodSeconds: 10
      readinessProbe:
        exec:
          command: ["/bin/bash", "-c", "mariadb -u root -p${MARIADB_ROOT_PASSWORD} -e 'SELECT 1;'"]
        initialDelaySeconds: 15
        periodSeconds: 10

  metrics:
    enabled: true

  # Recovery/Bootstrap section
  {{- if .recovery.enabled }}
  bootstrapFrom:
    s3:
      bucket: {{ .s3.bucket }}
      endpoint: {{ .s3.endpoint }}
      region: {{ .s3.region | default "garage" }}
      credentialsSecretRef:
        name: {{ .s3.secretName }}
  {{- end }}

  storage:
    size: {{ .size | default "25Gi" }}
    storageClassName: {{ .storageClassName }}
    pvcRetentionPolicy:
      whenDeleted: Delete
      whenScaled: Delete

  myCnf: |
    [mariadb]
    bind-address=0.0.0.0
    default_storage_engine=InnoDB
    binlog_format=ROW
---
{{- end }}
{{- end }}
{{- end }}