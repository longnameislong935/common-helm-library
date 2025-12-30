{{- define "common-helm-library.extensions.postgres.objectstore" }}
{{- if .Values.postgres.enabled }}
{{- with .Values.postgres }}
apiVersion: barmancloud.cnpg.io/v1
kind: ObjectStore
metadata:
  name: {{ .recovery.s3.ObjectName | default (printf "%s-store" $.Release.Name) }}
  annotations:
    argocd.argoproj.io/sync-wave: {{ .recovery.syncWave | default "3" | quote }}
spec:
  configuration:
    destinationPath: "s3://{{ .recovery.s3.bucket }}/backups/"
    endpointURL: {{ .s3.endpoint | quote }}
    s3Credentials:
      # If your secret doesn't have a region key, we can default it to 'us-east-1'
      region:
        name: {{ .s3.secretName }}
        key: "REGION"
      accessKeyId:
        name: {{ .s3.secretName }}
        key: "ACCESS_KEY_ID"
      secretAccessKey:
        name: {{ .s3.secretName }}
        key: "ACCESS_SECRET_KEY"
    wal:
      compression: gzip
  retentionPolicy: "30d"
{{- end }}
{{- end }}
{{- end }}