{{- define "common-helm-library.extensions.pxc.cluster" }}
{{- if .Values.pxc.enabled }}
{{- with .Values.pxc }}
apiVersion: pxc.percona.com/v1
kind: PerconaXtraDBCluster
metadata:
  name: {{ .clusterName | default (printf "%s-pxc" $.Release.Name) }}
  annotations:
    argocd.argoproj.io/sync-wave: {{ .syncWave | default "10" | quote }}
  finalizers:
    - percona.com/delete-pxc-pods-in-order
spec:
  crVersion: {{ .crVersion | default "1.20.0" }}
  {{- if .secretsName }}
  secretsName: {{ .secretsName }}
  {{- end }}
  updateStrategy: {{ .updateStrategy | default "SmartUpdate" }}
  upgradeOptions:
    apply: {{ .upgradeApply | default "disabled" }}
    schedule: {{ .upgradeSchedule | default "0 4 * * *" | quote }}
    versionServiceEndpoint: {{ .versionServiceEndpoint | default "https://check.percona.com" }}

  # --- TLS ---
  tls:
    enabled: {{ .tls.enabled | default true }}

  {{- /* Galera wants >=3 PXC nodes and >=2 proxy nodes. Any smaller (single-node
     dev) needs the matching unsafeFlags toggles or the operator refuses. */}}
  {{- if .unsafeFlags }}
  unsafeFlags:
    {{- toYaml .unsafeFlags | nindent 4 }}
  {{- end }}

  # --- PXC (Galera) nodes ---
  pxc:
    size: {{ .pxc.size | default 3 }}
    image: {{ .pxc.image | default "percona/percona-xtradb-cluster:8.4.8-8.1" }}
    autoRecovery: {{ .pxc.autoRecovery | default true }}
    {{- if .pxc.configuration }}
    configuration: |
      {{- .pxc.configuration | nindent 6 }}
    {{- end }}
    resources:
      {{- toYaml (.pxc.resources | default (dict)) | nindent 6 }}
    affinity:
      antiAffinityTopologyKey: {{ .pxc.antiAffinityTopologyKey | default "kubernetes.io/hostname" | quote }}
      {{- with .pxc.nodeAffinity }}
      advanced:
        nodeAffinity:
          {{- toYaml . | nindent 10 }}
      {{- end }}
    podDisruptionBudget:
      maxUnavailable: {{ .pxc.pdbMaxUnavailable | default 1 }}
    volumeSpec:
      persistentVolumeClaim:
        {{- if .pxc.storageClassName }}
        storageClassName: {{ .pxc.storageClassName }}
        {{- end }}
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: {{ .pxc.storage | default "8Gi" }}
    gracePeriod: {{ .pxc.gracePeriod | default 600 }}
    {{- /* mysqld_exporter sidecar so vmagent's pod-SD can scrape MySQL metrics
       on 9104 (no PMM needed). Uses the operator-managed `monitor` user. */}}
    {{- if .metrics.mysqld.enabled }}
    sidecars:
      - name: mysqld-exporter
        image: {{ .metrics.mysqld.image | default "prom/mysqld-exporter:v0.15.1" }}
        ports:
          - containerPort: {{ .metrics.mysqld.port | default 9104 }}
            name: metrics
        env:
          - name: MYSQLD_EXPORTER_PASSWORD
            valueFrom:
              secretKeyRef:
                name: {{ .secretsName | default (printf "%s-secrets" (.clusterName | default (printf "%s-pxc" $.Release.Name))) }}
                key: monitor
        args:
          - "--mysqld.username=monitor"
          - "--mysqld.address=localhost:3306"
          {{- range .metrics.mysqld.extraArgs }}
          - {{ . | quote }}
          {{- end }}
        resources:
          {{- toYaml (.metrics.mysqld.resources | default (dict "requests" (dict "cpu" "25m" "memory" "32Mi") "limits" (dict "memory" "64Mi"))) | nindent 10 }}
    {{- end }}

  # --- Proxy layer: HAProxy (default) or ProxySQL ---
  haproxy:
    enabled: {{ .haproxy.enabled | default true }}
    size: {{ .haproxy.size | default 2 }}
    image: {{ .haproxy.image | default "percona/haproxy:2.8.18-1" }}
    resources:
      {{- toYaml (.haproxy.resources | default (dict)) | nindent 6 }}
    affinity:
      antiAffinityTopologyKey: {{ .haproxy.antiAffinityTopologyKey | default "kubernetes.io/hostname" | quote }}
    podDisruptionBudget:
      maxUnavailable: {{ .haproxy.pdbMaxUnavailable | default 1 }}
    gracePeriod: {{ .haproxy.gracePeriod | default 30 }}

  proxysql:
    enabled: {{ .proxysql.enabled | default false }}
    {{- if .proxysql.enabled }}
    size: {{ .proxysql.size | default 2 }}
    image: {{ .proxysql.image | default "percona/proxysql2:2.7.3-1.3" }}
    resources:
      {{- toYaml (.proxysql.resources | default (dict)) | nindent 6 }}
    affinity:
      antiAffinityTopologyKey: {{ .proxysql.antiAffinityTopologyKey | default "kubernetes.io/hostname" | quote }}
    volumeSpec:
      persistentVolumeClaim:
        {{- if .proxysql.storageClassName }}
        storageClassName: {{ .proxysql.storageClassName }}
        {{- end }}
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: {{ .proxysql.storage | default "2Gi" }}
    {{- end }}

  # --- Log collector ---
  logcollector:
    enabled: {{ .logcollector.enabled | default true }}
    image: {{ .logcollector.image | default "percona/fluentbit:5.0.6-1" }}

  # --- PMM (metrics agent; needs a PMM server) ---
  {{- if .pmm.enabled }}
  pmm:
    enabled: true
    image: {{ .pmm.image | default "percona/pmm-client:3.8.0" }}
    serverHost: {{ .pmm.serverHost | quote }}
  {{- end }}

  # --- Backups (XtraBackup -> S3/Garage) ---
  backup:
    image: {{ .backupImage | default "percona/percona-xtrabackup:8.4.0-5.1" }}

    storages:
      {{- /* Full-backup storage. endpointUrl carries the scheme (http:// for
         plain-HTTP Garage); forcePathStyle is required for Garage/MinIO. */}}
      {{ .backup.storageName | default "s3-backup" }}:
        type: s3
        verifyTLS: {{ .s3.verifyTLS | default false }}
        s3:
          bucket: {{ .s3.bucket }}
          credentialsSecret: {{ .s3.credentialsSecret }}
          region: {{ .s3.region | default "garage" }}
          endpointUrl: {{ .s3.endpointUrl }}
          forcePathStyle: {{ .s3.forcePathStyle | default true }}
          {{- if .backup.prefix }}
          prefix: {{ .backup.prefix }}
          {{- end }}
      {{- /* PITR needs its own dedicated binlog storage, separate from full
         backups (same bucket is fine as long as the prefix differs). */}}
      {{- if .pitr.enabled }}
      {{ .pitr.storageName | default "s3-binlog" }}:
        type: s3
        verifyTLS: {{ .s3.verifyTLS | default false }}
        s3:
          bucket: {{ .pitr.bucket | default .s3.bucket }}
          credentialsSecret: {{ .s3.credentialsSecret }}
          region: {{ .s3.region | default "garage" }}
          endpointUrl: {{ .s3.endpointUrl }}
          forcePathStyle: {{ .s3.forcePathStyle | default true }}
          prefix: {{ .pitr.prefix | default "binlog" }}
      {{- end }}

    # --- Point-in-time recovery: continuous binlog upload ---
    {{- if .pitr.enabled }}
    pitr:
      enabled: true
      storageName: {{ .pitr.storageName | default "s3-binlog" }}
      timeBetweenUploads: {{ .pitr.timeBetweenUploads | default 60 }}
      timeoutSeconds: {{ .pitr.timeoutSeconds | default 60 }}
    {{- end }}

    # --- Scheduled full backups ---
    {{- if .backup.enabled }}
    schedule:
      {{- if .backup.schedules }}
      {{- toYaml .backup.schedules | nindent 6 }}
      {{- else }}
      - name: {{ .backup.name | default "daily-backup" | quote }}
        schedule: {{ .backup.schedule | default "0 0 * * *" | quote }}
        storageName: {{ .backup.storageName | default "s3-backup" }}
        {{- /* Retention is INCOMPATIBLE with PITR: deleting full backups breaks
           the binlog chain. When pitr is on, omit retention and rely on a Garage
           bucket lifecycle rule for cleanup instead. */}}
        {{- if not .pitr.enabled }}
        retention:
          type: count
          count: {{ .backup.retentionCount | default 5 }}
          deleteFromStorage: {{ .backup.deleteFromStorage | default true }}
        {{- end }}
      {{- end }}
    {{- end }}
---
{{- end }}
{{- end }}
{{- end }}
