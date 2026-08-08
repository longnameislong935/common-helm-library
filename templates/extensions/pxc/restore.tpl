{{- define "common-helm-library.extensions.pxc.restore" }}
{{- if and .Values.pxc.enabled .Values.pxc.recovery.enabled }}
{{- with .Values.pxc }}
apiVersion: pxc.percona.com/v1
kind: PerconaXtraDBClusterRestore
metadata:
  name: {{ printf "%s-pxc-restore" $.Release.Name }}
  annotations:
    argocd.argoproj.io/sync-wave: {{ .recovery.syncWave | default "10" | quote }}
spec:
  pxcCluster: {{ .clusterName | default (printf "%s-pxc" $.Release.Name) }}
  {{- if .recovery.backupName }}
  # Restore from an existing PerconaXtraDBClusterBackup object.
  backupName: {{ .recovery.backupName }}
  {{- else }}
  # Restore straight from object storage (no Backup object needed).
  backupSource:
    verifyTLS: {{ .s3.verifyTLS | default false }}
    destination: {{ printf "s3://%s/%s" .s3.bucket .recovery.backupDestination }}
    s3:
      bucket: {{ .s3.bucket }}
      credentialsSecret: {{ .s3.credentialsSecret }}
      region: {{ .s3.region | default "garage" }}
      endpointUrl: {{ .s3.endpointUrl }}
  {{- end }}
  {{- if .recovery.pitr.enabled }}
  # Point-in-time recovery: replay binlogs from the dedicated binlog storage.
  pitr:
    # type: latest | date | transaction
    type: {{ .recovery.pitr.type | default "latest" }}
    {{- if .recovery.pitr.date }}
    date: {{ .recovery.pitr.date | quote }}
    {{- end }}
    {{- if .recovery.pitr.gtid }}
    gtid: {{ .recovery.pitr.gtid | quote }}
    {{- end }}
    backupSource:
      verifyTLS: {{ .s3.verifyTLS | default false }}
      storageName: {{ .pitr.storageName | default "s3-binlog" }}
      s3:
        bucket: {{ .pitr.bucket | default .s3.bucket }}
        credentialsSecret: {{ .s3.credentialsSecret }}
        region: {{ .s3.region | default "garage" }}
        endpointUrl: {{ .s3.endpointUrl }}
  {{- end }}
---
{{- end }}
{{- end }}
{{- end }}
