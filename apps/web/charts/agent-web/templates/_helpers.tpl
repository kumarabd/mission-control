{{- define "agent-web.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "agent-web.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "agent-web.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end }}

{{- define "agent-web.labels" -}}
helm.sh/chart: {{ include "agent-web.chart" . }}
{{ include "agent-web.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "agent-web.selectorLabels" -}}
app.kubernetes.io/name: {{ include "agent-web.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "agent-web.image" -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion -}}
{{ printf "%s/%s:%s" .Values.image.registry .Values.image.repository $tag }}
{{- end }}

{{- define "agent-web.dockerBuildArgs" -}}
{{- $key := .Values.image.buildArgs.viteClerkPublishableKey | default .Values.frontend.clerkPublishableKey | default "" -}}
--build-arg VITE_CLERK_PUBLISHABLE_KEY={{ $key }}
{{- end }}
