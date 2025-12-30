{{- define "common-helm-library.extensions.postgres.guardrailJob" }}
{{- if and .Values.postgres.enabled .Values.postgres.recovery.checkExists }}
{{- with .Values.postgres }}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ $.Release.Name }}-s3-guardrail
  annotations:
    argocd.argoproj.io/sync-wave: "2"
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
spec:
  template:
    spec:
      serviceAccountName: {{ .recovery.serviceAccountName | default (printf "%s-checker" $.Release.Name) }}
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
            - name: CHECK_PATH
              value: "s3://{{ .recovery.s3.bucket }}/backups/{{ $.Release.Name }}/base/"
          command:
            - /bin/bash
            - -c
            - |
              echo "Checking path: ${CHECK_PATH}"
              # We use --recursive and pipe to head to see if ANY files exist in the base backup folder
              BACKUP_EXISTS=$(aws s3 ls ${CHECK_PATH} --endpoint-url ${ENDPOINT} --no-verify-ssl --recursive | head -n 1)

              if [ -n "$BACKUP_EXISTS" ]; then
                echo "RESULT: Data found in S3."
                if [ "$RECOVERY_ENABLED" = "true" ]; then
                  echo "SUCCESS: Recovery mode enabled and data exists. Proceeding..."
                  exit 0
                else
                  echo "CRITICAL ERROR: Data exists in S3 at ${CHECK_PATH} but recovery.enabled is FALSE."
                  echo "To protect existing data, the sync has been blocked."
                  exit 1
                fi
              else
                echo "RESULT: No data found in S3 at ${CHECK_PATH}."
                if [ "$RECOVERY_ENABLED" = "true" ]; then
                  echo "CRITICAL ERROR: recovery.enabled is TRUE but no backup was found at ${CHECK_PATH}."
                  echo "The cluster would fail to bootstrap. Sync blocked."
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