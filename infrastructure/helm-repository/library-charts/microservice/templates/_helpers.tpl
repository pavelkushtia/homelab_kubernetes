{{/*
Common labels
*/}}
{{- define "microservice.labels" -}}
app.kubernetes.io/name: {{ .Values.name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Values.image.tag | default .Chart.AppVersion }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: {{ .Values.partOf | default .Release.Name }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "microservice.selectorLabels" -}}
app.kubernetes.io/name: {{ .Values.name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Service template
*/}}
{{- define "microservice.service" -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ .Values.name }}
  namespace: {{ .Values.namespace | default .Release.Namespace }}
  labels:
    {{- include "microservice.labels" . | nindent 4 }}
    component: {{ .Values.component | default "backend" }}
spec:
  type: {{ .Values.service.type | default "ClusterIP" }}
  ports:
  - port: {{ .Values.service.port | default 80 }}
    targetPort: {{ .Values.service.targetPort | default 8080 }}
    protocol: TCP
    name: http
    {{- if and (eq (.Values.service.type | default "ClusterIP") "NodePort") .Values.service.nodePort }}
    nodePort: {{ .Values.service.nodePort }}
    {{- end }}
  selector:
    {{- include "microservice.selectorLabels" . | nindent 4 }}
    component: {{ .Values.component | default "backend" }}
{{- end }}

{{/*
ServiceAccount template
*/}}
{{- define "microservice.serviceAccount" -}}
{{- if .Values.serviceAccount.create }}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ .Values.serviceAccount.name | default .Values.name }}
  namespace: {{ .Values.namespace | default .Release.Namespace }}
  labels:
    {{- include "microservice.labels" . | nindent 4 }}
  {{- with .Values.serviceAccount.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
HorizontalPodAutoscaler template
*/}}
{{- define "microservice.hpa" -}}
{{- if .Values.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ .Values.name }}
  namespace: {{ .Values.namespace | default .Release.Namespace }}
  labels:
    {{- include "microservice.labels" . | nindent 4 }}
    component: {{ .Values.component | default "backend" }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ .Values.name }}
  minReplicas: {{ .Values.autoscaling.minReplicas | default 1 }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas | default 3 }}
  metrics:
  {{- if .Values.autoscaling.targetCPUUtilizationPercentage }}
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
  {{- end }}
  {{- if .Values.autoscaling.targetMemoryUtilizationPercentage }}
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: {{ .Values.autoscaling.targetMemoryUtilizationPercentage }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
ConfigMap template
*/}}
{{- define "microservice.configmap" -}}
{{- if .Values.configMap.data }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Values.name }}-config
  namespace: {{ .Values.namespace | default .Release.Namespace }}
  labels:
    {{- include "microservice.labels" . | nindent 4 }}
data:
  {{- toYaml .Values.configMap.data | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Secret template
*/}}
{{- define "microservice.secret" -}}
{{- if .Values.secret.data }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ .Values.name }}-secret
  namespace: {{ .Values.namespace | default .Release.Namespace }}
  labels:
    {{- include "microservice.labels" . | nindent 4 }}
type: Opaque
data:
  {{- range $key, $value := .Values.secret.data }}
  {{ $key }}: {{ $value | b64enc }}
  {{- end }}
{{- end }}
{{- end }} 