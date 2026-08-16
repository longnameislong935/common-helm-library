{{- define "common-helm-library.helpers.metadata.commonLabels" }}
app.kubernetes.io/name: {{ .Release.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.workload.image.tag }}
app.kubernetes.io/version: {{ . | quote }}
helm.sh/chart: {{ printf "%s-%s" $.Release.Name (. | toString | replace "+" "_") | quote }}
{{- else }}
helm.sh/chart: {{ $.Release.Name }}
{{- end }}
{{- with .Values.global.labels }}
{{- toYaml .| nindent 0 }}
{{- end }}
{{- end }}
