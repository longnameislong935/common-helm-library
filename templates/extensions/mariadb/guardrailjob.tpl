{{- define "common-helm-library.extensions.mariadb.guardrailJob" }}
{{- if and .Values.mariadb.enabled .Values.mariadb.recovery.checkExists }}
{{- with .Values.mariadb }}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ $.Release.Name }}-mariadb-s3-guardrail
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
            - name: AWS_ACCESS_KEY_ID
              valueFrom: { secretKeyRef: { name: {{ .s3.secretName }}, key: {{ .s3.accessKeyIdKey | default "accessKeyId" | quote }} } }
            - name: AWS_SECRET_ACCESS_KEY
              valueFrom: { secretKeyRef: { name: {{ .s3.secretName }}, key: {{ .s3.secretAccessKeyKey | default "secretAccessKey" | quote }} } }
            # Operator wants a bare host:port endpoint; aws-cli needs a scheme,
            # so build the URL here from s3.tls (http for Garage, https otherwise).
            - name: ENDPOINT
              value: {{ printf "%s://%s" (ternary "https" "http" (.s3.tls | default false)) .s3.endpoint | quote }}
            - name: BUCKET
              value: {{ .s3.bucket | quote }}
            - name: AWS_DEFAULT_REGION
              value: {{ .s3.region | default "garage" | quote }}
            # Scope the restore check to a prefix (e.g. "physical") so continuous
            # backups elsewhere in the bucket don't count. Empty = whole bucket.
            - name: PREFIX
              value: {{ .recovery.checkPrefix | default "" | quote }}
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

              # Fresh install / normal operation: the bucket legitimately holds
              # this DB's OWN backups (physical/, binlog/, ...), so their presence
              # must NOT block the sync. Only a restore needs guarding.
              if [ "${RECOVERY_ENABLED}" != "true" ]; then
                echo "recovery.enabled=false — nothing to guard. Proceeding."
                exit 0
              fi

              # Recovery requested: a base backup MUST exist or the restore fails.
              echo "Recovery requested. Checking for a base backup at ${CHECK_PATH} (${ENDPOINT})"
              if ! LIST_OUTPUT=$(aws s3 ls "${CHECK_PATH}" --endpoint-url "${ENDPOINT}" --no-verify-ssl --recursive 2>&1); then
                echo "CRITICAL ERROR: S3 connection failed: ${LIST_OUTPUT}"
                exit 1
              fi
              if [ -n "$(echo "${LIST_OUTPUT}" | head -n 1)" ]; then
                echo "SUCCESS: Base backup found. Restore can proceed."
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