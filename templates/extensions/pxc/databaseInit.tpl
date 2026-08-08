{{- define "common-helm-library.extensions.pxc.databaseInit" }}
{{- /* The PXC operator has no declarative "create database" (unlike CNPG/mariadb).
   When pxc.database is set, run a post-sync Job that waits for MySQL to accept
   connections, then CREATE DATABASE IF NOT EXISTS (idempotent). Runs as root
   from the operator-generated secret. */}}
{{- if and .Values.pxc.enabled .Values.pxc.database }}
{{- with .Values.pxc }}
{{- $cluster := .clusterName | default (printf "%s-pxc" $.Release.Name) }}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ $.Release.Name }}-pxc-init-db
  annotations:
    # PostSync so it runs after the cluster is applied; recreated each sync.
    argocd.argoproj.io/hook: PostSync
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
spec:
  backoffLimit: {{ .databaseInitRetries | default 10 }}
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: init-db
          image: {{ .databaseInitImage | default "mysql:8.4" }}
          env:
            - name: DB_HOST
              value: {{ printf "%s-haproxy" $cluster }}
            - name: DB_NAME
              value: {{ .database | quote }}
            # MYSQL_PWD is read by the mysql client, keeping the password off argv.
            - name: MYSQL_PWD
              valueFrom:
                secretKeyRef:
                  name: {{ .secretsName | default (printf "%s-secrets" $cluster) }}
                  key: root
          command:
            - /bin/sh
            - -c
            - |
              set -e
              echo "Waiting for MySQL at ${DB_HOST}:3306 ..."
              i=0
              until mysql -h "${DB_HOST}" -uroot -e "SELECT 1" >/dev/null 2>&1; do
                i=$((i+1))
                if [ $i -gt 60 ]; then echo "Timed out waiting for MySQL"; exit 1; fi
                sleep 5
              done
              echo "Ensuring database '${DB_NAME}' exists ..."
              mysql -h "${DB_HOST}" -uroot -e \
                "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
              echo "Database '${DB_NAME}' ensured."
---
{{- end }}
{{- end }}
{{- end }}
