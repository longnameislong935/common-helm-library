{{- define "common-helm-library.extensions.pxc.backup" }}
{{- if and .Values.pxc.enabled .Values.pxc.onDemandBackup.enabled }}
{{- with .Values.pxc }}
apiVersion: pxc.percona.com/v1
kind: PerconaXtraDBClusterBackup
metadata:
  name: {{ printf "%s-pxc-backup" $.Release.Name }}
  annotations:
    argocd.argoproj.io/sync-wave: {{ .onDemandBackup.syncWave | default "11" | quote }}
spec:
  pxcCluster: {{ .clusterName | default (printf "%s-pxc" $.Release.Name) }}
  storageName: {{ .onDemandBackup.storageName | default (.backup.storageName | default "s3-backup") }}
---
{{- end }}
{{- end }}
{{- end }}
