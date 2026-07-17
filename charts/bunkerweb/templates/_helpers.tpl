{{/*
Expand the name of the chart.
*/}}
{{- define "bunkerweb.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "bunkerweb.fullname" -}}
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

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "bunkerweb.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "bunkerweb.labels" -}}
helm.sh/chart: {{ include "bunkerweb.chart" . }}
{{ include "bunkerweb.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "bunkerweb.selectorLabels" -}}
app.kubernetes.io/name: {{ include "bunkerweb.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Expand the namespace of the release.
Allows overriding it for multi-namespace deployments in combined charts.
*/}}
{{- define "bunkerweb.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
DATABASE_URI setting
*/}}
{{- define "bunkerweb.databaseUri" -}}
{{- if .Values.mariadb.enabled -}}
  {{- $user := .Values.mariadb.config.user -}}
  {{- $password := .Values.mariadb.config.password -}}
  {{- $host := printf "mariadb-%s.%s.svc.%s" (include "bunkerweb.fullname" .) (include "bunkerweb.namespace" .) .Values.settings.kubernetes.domainName -}}
  {{- $db := .Values.mariadb.config.database -}}
  {{- printf "mariadb+pymysql://%s:%s@%s:3306/%s" $user $password $host $db -}}
{{- else -}}
  {{- .Values.settings.misc.databaseUri -}}
{{- end -}}
{{- end -}}

{{- /*
REDIS settings
*/}}
{{- define "bunkerweb.redisEnv" -}}
{{- if and .Values.redis.enabled .Values.settings.redis.redisSentinelHosts }}
{{- fail "settings.redis.redisSentinelHosts requires redis.enabled=false (use an external Redis/Sentinel cluster, not the bundled Redis)." }}
{{- end }}
{{- if eq .Values.settings.redis.useRedis "yes" }}
- name: USE_REDIS
  value: "yes"
{{- end }}
{{- if .Values.redis.enabled }}
- name: REDIS_HOST
  {{- if .Values.settings.redis.redisHost }}
  value: "{{ .Values.settings.redis.redisHost }}"
  {{- else }}
  value: "redis-{{ include "bunkerweb.fullname" . }}.{{ include "bunkerweb.namespace" . }}.svc.{{ .Values.settings.kubernetes.domainName }}"
  {{- end }}
- name: REDIS_USERNAME
  value: ""
- name: REDIS_PASSWORD
  {{- if not (empty .Values.settings.existingSecret) }}
  valueFrom:
    secretKeyRef:
      name: "{{ .Values.settings.existingSecret }}"
      key: redis-password
  {{- else }}
  value: "{{ .Values.redis.config.password }}"
  {{- end }}
{{- else }}
{{- if or .Values.settings.redis.redisHost (not .Values.settings.redis.redisSentinelHosts) }}
- name: REDIS_HOST
  value: "{{ .Values.settings.redis.redisHost }}"
{{- end }}
- name: REDIS_USERNAME
    {{- if not (empty .Values.settings.existingSecret) }}
  valueFrom:
    secretKeyRef:
      name: "{{ .Values.settings.existingSecret }}"
      key: redis-username
    {{- else }}
  value: "{{ .Values.settings.redis.redisUsername }}"
    {{- end }}
- name: REDIS_PASSWORD
    {{- if not (empty .Values.settings.existingSecret) }}
  valueFrom:
    secretKeyRef:
      name: "{{ .Values.settings.existingSecret }}"
      key: redis-password
    {{- else }}
  value: "{{ .Values.settings.redis.redisPassword }}"
    {{- end }}
{{- end }}
{{- /* Optional connection knobs (only emitted when set) */}}
{{- if .Values.settings.redis.redisPort }}
- name: REDIS_PORT
  value: "{{ .Values.settings.redis.redisPort }}"
{{- end }}
{{- if .Values.settings.redis.redisDatabase }}
- name: REDIS_DATABASE
  value: "{{ .Values.settings.redis.redisDatabase }}"
{{- end }}
{{- if .Values.settings.redis.redisSsl }}
- name: REDIS_SSL
  value: "{{ .Values.settings.redis.redisSsl }}"
{{- end }}
{{- if .Values.settings.redis.redisSslVerify }}
- name: REDIS_SSL_VERIFY
  value: "{{ .Values.settings.redis.redisSslVerify }}"
{{- end }}
{{- if .Values.settings.redis.redisTimeout }}
- name: REDIS_TIMEOUT
  value: "{{ .Values.settings.redis.redisTimeout }}"
{{- end }}
{{- /* Redis Sentinel (high availability). When set, the master is resolved via the Sentinels. */}}
{{- if .Values.settings.redis.redisSentinelHosts }}
- name: REDIS_SENTINEL_HOSTS
  value: "{{ .Values.settings.redis.redisSentinelHosts }}"
{{- if .Values.settings.redis.redisSentinelMaster }}
- name: REDIS_SENTINEL_MASTER
  value: "{{ .Values.settings.redis.redisSentinelMaster }}"
{{- end }}
- name: REDIS_SENTINEL_USERNAME
  {{- if not (empty .Values.settings.existingSecret) }}
  valueFrom:
    secretKeyRef:
      name: "{{ .Values.settings.existingSecret }}"
      key: redis-sentinel-username
      optional: true
  {{- else }}
  value: "{{ .Values.settings.redis.redisSentinelUsername }}"
  {{- end }}
- name: REDIS_SENTINEL_PASSWORD
  {{- if not (empty .Values.settings.existingSecret) }}
  valueFrom:
    secretKeyRef:
      name: "{{ .Values.settings.existingSecret }}"
      key: redis-sentinel-password
      optional: true
  {{- else }}
  value: "{{ .Values.settings.redis.redisSentinelPassword }}"
  {{- end }}
{{- end }}
{{- end }}

{{/*
Whether the external API component must run.
True when the API is explicitly enabled, or when MCP is enabled and points at
the internal API (mcp.config.bunkerwebBaseUrl empty) — MCP depends on it.
*/}}
{{- define "bunkerweb.apiEnabled" -}}
{{- if or .Values.api.enabled (and .Values.mcp.enabled (empty .Values.mcp.config.bunkerwebBaseUrl)) -}}
true
{{- end -}}
{{- end -}}

{{/*
Whether any API authentication method is configured.
*/}}
{{- define "bunkerweb.apiAuthConfigured" -}}
{{- $s := .Values.settings.api -}}
{{- $hasToken := or (and $s.useBearerToken.fromExistingSecret (not (empty .Values.settings.existingSecret))) (and (not $s.useBearerToken.fromExistingSecret) (not (empty $s.useBearerToken.token))) -}}
{{- $hasUserPass := or (and $s.useUserPass.fromExistingSecret (not (empty .Values.settings.existingSecret))) (and (not $s.useUserPass.fromExistingSecret) (not (empty $s.useUserPass.apiUsername)) (not (empty $s.useUserPass.apiPassword))) -}}
{{- $hasAcl := not (empty $s.apiAclBootstrapFile) -}}
{{- if or $hasToken $hasUserPass $hasAcl -}}
true
{{- end -}}
{{- end -}}

{{/*
Pod nodeSelector + tolerations, component value with fallback to the global one.
Usage: {{- include "bunkerweb.podNodeTolerations" (dict "comp" .Values.<component> "root" .Values) }}
*/}}
{{- define "bunkerweb.podNodeTolerations" -}}
{{- $c := .comp -}}
{{- $r := .root -}}
    {{- if $c.nodeSelector }}
      {{- with $c.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
    {{- else if $r.nodeSelector }}
      {{- with $r.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
    {{- end }}
    {{- if or ($c.tolerations) ($r.tolerations) }}
      tolerations:
      {{- if $c.tolerations }}
        {{- toYaml $c.tolerations | nindent 6 }}
      {{- else }}
        {{- toYaml $r.tolerations | nindent 6 }}
      {{- end }}
    {{- end }}
{{- end -}}

{{/*
Pod imagePullSecrets, component value with fallback to the global one.
Usage: {{- include "bunkerweb.podImagePullSecrets" (dict "comp" .Values.<component> "root" .Values) }}
*/}}
{{- define "bunkerweb.podImagePullSecrets" -}}
{{- $c := .comp -}}
{{- $r := .root -}}
    {{- if or ($c.imagePullSecrets) ($r.imagePullSecrets) }}
      imagePullSecrets:
      {{- if $c.imagePullSecrets }}
        {{- toYaml $c.imagePullSecrets | nindent 6 }}
      {{- else }}
        {{- toYaml $r.imagePullSecrets | nindent 6 }}
      {{- end }}
    {{- end }}
{{- end -}}

{{/*
Emit a `- name/value` container env entry when the value is truthy (non-empty
string / non-zero number). Collapses the repeated feature-env blocks.
Usage: {{- include "bunkerweb.envVar" (dict "name" "ENV_NAME" "value" <expr>) }}
The caller passes the value pre-guarded (e.g. `(and .parent .parent.field)`) so
nil-parent short-circuiting is preserved.
*/}}
{{- define "bunkerweb.envVar" -}}
{{- if .value }}
- name: {{ .name }}
  value: {{ .value | quote }}
{{- end }}
{{- end -}}

{{/*
Emit a secret-backed env var: valueFrom.secretKeyRef when an existingSecret is
set, otherwise a plain value when truthy. Collapses the repeated
existingSecret-or-plain feature env blocks.
Usage: {{- include "bunkerweb.secretOrValue" (dict "name" "ENV" "secret" <existingSecret> "key" "secret-key" "optional" true "value" <plainExpr>) }}
*/}}
{{- define "bunkerweb.secretOrValue" -}}
{{- if not (empty .secret) }}
- name: {{ .name }}
  valueFrom:
    secretKeyRef:
      name: "{{ .secret }}"
      key: {{ .key }}
{{- if .optional }}
      optional: true
{{- end }}
{{- else if .value }}
- name: {{ .name }}
  value: {{ .value | quote }}
{{- end }}
{{- end -}}

{{/*
Syslog log env vars (LOG_TYPES/LOG_SYSLOG_ADDRESS) shared by the api, ui,
scheduler and controller deployments. Indentation is baked at 12 spaces; call
as {{- include "bunkerweb.logEnvs" . }} with no nindent.
*/}}
{{- define "bunkerweb.logEnvs" -}}
{{- if .Values.ui.logs.enabled }}
            - name: LOG_TYPES
              value: "stderr syslog"
            - name: LOG_SYSLOG_ADDRESS
              value: "{{ include "bunkerweb.syslogAddress" . }}"
{{- end }}
{{- end -}}

{{/*
Common BunkerWeb container env preamble shared by the Deployment, DaemonSet and
StatefulSet workloads. Emit at col 0; the caller applies `| nindent 12`.
*/}}
{{- define "bunkerweb.commonEnv" -}}
# Mandatory for k8s integration
- name: KUBERNETES_MODE
  value: "yes"
# DNS resolver
- name: DNS_RESOLVERS
  value: "{{ .Values.settings.misc.dnsResolvers }}"
# Internal subnet(s) + localhost
- name: API_WHITELIST_IP
  value: "{{ .Values.settings.misc.apiWhitelistIp }}"
{{- include "bunkerweb.redisEnv" . | nindent 0 }}
{{- if .Values.ui.logs.enabled }}
- name: ACCESS_LOG_1
  value: "syslog:server={{ include "bunkerweb.syslogAddress" . }},tag=bunkerweb_access"
- name: ERROR_LOG_1
  value: "syslog:server={{ include "bunkerweb.syslogAddress" . }},tag=bunkerweb"
{{- end }}
{{- end -}}

{{/*
Generate BunkerWeb feature environment variables
*/}}
{{- define "bunkerweb.featureEnvs" -}}
{{- with .Values.scheduler.features }}
# =============================================================================
# GLOBAL SETTINGS
# =============================================================================
{{- include "bunkerweb.envVar" (dict "name" "SECURITY_MODE" "value" (and .global.securityMode)) }}
{{- include "bunkerweb.envVar" (dict "name" "DISABLE_DEFAULT_SERVER" "value" (and .global.disableDefaultServer)) }}
{{- include "bunkerweb.envVar" (dict "name" "DISABLE_DEFAULT_SERVER_STRICT_SNI" "value" (and .global.disableDefaultServerStrictSni)) }}
{{- include "bunkerweb.envVar" (dict "name" "MAX_HEADERS" "value" (and .global.maxHeaders)) }}
{{- include "bunkerweb.envVar" (dict "name" "WORKER_SHUTDOWN_TIMEOUT" "value" (and .global.workerShutdownTimeout)) }}

# =============================================================================
# NGINX TIMEOUTS
# =============================================================================
{{- include "bunkerweb.envVar" (dict "name" "CLIENT_BODY_TIMEOUT" "value" (and .timeouts .timeouts.clientBodyTimeout)) }}
{{- include "bunkerweb.envVar" (dict "name" "CLIENT_HEADER_TIMEOUT" "value" (and .timeouts .timeouts.clientHeaderTimeout)) }}
{{- include "bunkerweb.envVar" (dict "name" "KEEPALIVE_TIMEOUT" "value" (and .timeouts .timeouts.keepaliveTimeout)) }}
{{- include "bunkerweb.envVar" (dict "name" "SEND_TIMEOUT" "value" (and .timeouts .timeouts.sendTimeout)) }}

# =============================================================================
# DATABASE CONNECTION POOL
# =============================================================================
{{- include "bunkerweb.envVar" (dict "name" "DATABASE_POOL_SIZE" "value" (and .databasePool .databasePool.databasePoolSize)) }}
{{- include "bunkerweb.envVar" (dict "name" "DATABASE_POOL_MAX_OVERFLOW" "value" (and .databasePool .databasePool.databasePoolMaxOverflow)) }}
{{- include "bunkerweb.envVar" (dict "name" "DATABASE_POOL_TIMEOUT" "value" (and .databasePool .databasePool.databasePoolTimeout)) }}
{{- include "bunkerweb.envVar" (dict "name" "DATABASE_POOL_RECYCLE" "value" (and .databasePool .databasePool.databasePoolRecycle)) }}
{{- include "bunkerweb.envVar" (dict "name" "DATABASE_POOL_PRE_PING" "value" (and .databasePool .databasePool.databasePoolPrePing)) }}
{{- include "bunkerweb.envVar" (dict "name" "DATABASE_POOL_RESET_ON_RETURN" "value" (and .databasePool .databasePool.databasePoolResetOnReturn)) }}
{{- include "bunkerweb.envVar" (dict "name" "DATABASE_RETRY_TIMEOUT" "value" (and .databasePool .databasePool.databaseRetryTimeout)) }}
{{- include "bunkerweb.envVar" (dict "name" "DATABASE_REQUEST_RETRY_ATTEMPTS" "value" (and .databasePool .databasePool.databaseRequestRetryAttempts)) }}
{{- include "bunkerweb.envVar" (dict "name" "DATABASE_REQUEST_RETRY_DELAY" "value" (and .databasePool .databasePool.databaseRequestRetryDelay)) }}

# =============================================================================
# MODSECURITY WAF
# =============================================================================
{{- include "bunkerweb.envVar" (dict "name" "USE_MODSECURITY" "value" (and .modsecurity .modsecurity.useModsecurity)) }}
{{- include "bunkerweb.envVar" (dict "name" "USE_MODSECURITY_CRS" "value" (and .modsecurity .modsecurity.useModsecurityCrs)) }}
{{- include "bunkerweb.envVar" (dict "name" "MODSECURITY_CRS_VERSION" "value" (and .modsecurity .modsecurity.modsecurityCrsVersion)) }}
{{- include "bunkerweb.envVar" (dict "name" "MODSECURITY_SEC_RULE_ENGINE" "value" (and .modsecurity .modsecurity.modsecuritySecRuleEngine)) }}
{{- include "bunkerweb.envVar" (dict "name" "USE_MODSECURITY_CRS_PLUGINS" "value" (and .modsecurity .modsecurity.useModsecurityCrsPlugins)) }}
{{- include "bunkerweb.envVar" (dict "name" "MODSECURITY_CRS_PLUGINS" "value" (and .modsecurity .modsecurity.modsecurityCrsPlugins)) }}
{{- include "bunkerweb.envVar" (dict "name" "MODSECURITY_SEC_REQUEST_BODY_LIMIT" "value" (and .modsecurity .modsecurity.modsecuritySecRequestBodyLimit)) }}
{{- include "bunkerweb.envVar" (dict "name" "MODSECURITY_SEC_REQUEST_BODY_LIMIT_ACTION" "value" (and .modsecurity .modsecurity.modsecuritySecRequestBodyLimitAction)) }}

# =============================================================================
# ANTIBOT PROTECTION
# =============================================================================
{{- include "bunkerweb.envVar" (dict "name" "USE_ANTIBOT" "value" (and .antibot .antibot.useAntibot)) }}
{{- include "bunkerweb.envVar" (dict "name" "ANTIBOT_URI" "value" (and .antibot .antibot.antibotUri)) }}
{{- include "bunkerweb.envVar" (dict "name" "ANTIBOT_TIME_RESOLVE" "value" (and .antibot .antibot.antibotTimeResolve)) }}
{{- include "bunkerweb.envVar" (dict "name" "ANTIBOT_TIME_VALID" "value" (and .antibot .antibot.antibotTimeValid)) }}
{{- include "bunkerweb.envVar" (dict "name" "ANTIBOT_IGNORE_IP" "value" (and .antibot .antibot.antibotIgnoreIp)) }}
{{- include "bunkerweb.envVar" (dict "name" "ANTIBOT_IGNORE_URI" "value" (and .antibot .antibot.antibotIgnoreUri)) }}
{{- include "bunkerweb.envVar" (dict "name" "ANTIBOT_RECAPTCHA_CLASSIC" "value" (and .antibot .antibot.antibotRecaptchaClassic)) }}
{{- include "bunkerweb.envVar" (dict "name" "ANTIBOT_RDNS_GLOBAL" "value" (and .antibot .antibot.antibotRdnsGlobal)) }}
{{- include "bunkerweb.envVar" (dict "name" "ANTIBOT_SUCCESS_URI" "value" (and .antibot .antibot.antibotSuccessUri)) }}

# =============================================================================
# RATE LIMITING
# =============================================================================
{{- include "bunkerweb.envVar" (dict "name" "USE_LIMIT_REQ" "value" (and .rateLimit .rateLimit.useLimitReq)) }}
{{- include "bunkerweb.envVar" (dict "name" "LIMIT_REQ_RATE" "value" (and .rateLimit .rateLimit.limitReqRate)) }}
{{- include "bunkerweb.envVar" (dict "name" "LIMIT_REQ_URL" "value" (and .rateLimit .rateLimit.limitReqUrl)) }}
{{- include "bunkerweb.envVar" (dict "name" "USE_LIMIT_CONN" "value" (and .rateLimit .rateLimit.useLimitConn)) }}
{{- include "bunkerweb.envVar" (dict "name" "LIMIT_CONN_MAX_HTTP1" "value" (and .rateLimit .rateLimit.limitConnMaxHttp1)) }}
{{- include "bunkerweb.envVar" (dict "name" "LIMIT_CONN_MAX_HTTP2" "value" (and .rateLimit .rateLimit.limitConnMaxHttp2)) }}
{{- include "bunkerweb.envVar" (dict "name" "LIMIT_CONN_MAX_HTTP3" "value" (and .rateLimit .rateLimit.limitConnMaxHttp3)) }}
{{- include "bunkerweb.envVar" (dict "name" "USE_LIMIT_REQ_GLOBAL" "value" (and .rateLimit .rateLimit.useLimitReqGlobal)) }}
{{- include "bunkerweb.envVar" (dict "name" "LIMIT_REQ_GLOBAL_RATE" "value" (and .rateLimit .rateLimit.limitReqGlobalRate)) }}

# =============================================================================
# BLACKLIST/WHITELIST
# =============================================================================
{{- include "bunkerweb.envVar" (dict "name" "USE_BLACKLIST" "value" (and .blacklist .blacklist.useBlacklist)) }}
{{- include "bunkerweb.envVar" (dict "name" "BLACKLIST_COMMUNITY_LISTS" "value" (and .blacklist .blacklist.blacklistCommunityLists)) }}
{{- include "bunkerweb.envVar" (dict "name" "BLACKLIST_IP" "value" (and .blacklist .blacklist.blacklistIp)) }}
{{- include "bunkerweb.envVar" (dict "name" "BLACKLIST_IP_URLS" "value" (and .blacklist .blacklist.blacklistIpUrls)) }}

{{- include "bunkerweb.envVar" (dict "name" "USE_WHITELIST" "value" (and .whitelist .whitelist.useWhitelist)) }}
{{- include "bunkerweb.envVar" (dict "name" "WHITELIST_IP" "value" (and .whitelist .whitelist.whitelistIp)) }}
{{- include "bunkerweb.envVar" (dict "name" "WHITELIST_IP_URLS" "value" (and .whitelist .whitelist.whitelistIpUrls)) }}

# =============================================================================
# COUNTRY BLOCKING
# =============================================================================
{{- include "bunkerweb.envVar" (dict "name" "WHITELIST_COUNTRY" "value" (and .geoBlocking .geoBlocking.whitelistCountry)) }}
{{- include "bunkerweb.envVar" (dict "name" "BLACKLIST_COUNTRY" "value" (and .geoBlocking .geoBlocking.blacklistCountry)) }}
{{- include "bunkerweb.envVar" (dict "name" "COUNTRY_IGNORE_URI" "value" (and .geoBlocking .geoBlocking.countryIgnoreUri)) }}

# =============================================================================
# BAD BEHAVIOR DETECTION
# =============================================================================
{{- include "bunkerweb.envVar" (dict "name" "USE_BAD_BEHAVIOR" "value" (and .badBehavior .badBehavior.useBadBehavior)) }}
{{- include "bunkerweb.envVar" (dict "name" "BAD_BEHAVIOR_STATUS_CODES" "value" (and .badBehavior .badBehavior.badBehaviorStatusCodes)) }}
{{- include "bunkerweb.envVar" (dict "name" "BAD_BEHAVIOR_THRESHOLD" "value" (and .badBehavior .badBehavior.badBehaviorThreshold)) }}
{{- include "bunkerweb.envVar" (dict "name" "BAD_BEHAVIOR_COUNT_TIME" "value" (and .badBehavior .badBehavior.badBehaviorCountTime)) }}
{{- include "bunkerweb.envVar" (dict "name" "BAD_BEHAVIOR_BAN_TIME" "value" (and .badBehavior .badBehavior.badBehaviorBanTime)) }}

# =============================================================================
# SSL/TLS CONFIGURATION
# =============================================================================
{{- include "bunkerweb.envVar" (dict "name" "LISTEN_HTTPS" "value" (and .ssl .ssl.listenHttps)) }}
{{- include "bunkerweb.envVar" (dict "name" "SSL_PROTOCOLS" "value" (and .ssl .ssl.sslProtocols)) }}
{{- include "bunkerweb.envVar" (dict "name" "SSL_CIPHERS_LEVEL" "value" (and .ssl .ssl.sslCiphersLevel)) }}
{{- include "bunkerweb.envVar" (dict "name" "AUTO_REDIRECT_HTTP_TO_HTTPS" "value" (and .ssl .ssl.autoRedirectHttpToHttps)) }}

# Let's Encrypt configuration
{{- include "bunkerweb.envVar" (dict "name" "AUTO_LETS_ENCRYPT" "value" (and .letsEncrypt .letsEncrypt.autoLetsEncrypt)) }}
{{- include "bunkerweb.envVar" (dict "name" "EMAIL_LETS_ENCRYPT" "value" (and .letsEncrypt .letsEncrypt.emailLetsEncrypt)) }}
{{- include "bunkerweb.envVar" (dict "name" "LETS_ENCRYPT_CHALLENGE" "value" (and .letsEncrypt .letsEncrypt.letsEncryptChallenge)) }}
{{- include "bunkerweb.envVar" (dict "name" "LETS_ENCRYPT_DNS_PROVIDER" "value" (and .letsEncrypt .letsEncrypt.letsEncryptDnsProvider)) }}
{{- include "bunkerweb.envVar" (dict "name" "USE_LETS_ENCRYPT_WILDCARD" "value" (and .letsEncrypt .letsEncrypt.useLetsEncryptWildcard)) }}
{{- include "bunkerweb.envVar" (dict "name" "LETS_ENCRYPT_SERVER" "value" (and .letsEncrypt .letsEncrypt.letsEncryptServer)) }}
{{- include "bunkerweb.envVar" (dict "name" "LETS_ENCRYPT_PROFILE" "value" (and .letsEncrypt .letsEncrypt.letsEncryptProfile)) }}
{{- include "bunkerweb.envVar" (dict "name" "LETS_ENCRYPT_CUSTOM_PROFILE" "value" (and .letsEncrypt .letsEncrypt.letsEncryptCustomProfile)) }}
{{- include "bunkerweb.secretOrValue" (dict "name" "LETS_ENCRYPT_ZEROSSL_API_KEY" "secret" $.Values.settings.existingSecret "key" "zerossl-api-key" "optional" true "value" (and .letsEncrypt .letsEncrypt.letsEncryptZerosslApiKey)) }}
{{- include "bunkerweb.envVar" (dict "name" "LETS_ENCRYPT_ZEROSSL_API_CONNECT_TIMEOUT" "value" (and .letsEncrypt .letsEncrypt.letsEncryptZerosslApiConnectTimeout)) }}
{{- include "bunkerweb.envVar" (dict "name" "LETS_ENCRYPT_ZEROSSL_API_MAX_TIME" "value" (and .letsEncrypt .letsEncrypt.letsEncryptZerosslApiMaxTime)) }}
{{- include "bunkerweb.envVar" (dict "name" "LETS_ENCRYPT_ZEROSSL_API_RETRY" "value" (and .letsEncrypt .letsEncrypt.letsEncryptZerosslApiRetry)) }}
{{- include "bunkerweb.envVar" (dict "name" "LETS_ENCRYPT_ZEROSSL_API_RETRY_DELAY" "value" (and .letsEncrypt .letsEncrypt.letsEncryptZerosslApiRetryDelay)) }}
{{- include "bunkerweb.envVar" (dict "name" "LETS_ENCRYPT_MAX_LOG_BACKUPS" "value" (and .letsEncrypt .letsEncrypt.letsEncryptMaxLogBackups)) }}

# Custom SSL certificate
{{- include "bunkerweb.envVar" (dict "name" "USE_CUSTOM_SSL" "value" (and .customSsl .customSsl.useCustomSsl)) }}
{{- include "bunkerweb.envVar" (dict "name" "CUSTOM_SSL_CERT_PRIORITY" "value" (and .customSsl .customSsl.customSslCertPriority)) }}
{{- include "bunkerweb.envVar" (dict "name" "CUSTOM_SSL_CERT" "value" (and .customSsl .customSsl.customSslCert)) }}
{{- include "bunkerweb.secretOrValue" (dict "name" "CUSTOM_SSL_KEY" "secret" $.Values.settings.existingSecret "key" "custom-ssl-key" "optional" true "value" (and .customSsl .customSsl.customSslKey)) }}


# =============================================================================
# COMPRESSION
# =============================================================================
{{- include "bunkerweb.envVar" (dict "name" "USE_GZIP" "value" (and .compression .compression.useGzip)) }}
{{- include "bunkerweb.envVar" (dict "name" "GZIP_COMP_LEVEL" "value" (and .compression .compression.gzipCompLevel)) }}
{{- include "bunkerweb.envVar" (dict "name" "GZIP_MIN_LENGTH" "value" (and .compression .compression.gzipMinLength)) }}

{{- include "bunkerweb.envVar" (dict "name" "USE_BROTLI" "value" (and .compression .compression.useBrotli)) }}
{{- include "bunkerweb.envVar" (dict "name" "BROTLI_COMP_LEVEL" "value" (and .compression .compression.brotliCompLevel)) }}

# =============================================================================
# CLIENT CACHING
# =============================================================================
{{- include "bunkerweb.envVar" (dict "name" "USE_CLIENT_CACHE" "value" (and .clientCache .clientCache.useClientCache)) }}
{{- include "bunkerweb.envVar" (dict "name" "CLIENT_CACHE_EXTENSIONS" "value" (and .clientCache .clientCache.clientCacheExtensions)) }}
{{- include "bunkerweb.envVar" (dict "name" "CLIENT_CACHE_CONTROL" "value" (and .clientCache .clientCache.clientCacheControl)) }}
{{- include "bunkerweb.envVar" (dict "name" "CLIENT_CACHE_ETAG" "value" (and .clientCache .clientCache.clientCacheEtag)) }}

# =============================================================================
# REVERSE PROXY
# =============================================================================
{{- include "bunkerweb.envVar" (dict "name" "USE_REVERSE_PROXY" "value" (and .reverseProxy .reverseProxy.useReverseProxy)) }}
{{- include "bunkerweb.envVar" (dict "name" "REVERSE_PROXY_HOST" "value" (and .reverseProxy .reverseProxy.reverseProxyHost)) }}
{{- include "bunkerweb.envVar" (dict "name" "REVERSE_PROXY_URL" "value" (and .reverseProxy .reverseProxy.reverseProxyUrl)) }}
{{- include "bunkerweb.envVar" (dict "name" "REVERSE_PROXY_CONNECT_TIMEOUT" "value" (and .reverseProxy .reverseProxy.reverseProxyConnectTimeout)) }}
{{- include "bunkerweb.envVar" (dict "name" "REVERSE_PROXY_SEND_TIMEOUT" "value" (and .reverseProxy .reverseProxy.reverseProxySendTimeout)) }}
{{- include "bunkerweb.envVar" (dict "name" "REVERSE_PROXY_READ_TIMEOUT" "value" (and .reverseProxy .reverseProxy.reverseProxyReadTimeout)) }}
{{- include "bunkerweb.envVar" (dict "name" "REVERSE_PROXY_KEEPALIVE" "value" (and .reverseProxy .reverseProxy.reverseProxyKeepalive)) }}
{{- include "bunkerweb.envVar" (dict "name" "REVERSE_PROXY_HTTP_VERSION" "value" (and .reverseProxy .reverseProxy.reverseProxyHttpVersion)) }}
{{- include "bunkerweb.envVar" (dict "name" "REVERSE_PROXY_MODSECURITY" "value" (and .reverseProxy .reverseProxy.reverseProxyModsecurity)) }}
{{- include "bunkerweb.envVar" (dict "name" "REVERSE_PROXY_SSL_VERIFY" "value" (and .reverseProxy .reverseProxy.reverseProxySslVerify)) }}
{{- /* toString: this value is numeric, and `ne <int> ""` is a template error. */}}
{{- include "bunkerweb.envVar" (dict "name" "REVERSE_PROXY_SSL_VERIFY_DEPTH" "value" (and .reverseProxy .reverseProxy.reverseProxySslVerifyDepth)) }}
{{- include "bunkerweb.envVar" (dict "name" "REVERSE_PROXY_SSL_TRUSTED_CERTIFICATE" "value" (and .reverseProxy .reverseProxy.reverseProxySslTrustedCertificate)) }}

# =============================================================================
# GRPC REVERSE PROXY
# =============================================================================
{{- include "bunkerweb.envVar" (dict "name" "USE_GRPC" "value" (and .grpc .grpc.useGrpc)) }}
{{- include "bunkerweb.envVar" (dict "name" "GRPC_URL" "value" (and .grpc .grpc.grpcUrl)) }}
{{- include "bunkerweb.envVar" (dict "name" "GRPC_HOST" "value" (and .grpc .grpc.grpcHost)) }}
{{- include "bunkerweb.envVar" (dict "name" "GRPC_CONNECT_TIMEOUT" "value" (and .grpc .grpc.grpcConnectTimeout)) }}
{{- include "bunkerweb.envVar" (dict "name" "GRPC_READ_TIMEOUT" "value" (and .grpc .grpc.grpcReadTimeout)) }}
{{- include "bunkerweb.envVar" (dict "name" "GRPC_SEND_TIMEOUT" "value" (and .grpc .grpc.grpcSendTimeout)) }}
{{- include "bunkerweb.envVar" (dict "name" "GRPC_CUSTOM_HOST" "value" (and .grpc .grpc.grpcCustomHost)) }}
{{- include "bunkerweb.envVar" (dict "name" "GRPC_HEADERS" "value" (and .grpc .grpc.grpcHeaders)) }}
{{- include "bunkerweb.envVar" (dict "name" "GRPC_HIDE_HEADERS" "value" (and .grpc .grpc.grpcHideHeaders)) }}
{{- include "bunkerweb.envVar" (dict "name" "GRPC_INTERCEPT_ERRORS" "value" (and .grpc .grpc.grpcInterceptErrors)) }}
{{- include "bunkerweb.envVar" (dict "name" "GRPC_SOCKET_KEEPALIVE" "value" (and .grpc .grpc.grpcSocketKeepalive)) }}
{{- include "bunkerweb.envVar" (dict "name" "GRPC_SSL_SNI" "value" (and .grpc .grpc.grpcSslSni)) }}
{{- include "bunkerweb.envVar" (dict "name" "GRPC_SSL_SNI_NAME" "value" (and .grpc .grpc.grpcSslSniName)) }}
{{- include "bunkerweb.envVar" (dict "name" "GRPC_NEXT_UPSTREAM" "value" (and .grpc .grpc.grpcNextUpstream)) }}
{{- include "bunkerweb.envVar" (dict "name" "GRPC_NEXT_UPSTREAM_TIMEOUT" "value" (and .grpc .grpc.grpcNextUpstreamTimeout)) }}
{{- include "bunkerweb.envVar" (dict "name" "GRPC_NEXT_UPSTREAM_TRIES" "value" (and .grpc .grpc.grpcNextUpstreamTries)) }}
{{- include "bunkerweb.envVar" (dict "name" "GRPC_INCLUDES" "value" (and .grpc .grpc.grpcIncludes)) }}

# =============================================================================
# REAL IP DETECTION
# =============================================================================
{{- include "bunkerweb.envVar" (dict "name" "USE_REAL_IP" "value" (and .realIp .realIp.useRealIp)) }}
{{- include "bunkerweb.envVar" (dict "name" "REAL_IP_FROM" "value" (and .realIp .realIp.realIpFrom)) }}
{{- include "bunkerweb.envVar" (dict "name" "REAL_IP_HEADER" "value" (and .realIp .realIp.realIpHeader)) }}
{{- include "bunkerweb.envVar" (dict "name" "REAL_IP_RECURSIVE" "value" (and .realIp .realIp.realIpRecursive)) }}
{{- include "bunkerweb.envVar" (dict "name" "USE_PROXY_PROTOCOL" "value" (and .realIp .realIp.useProxyProtocol)) }}

# =============================================================================
# SECURITY HEADERS
# =============================================================================
{{- include "bunkerweb.envVar" (dict "name" "STRICT_TRANSPORT_SECURITY" "value" (and .headers .headers.strictTransportSecurity)) }}
{{- include "bunkerweb.envVar" (dict "name" "CONTENT_SECURITY_POLICY" "value" (and .headers .headers.contentSecurityPolicy)) }}
{{- include "bunkerweb.envVar" (dict "name" "CONTENT_SECURITY_POLICY_REPORT_ONLY" "value" (and .headers .headers.contentSecurityPolicyReportOnly)) }}
{{- include "bunkerweb.envVar" (dict "name" "X_FRAME_OPTIONS" "value" (and .headers .headers.xFrameOptions)) }}
{{- include "bunkerweb.envVar" (dict "name" "X_CONTENT_TYPE_OPTIONS" "value" (and .headers .headers.xContentTypeOptions)) }}
{{- include "bunkerweb.envVar" (dict "name" "REFERRER_POLICY" "value" (and .headers .headers.referrerPolicy)) }}
{{- include "bunkerweb.envVar" (dict "name" "REMOVE_HEADERS" "value" (and .headers .headers.removeHeaders)) }}
{{- include "bunkerweb.envVar" (dict "name" "CUSTOM_HEADER" "value" (and .headers .headers.customHeader)) }}

# =============================================================================
# CORS CONFIGURATION
# =============================================================================
{{- include "bunkerweb.envVar" (dict "name" "USE_CORS" "value" (and .cors .cors.useCors)) }}
{{- include "bunkerweb.envVar" (dict "name" "CORS_ALLOW_ORIGIN" "value" (and .cors .cors.corsAllowOrigin)) }}
{{- include "bunkerweb.envVar" (dict "name" "CORS_ALLOW_METHODS" "value" (and .cors .cors.corsAllowMethods)) }}
{{- include "bunkerweb.envVar" (dict "name" "CORS_ALLOW_HEADERS" "value" (and .cors .cors.corsAllowHeaders)) }}
{{- include "bunkerweb.envVar" (dict "name" "CORS_ALLOW_CREDENTIALS" "value" (and .cors .cors.corsAllowCredentials)) }}

# =============================================================================
# DNSBL CHECKING
# =============================================================================
{{- include "bunkerweb.envVar" (dict "name" "USE_DNSBL" "value" (and .dnsbl .dnsbl.useDnsbl)) }}
{{- include "bunkerweb.envVar" (dict "name" "DNSBL_LIST" "value" (and .dnsbl .dnsbl.dnsblList)) }}

# =============================================================================
# BUNKERNET THREAT INTELLIGENCE
# =============================================================================
{{- include "bunkerweb.envVar" (dict "name" "USE_BUNKERNET" "value" (and .bunkerNet .bunkerNet.useBunkernet)) }}
{{- include "bunkerweb.envVar" (dict "name" "BUNKERNET_SERVER" "value" (and .bunkerNet .bunkerNet.bunkernetServer)) }}

# =============================================================================
# SESSION MANAGEMENT
# =============================================================================
{{- include "bunkerweb.secretOrValue" (dict "name" "SESSIONS_SECRET" "secret" $.Values.settings.existingSecret "key" "sessions-secret" "optional" true "value" (and .sessions .sessions.sessionsSecret)) }}
{{- include "bunkerweb.envVar" (dict "name" "SESSIONS_NAME" "value" (and .sessions .sessions.sessionsName)) }}
{{- include "bunkerweb.envVar" (dict "name" "SESSIONS_IDLING_TIMEOUT" "value" (and .sessions .sessions.sessionsIdlingTimeout)) }}
{{- include "bunkerweb.envVar" (dict "name" "SESSIONS_ROLLING_TIMEOUT" "value" (and .sessions .sessions.sessionsRollingTimeout)) }}
{{- include "bunkerweb.envVar" (dict "name" "SESSIONS_ABSOLUTE_TIMEOUT" "value" (and .sessions .sessions.sessionsAbsoluteTimeout)) }}
{{- include "bunkerweb.envVar" (dict "name" "SESSIONS_CHECK_IP" "value" (and .sessions .sessions.sessionsCheckIp)) }}
{{- include "bunkerweb.envVar" (dict "name" "SESSIONS_CHECK_USER_AGENT" "value" (and .sessions .sessions.sessionsCheckUserAgent)) }}
{{- include "bunkerweb.envVar" (dict "name" "SESSIONS_DOMAIN" "value" (and .sessions .sessions.sessionsDomain)) }}

# =============================================================================
# METRICS AND MONITORING
# =============================================================================
{{- include "bunkerweb.envVar" (dict "name" "USE_METRICS" "value" (and .metrics .metrics.useMetrics)) }}
{{- include "bunkerweb.envVar" (dict "name" "METRICS_MEMORY_SIZE" "value" (and .metrics .metrics.metricsMemorySize)) }}
{{- include "bunkerweb.envVar" (dict "name" "METRICS_MAX_BLOCKED_REQUESTS" "value" (and .metrics .metrics.metricsMaxBlockedRequests)) }}
{{- include "bunkerweb.envVar" (dict "name" "METRICS_MAX_BLOCKED_REQUESTS_REDIS" "value" (and .metrics .metrics.metricsMaxBlockedRequestsRedis)) }}
{{- include "bunkerweb.envVar" (dict "name" "METRICS_SAVE_TO_REDIS" "value" (and .metrics .metrics.metricsSaveToRedis)) }}
{{- include "bunkerweb.envVar" (dict "name" "MAX_LRU_HISTORY" "value" (and .metrics .metrics.maxLruHistory)) }}
{{- include "bunkerweb.envVar" (dict "name" "DATASTORE_LRU_SIZE" "value" (and .metrics .metrics.datastoreLruSize)) }}

# =============================================================================
# AUTH BASIC
# =============================================================================
{{- include "bunkerweb.envVar" (dict "name" "USE_AUTH_BASIC" "value" (and .authBasic .authBasic.useAuthBasic)) }}
{{- include "bunkerweb.envVar" (dict "name" "AUTH_BASIC_LOCATION" "value" (and .authBasic .authBasic.authBasicLocation)) }}
{{- include "bunkerweb.envVar" (dict "name" "AUTH_BASIC_USER" "value" (and .authBasic .authBasic.authBasicUser)) }}
{{- include "bunkerweb.secretOrValue" (dict "name" "AUTH_BASIC_PASSWORD" "secret" $.Values.settings.existingSecret "key" "auth-basic-password" "optional" true "value" (and .authBasic .authBasic.authBasicPassword)) }}
{{- include "bunkerweb.envVar" (dict "name" "AUTH_BASIC_TEXT" "value" (and .authBasic .authBasic.authBasicText)) }}

# =============================================================================
# REDIRECTS
# =============================================================================
{{- include "bunkerweb.envVar" (dict "name" "REDIRECT_FROM" "value" .redirect.redirectFrom) }}
{{- include "bunkerweb.envVar" (dict "name" "REDIRECT_TO" "value" .redirect.redirectTo) }}
{{- include "bunkerweb.envVar" (dict "name" "REDIRECT_TO_REQUEST_URI" "value" .redirect.redirectToRequestUri) }}
{{- include "bunkerweb.envVar" (dict "name" "REDIRECT_TO_STATUS_CODE" "value" .redirect.redirectToStatusCode) }}

# =============================================================================
# ERROR PAGES
# =============================================================================
{{- include "bunkerweb.envVar" (dict "name" "ERRORS" "value" .errors.errors) }}
{{- include "bunkerweb.envVar" (dict "name" "INTERCEPTED_ERROR_CODES" "value" .errors.interceptedErrorCodes) }}

# =============================================================================
# HTML INJECTION
# =============================================================================
{{- include "bunkerweb.envVar" (dict "name" "INJECT_HEAD" "value" .htmlInjection.injectHead) }}
{{- include "bunkerweb.envVar" (dict "name" "INJECT_BODY" "value" .htmlInjection.injectBody) }}

# =============================================================================
# ROBOTS.TXT
# =============================================================================
{{- include "bunkerweb.envVar" (dict "name" "USE_ROBOTSTXT" "value" (and .robotsTxt .robotsTxt.useRobotsTxt)) }}
{{- include "bunkerweb.secretOrValue" (dict "name" "ROBOTSTXT_DARKVISITORS_TOKEN" "secret" $.Values.settings.existingSecret "key" "darkvisitors-token" "optional" true "value" (and .robotsTxt .robotsTxt.robotsTxtDarkvisitorsToken)) }}
{{- include "bunkerweb.envVar" (dict "name" "ROBOTSTXT_COMMUNITY_LISTS" "value" (and .robotsTxt .robotsTxt.robotsTxtCommunityLists)) }}
{{- include "bunkerweb.envVar" (dict "name" "ROBOTSTXT_RULE" "value" (and .robotsTxt .robotsTxt.robotsTxtRule)) }}
{{- include "bunkerweb.envVar" (dict "name" "ROBOTSTXT_SITEMAP" "value" (and .robotsTxt .robotsTxt.robotsTxtSitemap)) }}

# =============================================================================
# SECURITY.TXT
# =============================================================================
{{- include "bunkerweb.envVar" (dict "name" "USE_SECURITYTXT" "value" (and .securityTxt .securityTxt.useSecurityTxt)) }}
{{- include "bunkerweb.envVar" (dict "name" "SECURITYTXT_CONTACT" "value" (and .securityTxt .securityTxt.securityTxtContact)) }}
{{- include "bunkerweb.envVar" (dict "name" "SECURITYTXT_EXPIRES" "value" (and .securityTxt .securityTxt.securityTxtExpires)) }}
{{- include "bunkerweb.envVar" (dict "name" "SECURITYTXT_POLICY" "value" (and .securityTxt .securityTxt.securityTxtPolicy)) }}

# =============================================================================
# CROWDSEC INTEGRATION
# =============================================================================
{{- include "bunkerweb.envVar" (dict "name" "USE_CROWDSEC" "value" (and .crowdSec .crowdSec.useCrowdSec)) }}
{{- include "bunkerweb.envVar" (dict "name" "CROWDSEC_API" "value" (and .crowdSec .crowdSec.crowdSecApi)) }}
{{- include "bunkerweb.secretOrValue" (dict "name" "CROWDSEC_API_KEY" "secret" $.Values.settings.existingSecret "key" "crowdsec-api-key" "optional" true "value" (and .crowdSec .crowdSec.crowdSecApiKey)) }}
{{- include "bunkerweb.envVar" (dict "name" "CROWDSEC_MODE" "value" (and .crowdSec .crowdSec.crowdSecMode)) }}
{{- include "bunkerweb.envVar" (dict "name" "CROWDSEC_APPSEC_URL" "value" (and .crowdSec .crowdSec.crowdSecAppsecUrl)) }}

# =============================================================================
# PHP INTEGRATION
# =============================================================================
{{- include "bunkerweb.envVar" (dict "name" "REMOTE_PHP" "value" (and .php .php.remotePhp)) }}
{{- include "bunkerweb.envVar" (dict "name" "REMOTE_PHP_PORT" "value" (and .php .php.remotePhpPort)) }}
{{- include "bunkerweb.envVar" (dict "name" "REMOTE_PHP_PATH" "value" (and .php .php.remotephpPath)) }}
{{- include "bunkerweb.envVar" (dict "name" "LOCAL_PHP" "value" (and .php .php.localPhp)) }}
{{- include "bunkerweb.envVar" (dict "name" "LOCAL_PHP_PATH" "value" (and .php .php.localPhpPath)) }}

# =============================================================================
# GREYLIST (CONDITIONAL ACCESS)
# =============================================================================
{{- include "bunkerweb.envVar" (dict "name" "USE_GREYLIST" "value" (and .greylist .greylist.useGreylist)) }}
{{- include "bunkerweb.envVar" (dict "name" "GREYLIST_IP" "value" (and .greylist .greylist.greylistIp)) }}
{{- include "bunkerweb.envVar" (dict "name" "GREYLIST_IP_URLS" "value" (and .greylist .greylist.greylistIpUrls)) }}

# =============================================================================
# REVERSE SCAN
# =============================================================================
{{- include "bunkerweb.envVar" (dict "name" "USE_REVERSE_SCAN" "value" (and .reverseScan .reverseScan.useReverseScan)) }}
{{- include "bunkerweb.envVar" (dict "name" "REVERSE_SCAN_PORTS" "value" (and .reverseScan .reverseScan.reverseScanPorts)) }}
{{- include "bunkerweb.envVar" (dict "name" "REVERSE_SCAN_TIMEOUT" "value" (and .reverseScan .reverseScan.reverseScanTimeout)) }}

# =============================================================================
# BACKUP CONFIGURATION
# =============================================================================
{{- include "bunkerweb.envVar" (dict "name" "USE_BACKUP" "value" (and .backup .backup.useBackup)) }}
{{- include "bunkerweb.envVar" (dict "name" "BACKUP_SCHEDULE" "value" (and .backup .backup.backupSchedule)) }}
{{- include "bunkerweb.envVar" (dict "name" "BACKUP_ROTATION" "value" (and .backup .backup.backupRotation)) }}
{{- include "bunkerweb.envVar" (dict "name" "BACKUP_DIRECTORY" "value" (and .backup .backup.backupDirectory)) }}

# =============================================================================
# STREAM/PASSTHROUGH
# =============================================================================
{{- include "bunkerweb.envVar" (dict "name" "LISTEN_STREAM" "value" (and .stream .stream.listenStream)) }}
{{- include "bunkerweb.envVar" (dict "name" "LISTEN_STREAM_PORT" "value" (and .stream .stream.listenStreamPort)) }}
{{- include "bunkerweb.envVar" (dict "name" "LISTEN_STREAM_PORT_SSL" "value" (and .stream .stream.listenStreamPortSsl)) }}
{{- end }}
{{- end }}

{{/*
Syslog address for UI logs
Returns the configured syslog address if set, otherwise the UI sidecar service address
*/}}
{{- define "bunkerweb.syslogAddress" -}}
{{- if .Values.ui.logs.syslogAddress -}}
  {{- .Values.ui.logs.syslogAddress -}}
{{- else -}}
  {{- printf "ui-%s.%s.svc.%s:514" (include "bunkerweb.fullname" .) (include "bunkerweb.namespace" .) .Values.settings.kubernetes.domainName -}}
{{- end -}}
{{- end -}}