{{- define "common-helm-library.extensions.pxc.guardrailJob" }}
{{- /* Runs when preflight (gate cluster on S3 reachability) OR the restore
   guardrail (block a restore if no backup exists) is requested. Sync-wave 2 puts
   it before the cluster (wave 10), so a failure pauses cluster creation. */}}
{{- if and .Values.pxc.enabled (or .Values.pxc.s3.preflight .Values.pxc.recovery.checkExists) }}
{{- with .Values.pxc }}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ $.Release.Name }}-pxc-s3-guardrail
  annotations:
    argocd.argoproj.io/sync-wave: "2"
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
spec:
  backoffLimit: {{ .s3.preflightRetries | default 3 }}
  template:
    spec:
      containers:
        - name: checker
          image: amazon/aws-cli
          env:
            - name: PREFLIGHT
              value: {{ .s3.preflight | default false | quote }}
            - name: RECOVERY_ENABLED
              value: {{ .recovery.enabled | quote }}
            # PXC's credentialsSecret already uses the AWS_* key names aws-cli wants.
            - name: AWS_ACCESS_KEY_ID
              valueFrom: { secretKeyRef: { name: {{ .s3.credentialsSecret }}, key: AWS_ACCESS_KEY_ID } }
            - name: AWS_SECRET_ACCESS_KEY
              valueFrom: { secretKeyRef: { name: {{ .s3.credentialsSecret }}, key: AWS_SECRET_ACCESS_KEY } }
            # endpointUrl already carries the scheme, so aws-cli can use it directly.
            - name: ENDPOINT
              value: {{ .s3.endpointUrl | quote }}
            - name: BUCKET
              value: {{ .s3.bucket | quote }}
            - name: AWS_DEFAULT_REGION
              value: {{ .s3.region | default "garage" | quote }}
            # Restore-guard scope: only count backups under this prefix (empty = whole bucket).
            - name: PREFIX
              value: {{ .recovery.checkPrefix | default (.backup.prefix | default "") | quote }}
          command:
            - /bin/bash
            - -c
            - |
              set -eo pipefail

              # --- Preflight: the bucket must be reachable with these creds, or we
              #     block the sync so the cluster isn't created against a dead target.
              if [ "${PREFLIGHT}" = "true" ]; then
                echo "Preflight: checking S3 reachability at s3://${BUCKET}/ (${ENDPOINT})"
                if ! aws s3 ls "s3://${BUCKET}/" --endpoint-url "${ENDPOINT}" --no-verify-ssl >/dev/null 2>&1; then
                  echo "CRITICAL: bucket '${BUCKET}' is not reachable at ${ENDPOINT}. Blocking cluster creation."
                  exit 1
                fi
                echo "Preflight OK: bucket reachable."
              fi

              # --- Restore guard: a restore needs a base backup to exist first.
              if [ "${RECOVERY_ENABLED}" != "true" ]; then
                echo "recovery.enabled=false — no restore to guard. Done."
                exit 0
              fi

              if [ -n "${PREFIX}" ]; then
                CHECK_PATH="s3://${BUCKET}/${PREFIX%/}/"
              else
                CHECK_PATH="s3://${BUCKET}/"
              fi
              echo "Recovery requested. Checking for a backup at ${CHECK_PATH}"
              if ! LIST_OUTPUT=$(aws s3 ls "${CHECK_PATH}" --endpoint-url "${ENDPOINT}" --no-verify-ssl --recursive 2>&1); then
                echo "CRITICAL ERROR: S3 connection failed: ${LIST_OUTPUT}"
                exit 1
              fi
              if [ -n "$(echo "${LIST_OUTPUT}" | head -n 1)" ]; then
                echo "SUCCESS: Backup data found. Restore can proceed."
                exit 0
              else
                echo "CRITICAL ERROR: recovery.enabled=true but no data at ${CHECK_PATH}. Blocking sync."
                exit 1
              fi
      restartPolicy: Never
---
{{- end }}
{{- end }}
{{- end }}
