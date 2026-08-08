{{- define "common-helm-library.extensions.pxc.guardrailJob" }}
{{- if and .Values.pxc.enabled .Values.pxc.recovery.checkExists }}
{{- with .Values.pxc }}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ $.Release.Name }}-pxc-s3-guardrail
  annotations:
    argocd.argoproj.io/sync-wave: "2"
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
spec:
  template:
    spec:
      containers:
        - name: checker
          image: amazon/aws-cli
          env:
            - name: RECOVERY_ENABLED
              value: {{ .recovery.enabled | quote }}
            # PXC's credentialsSecret already uses the AWS_* key names aws-cli wants.
            - name: AWS_ACCESS_KEY_ID
              valueFrom: { secretKeyRef: { name: {{ .s3.credentialsSecret }}, key: AWS_ACCESS_KEY_ID } }
            - name: AWS_SECRET_ACCESS_KEY
              valueFrom: { secretKeyRef: { name: {{ .s3.credentialsSecret }}, key: AWS_SECRET_ACCESS_KEY } }
            # PXC endpointUrl already carries the scheme, so aws-cli can use it directly.
            - name: ENDPOINT
              value: {{ .s3.endpointUrl | quote }}
            - name: BUCKET
              value: {{ .s3.bucket | quote }}
            - name: AWS_DEFAULT_REGION
              value: {{ .s3.region | default "garage" | quote }}
            # Scope the "does a backup exist?" check to a prefix (e.g. the full-backup
            # prefix) so unrelated data in the bucket doesn't count. Empty = whole bucket.
            - name: PREFIX
              value: {{ .recovery.checkPrefix | default (.backup.prefix | default "") | quote }}
          command:
            - /bin/bash
            - -c
            - |
              set -eo pipefail

              if [ -n "${PREFIX}" ]; then
                CHECK_PATH="s3://${BUCKET}/${PREFIX%/}/"
              else
                CHECK_PATH="s3://${BUCKET}/"
              fi

              # Fresh install / normal operation: the bucket legitimately holds this
              # cluster's OWN backups, so their presence must NOT block the sync.
              # Only a restore needs guarding.
              if [ "${RECOVERY_ENABLED}" != "true" ]; then
                echo "recovery.enabled=false — nothing to guard. Proceeding."
                exit 0
              fi

              echo "Recovery requested. Checking for a backup at ${CHECK_PATH} (${ENDPOINT})"
              if ! LIST_OUTPUT=$(aws s3 ls "${CHECK_PATH}" --endpoint-url "${ENDPOINT}" --no-verify-ssl --recursive 2>&1); then
                echo "CRITICAL ERROR: S3 connection failed: ${LIST_OUTPUT}"
                exit 1
              fi
              if [ -n "$(echo "${LIST_OUTPUT}" | head -n 1)" ]; then
                echo "SUCCESS: Backup data found. Restore can proceed."
                exit 0
              else
                echo "CRITICAL ERROR: recovery.enabled=true but no data at ${CHECK_PATH}."
                echo "The restore would fail. Blocking sync."
                exit 1
              fi
      restartPolicy: Never
---
{{- end }}
{{- end }}
{{- end }}
