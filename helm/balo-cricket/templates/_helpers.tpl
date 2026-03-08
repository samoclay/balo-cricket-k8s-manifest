{{/*
Expand the name of the chart.
*/}}
{{- define "balo-cricket.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels applied to every resource.
*/}}
{{- define "balo-cricket.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels for the frontend.
*/}}
{{- define "balo-cricket.frontend.selectorLabels" -}}
app: balo-cricket-frontend
app.kubernetes.io/name: balo-cricket-frontend
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Selector labels for the API.
*/}}
{{- define "balo-cricket.api.selectorLabels" -}}
app: balo-cricket-api
app.kubernetes.io/name: balo-cricket-api
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Full image reference for the frontend.
*/}}
{{- define "balo-cricket.frontend.image" -}}
{{- printf "%s:%s" .Values.frontend.image.repository (.Values.frontend.image.tag | default "latest") }}
{{- end }}

{{/*
Full image reference for the API.
*/}}
{{- define "balo-cricket.api.image" -}}
{{- printf "%s:%s" .Values.api.image.repository (.Values.api.image.tag | default "latest") }}
{{- end }}
