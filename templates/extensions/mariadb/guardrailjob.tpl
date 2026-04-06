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
              valueFrom: { secretKeyRef: { name: {{ .s3.secretName }}, key: "ACCESS_KEY_ID" } }
            - name: AWS_SECRET_ACCESS_KEY
              valueFrom: { secretKeyRef: { name: {{ .s3.secretName }}, key: "ACCESS_SECRET_KEY" } }
            - name: ENDPOINT
              value: {{ .s3.endpoint | quote }}
            - name: BUCKET
              value: {{ .s3.bucket | quote }}
            - name: AWS_DEFAULT_REGION
              value: {{ .s3.region | default "garage" | quote }}
          command:
            - /bin/bash
            - -c
            - |
              set -eo pipefail  # Exit on error and ensure pipe failures are caught
              
              CHECK_PATH="s3://${BUCKET}/"
              echo "Checking S3 Bucket: ${CHECK_PATH} at ${ENDPOINT}"
              
              # Attempt to list objects. If this fails (403, 404, etc.), the script exits 1.
              if ! LIST_OUTPUT=$(aws s3 ls ${CHECK_PATH} --endpoint-url ${ENDPOINT} --no-verify-ssl --recursive 2>&1); then
                echo "-------------------------------------------------------"
                echo "CRITICAL ERROR: S3 Connection Failed!"
                echo "Error Details: ${LIST_OUTPUT}"
                echo "-------------------------------------------------------"
                exit 1
              fi

              # Check if the output is empty
              BACKUP_EXISTS=$(echo "${LIST_OUTPUT}" | head -n 1)

              if [ -n "$BACKUP_EXISTS" ]; then
                echo "RESULT: Data found in S3."
                if [ "$RECOVERY_ENABLED" = "true" ]; then
                  echo "SUCCESS: Recovery mode enabled and data exists. Proceeding..."
                  exit 0
                else
                  echo "CRITICAL ERROR: Data exists in S3 but recovery.enabled is FALSE."
                  echo "Blocking sync to prevent accidental overwrite of existing backups."
                  exit 1
                fi
              else
                echo "RESULT: No data found in S3."
                if [ "$RECOVERY_ENABLED" = "true" ]; then
                  echo "CRITICAL ERROR: recovery.enabled is TRUE but S3 bucket is empty."
                  echo "The restore would fail. Blocking sync."
                  exit 1
                else
                  echo "SUCCESS: Fresh install requested and S3 is empty. Proceeding..."
                  exit 0
                fi
              fi
      restartPolicy: Never
---
{{- end }}
{{- end }}
{{- end }}