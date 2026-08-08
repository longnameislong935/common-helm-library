{{- define "common-helm-library.extensions.pxc.secret" }}
{{- /*
  The PXC operator reads S3 credentials from the Secret named in
  spec.backup.storages.<name>.s3.credentialsSecret, and it expects EXACTLY these
  two keys:  AWS_ACCESS_KEY_ID  and  AWS_SECRET_ACCESS_KEY.

  By default this renders nothing: point s3.credentialsSecret at a Secret you
  already manage (e.g. your existing Garage credentials).

  If you'd rather have the chart create it, set pxc.s3.createSecret: true and
  supply pxc.s3.accessKeyId / pxc.s3.secretAccessKey (ideally via a secrets
  manager / SOPS, not plain values).
*/ -}}
{{- if and .Values.pxc.enabled .Values.pxc.s3.createSecret }}
{{- with .Values.pxc }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ .s3.credentialsSecret }}
  annotations:
    argocd.argoproj.io/sync-wave: {{ .s3.syncWave | default "1" | quote }}
type: Opaque
stringData:
  AWS_ACCESS_KEY_ID: {{ .s3.accessKeyId | quote }}
  AWS_SECRET_ACCESS_KEY: {{ .s3.secretAccessKey | quote }}
---
{{- end }}
{{- end }}
{{- end }}
