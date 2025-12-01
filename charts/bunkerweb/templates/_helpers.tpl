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
UI_HOST setting
*/}}
{{- define "bunkerweb.uiHost" -}}
{{- printf "http://ui-%s.%s.svc.%s:7000" (include "bunkerweb.fullname" .) (include "bunkerweb.namespace" .) .Values.settings.kubernetes.domainName -}}
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
- name: REDIS_HOST
  value: "{{ .Values.settings.redis.redisHost }}"
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
{{- end }}

{{/*
Generate BunkerWeb feature environment variables
*/}}
{{- define "bunkerweb.featureEnvs" -}}
{{- with .Values.scheduler.features }}
# =============================================================================
# GLOBAL SETTINGS
# =============================================================================
{{- if and .global.securityMode (ne .global.securityMode "") }}
- name: SECURITY_MODE
  value: {{ .global.securityMode | quote }}
{{- end }}
{{- if and .global.disableDefaultServer (ne .global.disableDefaultServer "") }}
- name: DISABLE_DEFAULT_SERVER
  value: {{ .global.disableDefaultServer | quote }}
{{- end }}
{{- if and .global.disableDefaultServerStrictSni (ne .global.disableDefaultServerStrictSni "") }}
- name: DISABLE_DEFAULT_SERVER_STRICT_SNI
  value: {{ .global.disableDefaultServerStrictSni | quote }}
{{- end }}

# =============================================================================
# MODSECURITY WAF
# =============================================================================
{{- if and .modsecurity .modsecurity.useModsecurity (ne .modsecurity.useModsecurity "") }}
- name: USE_MODSECURITY
  value: {{ .modsecurity.useModsecurity | quote }}
{{- end }}
{{- if and .modsecurity .modsecurity.useModsecurityCrs (ne .modsecurity.useModsecurityCrs "") }}
- name: USE_MODSECURITY_CRS
  value: {{ .modsecurity.useModsecurityCrs | quote }}
{{- end }}
{{- if and .modsecurity .modsecurity.modsecurityCrsVersion (ne .modsecurity.modsecurityCrsVersion "") }}
- name: MODSECURITY_CRS_VERSION
  value: {{ .modsecurity.modsecurityCrsVersion | quote }}
{{- end }}
{{- if and .modsecurity .modsecurity.modsecuritySecRuleEngine (ne .modsecurity.modsecuritySecRuleEngine "") }}
- name: MODSECURITY_SEC_RULE_ENGINE
  value: {{ .modsecurity.modsecuritySecRuleEngine | quote }}
{{- end }}
{{- if and .modsecurity .modsecurity.useModsecurityCrsPlugins (ne .modsecurity.useModsecurityCrsPlugins "") }}
- name: USE_MODSECURITY_CRS_PLUGINS
  value: {{ .modsecurity.useModsecurityCrsPlugins | quote }}
{{- end }}
{{- if and .modsecurity .modsecurity.modsecurityCrsPlugins (ne .modsecurity.modsecurityCrsPlugins "") }}
- name: MODSECURITY_CRS_PLUGINS
  value: {{ .modsecurity.modsecurityCrsPlugins | quote }}
{{- end }}

# =============================================================================
# ANTIBOT PROTECTION  
# =============================================================================
{{- if and .antibot .antibot.useAntibot (ne .antibot.useAntibot "") }}
- name: USE_ANTIBOT
  value: {{ .antibot.useAntibot | quote }}
{{- end }}
{{- if and .antibot .antibot.antibotUri (ne .antibot.antibotUri "") }}
- name: ANTIBOT_URI
  value: {{ .antibot.antibotUri | quote }}
{{- end }}
{{- if and .antibot .antibot.antibotTimeResolve (ne .antibot.antibotTimeResolve "") }}
- name: ANTIBOT_TIME_RESOLVE
  value: {{ .antibot.antibotTimeResolve | quote }}
{{- end }}
{{- if and .antibot .antibot.antibotTimeValid (ne .antibot.antibotTimeValid "") }}
- name: ANTIBOT_TIME_VALID
  value: {{ .antibot.antibotTimeValid | quote }}
{{- end }}
{{- if and .antibot .antibot.antibotIgnoreIp (ne .antibot.antibotIgnoreIp "") }}
- name: ANTIBOT_IGNORE_IP
  value: {{ .antibot.antibotIgnoreIp | quote }}
{{- end }}
{{- if and .antibot .antibot.antibotIgnoreUri (ne .antibot.antibotIgnoreUri "") }}
- name: ANTIBOT_IGNORE_URI
  value: {{ .antibot.antibotIgnoreUri | quote }}
{{- end }}

# =============================================================================
# RATE LIMITING
# =============================================================================
{{- if and .rateLimit .rateLimit.useLimitReq (ne .rateLimit.useLimitReq "") }}
- name: USE_LIMIT_REQ
  value: {{ .rateLimit.useLimitReq | quote }}
{{- end }}
{{- if and .rateLimit .rateLimit.limitReqRate (ne .rateLimit.limitReqRate "") }}
- name: LIMIT_REQ_RATE
  value: {{ .rateLimit.limitReqRate | quote }}
{{- end }}
{{- if and .rateLimit .rateLimit.limitReqUrl (ne .rateLimit.limitReqUrl "") }}
- name: LIMIT_REQ_URL
  value: {{ .rateLimit.limitReqUrl | quote }}
{{- end }}
{{- if and .rateLimit .rateLimit.useLimitConn (ne .rateLimit.useLimitConn "") }}
- name: USE_LIMIT_CONN
  value: {{ .rateLimit.useLimitConn | quote }}
{{- end }}
{{- if and .rateLimit .rateLimit.limitConnMaxHttp1 (ne .rateLimit.limitConnMaxHttp1 "") }}
- name: LIMIT_CONN_MAX_HTTP1
  value: {{ .rateLimit.limitConnMaxHttp1 | quote }}
{{- end }}
{{- if and .rateLimit .rateLimit.limitConnMaxHttp2 (ne .rateLimit.limitConnMaxHttp2 "") }}
- name: LIMIT_CONN_MAX_HTTP2
  value: {{ .rateLimit.limitConnMaxHttp2 | quote }}
{{- end }}
{{- if and .rateLimit .rateLimit.limitConnMaxHttp3 (ne .rateLimit.limitConnMaxHttp3 "") }}
- name: LIMIT_CONN_MAX_HTTP3
  value: {{ .rateLimit.limitConnMaxHttp3 | quote }}
{{- end }}

# =============================================================================
# BLACKLIST/WHITELIST
# =============================================================================
{{- if and .blacklist .blacklist.useBlacklist (ne .blacklist.useBlacklist "") }}
- name: USE_BLACKLIST
  value: {{ .blacklist.useBlacklist | quote }}
{{- end }}
{{- if and .blacklist .blacklist.blacklistCommunityLists (ne .blacklist.blacklistCommunityLists "") }}
- name: BLACKLIST_COMMUNITY_LISTS
  value: {{ .blacklist.blacklistCommunityLists | quote }}
{{- end }}
{{- if and .blacklist .blacklist.blacklistIp (ne .blacklist.blacklistIp "") }}
- name: BLACKLIST_IP
  value: {{ .blacklist.blacklistIp | quote }}
{{- end }}
{{- if and .blacklist .blacklist.blacklistIpUrls (ne .blacklist.blacklistIpUrls "") }}
- name: BLACKLIST_IP_URLS
  value: {{ .blacklist.blacklistIpUrls | quote }}
{{- end }}

{{- if and .whitelist .whitelist.useWhitelist (ne .whitelist.useWhitelist "") }}
- name: USE_WHITELIST
  value: {{ .whitelist.useWhitelist | quote }}
{{- end }}
{{- if and .whitelist .whitelist.whitelistIp (ne .whitelist.whitelistIp "") }}
- name: WHITELIST_IP
  value: {{ .whitelist.whitelistIp | quote }}
{{- end }}
{{- if and .whitelist .whitelist.whitelistIpUrls (ne .whitelist.whitelistIpUrls "") }}
- name: WHITELIST_IP_URLS
  value: {{ .whitelist.whitelistIpUrls | quote }}
{{- end }}

# =============================================================================
# COUNTRY BLOCKING
# =============================================================================
{{- if and .geoBlocking .geoBlocking.whitelistCountry (ne .geoBlocking.whitelistCountry "") }}
- name: WHITELIST_COUNTRY
  value: {{ .geoBlocking.whitelistCountry | quote }}
{{- end }}
{{- if and .geoBlocking .geoBlocking.blacklistCountry (ne .geoBlocking.blacklistCountry "") }}
- name: BLACKLIST_COUNTRY
  value: {{ .geoBlocking.blacklistCountry | quote }}
{{- end }}

# =============================================================================
# BAD BEHAVIOR DETECTION
# =============================================================================
{{- if and .badBehavior .badBehavior.useBadBehavior (ne .badBehavior.useBadBehavior "") }}
- name: USE_BAD_BEHAVIOR
  value: {{ .badBehavior.useBadBehavior | quote }}
{{- end }}
{{- if and .badBehavior .badBehavior.badBehaviorStatusCodes (ne .badBehavior.badBehaviorStatusCodes "") }}
- name: BAD_BEHAVIOR_STATUS_CODES
  value: {{ .badBehavior.badBehaviorStatusCodes | quote }}
{{- end }}
{{- if and .badBehavior .badBehavior.badBehaviorThreshold (ne .badBehavior.badBehaviorThreshold "") }}
- name: BAD_BEHAVIOR_THRESHOLD
  value: {{ .badBehavior.badBehaviorThreshold | quote }}
{{- end }}
{{- if and .badBehavior .badBehavior.badBehaviorCountTime (ne .badBehavior.badBehaviorCountTime "") }}
- name: BAD_BEHAVIOR_COUNT_TIME
  value: {{ .badBehavior.badBehaviorCountTime | quote }}
{{- end }}
{{- if and .badBehavior .badBehavior.badBehaviorBanTime (ne .badBehavior.badBehaviorBanTime "") }}
- name: BAD_BEHAVIOR_BAN_TIME
  value: {{ .badBehavior.badBehaviorBanTime | quote }}
{{- end }}

# =============================================================================
# SSL/TLS CONFIGURATION
# =============================================================================
{{- if and .ssl .ssl.listenHttps (ne .ssl.listenHttps "") }}
- name: LISTEN_HTTPS
  value: {{ .ssl.listenHttps | quote }}
{{- end }}
{{- if and .ssl .ssl.sslProtocols (ne .ssl.sslProtocols "") }}
- name: SSL_PROTOCOLS
  value: {{ .ssl.sslProtocols | quote }}
{{- end }}
{{- if and .ssl .ssl.sslCiphersLevel (ne .ssl.sslCiphersLevel "") }}
- name: SSL_CIPHERS_LEVEL
  value: {{ .ssl.sslCiphersLevel | quote }}
{{- end }}
{{- if and .ssl .ssl.autoRedirectHttpToHttps (ne .ssl.autoRedirectHttpToHttps "") }}
- name: AUTO_REDIRECT_HTTP_TO_HTTPS
  value: {{ .ssl.autoRedirectHttpToHttps | quote }}
{{- end }}

# Let's Encrypt configuration
{{- if and .letsEncrypt .letsEncrypt.autoLetsEncrypt (ne .letsEncrypt.autoLetsEncrypt "") }}
- name: AUTO_LETS_ENCRYPT
  value: {{ .letsEncrypt.autoLetsEncrypt | quote }}
{{- end }}
{{- if and .letsEncrypt .letsEncrypt.emailLetsEncrypt (ne .letsEncrypt.emailLetsEncrypt "") }}
- name: EMAIL_LETS_ENCRYPT
  value: {{ .letsEncrypt.emailLetsEncrypt | quote }}
{{- end }}
{{- if and .letsEncrypt .letsEncrypt.letsEncryptChallenge (ne .letsEncrypt.letsEncryptChallenge "") }}
- name: LETS_ENCRYPT_CHALLENGE
  value: {{ .letsEncrypt.letsEncryptChallenge | quote }}
{{- end }}
{{- if and .letsEncrypt .letsEncrypt.letsEncryptDnsProvider (ne .letsEncrypt.letsEncryptDnsProvider "") }}
- name: LETS_ENCRYPT_DNS_PROVIDER
  value: {{ .letsEncrypt.letsEncryptDnsProvider | quote }}
{{- end }}
{{- if and .letsEncrypt .letsEncrypt.useLetsEncryptWildcard (ne .letsEncrypt.useLetsEncryptWildcard "") }}
- name: USE_LETS_ENCRYPT_WILDCARD
  value: {{ .letsEncrypt.useLetsEncryptWildcard | quote }}
{{- end }}

# Custom SSL certificate
{{- if and .customSsl .customSsl.useCustomSsl (ne .customSsl.useCustomSsl "") }}
- name: USE_CUSTOM_SSL
  value: {{ .customSsl.useCustomSsl | quote }}
{{- end }}
{{- if and .customSsl .customSsl.customSslCertPriority (ne .customSsl.customSslCertPriority "") }}
- name: CUSTOM_SSL_CERT_PRIORITY
  value: {{ .customSsl.customSslCertPriority | quote }}
{{- end }}
{{- if and .customSsl .customSsl.customSslCert (ne .customSsl.customSslCert "") }}
- name: CUSTOM_SSL_CERT
  value: {{ .customSsl.customSslCert | quote }}
{{- end }}
{{- if and .customSsl .customSsl.customSslKey (ne .customSsl.customSslKey "") }}
- name: CUSTOM_SSL_KEY
  value: {{ .customSsl.customSslKey | quote }}
{{- end }}


# =============================================================================
# COMPRESSION
# =============================================================================
{{- if and .compression .compression.useGzip (ne .compression.useGzip "") }}
- name: USE_GZIP
  value: {{ .compression.useGzip | quote }}
{{- end }}
{{- if and .compression .compression.gzipCompLevel (ne .compression.gzipCompLevel "") }}
- name: GZIP_COMP_LEVEL
  value: {{ .compression.gzipCompLevel | quote }}
{{- end }}
{{- if and .compression .compression.gzipMinLength (ne .compression.gzipMinLength "") }}
- name: GZIP_MIN_LENGTH
  value: {{ .compression.gzipMinLength | quote }}
{{- end }}

{{- if and .compression .compression.useBrotli (ne .compression.useBrotli "") }}
- name: USE_BROTLI
  value: {{ .compression.useBrotli | quote }}
{{- end }}
{{- if and .compression .compression.brotliCompLevel (ne .compression.brotliCompLevel "") }}
- name: BROTLI_COMP_LEVEL
  value: {{ .compression.brotliCompLevel | quote }}
{{- end }}

# =============================================================================
# CLIENT CACHING
# =============================================================================
{{- if and .clientCache .clientCache.useClientCache (ne .clientCache.useClientCache "") }}
- name: USE_CLIENT_CACHE
  value: {{ .clientCache.useClientCache | quote }}
{{- end }}
{{- if and .clientCache .clientCache.clientCacheExtensions (ne .clientCache.clientCacheExtensions "") }}
- name: CLIENT_CACHE_EXTENSIONS
  value: {{ .clientCache.clientCacheExtensions | quote }}
{{- end }}
{{- if and .clientCache .clientCache.clientCacheControl (ne .clientCache.clientCacheControl "") }}
- name: CLIENT_CACHE_CONTROL
  value: {{ .clientCache.clientCacheControl | quote }}
{{- end }}
{{- if and .clientCache .clientCache.clientCacheEtag (ne .clientCache.clientCacheEtag "") }}
- name: CLIENT_CACHE_ETAG
  value: {{ .clientCache.clientCacheEtag | quote }}
{{- end }}

# =============================================================================
# REVERSE PROXY
# =============================================================================
{{- if and .reverseProxy .reverseProxy.useReverseProxy (ne .reverseProxy.useReverseProxy "") }}
- name: USE_REVERSE_PROXY
  value: {{ .reverseProxy.useReverseProxy | quote }}
{{- end }}
{{- if and .reverseProxy .reverseProxy.reverseProxyHost (ne .reverseProxy.reverseProxyHost "") }}
- name: REVERSE_PROXY_HOST
  value: {{ .reverseProxy.reverseProxyHost | quote }}
{{- end }}
{{- if and .reverseProxy .reverseProxy.reverseProxyUrl (ne .reverseProxy.reverseProxyUrl "") }}
- name: REVERSE_PROXY_URL
  value: {{ .reverseProxy.reverseProxyUrl | quote }}
{{- end }}
{{- if and .reverseProxy .reverseProxy.reverseProxyConnectTimeout (ne .reverseProxy.reverseProxyConnectTimeout "") }}
- name: REVERSE_PROXY_CONNECT_TIMEOUT
  value: {{ .reverseProxy.reverseProxyConnectTimeout | quote }}
{{- end }}
{{- if and .reverseProxy .reverseProxy.reverseProxySendTimeout (ne .reverseProxy.reverseProxySendTimeout "") }}
- name: REVERSE_PROXY_SEND_TIMEOUT
  value: {{ .reverseProxy.reverseProxySendTimeout | quote }}
{{- end }}
{{- if and .reverseProxy .reverseProxy.reverseProxyReadTimeout (ne .reverseProxy.reverseProxyReadTimeout "") }}
- name: REVERSE_PROXY_READ_TIMEOUT
  value: {{ .reverseProxy.reverseProxyReadTimeout | quote }}
{{- end }}

# =============================================================================
# REAL IP DETECTION
# =============================================================================
{{- if and .realIp .realIp.useRealIp (ne .realIp.useRealIp "") }}
- name: USE_REAL_IP
  value: {{ .realIp.useRealIp | quote }}
{{- end }}
{{- if and .realIp .realIp.realIpFrom (ne .realIp.realIpFrom "") }}
- name: REAL_IP_FROM
  value: {{ .realIp.realIpFrom | quote }}
{{- end }}
{{- if and .realIp .realIp.realIpHeader (ne .realIp.realIpHeader "") }}
- name: REAL_IP_HEADER
  value: {{ .realIp.realIpHeader | quote }}
{{- end }}
{{- if and .realIp .realIp.realIpRecursive (ne .realIp.realIpRecursive "") }}
- name: REAL_IP_RECURSIVE
  value: {{ .realIp.realIpRecursive | quote }}
{{- end }}
{{- if and .realIp .realIp.useProxyProtocol (ne .realIp.useProxyProtocol "") }}
- name: USE_PROXY_PROTOCOL
  value: {{ .realIp.useProxyProtocol | quote }}
{{- end }}

# =============================================================================
# SECURITY HEADERS
# =============================================================================
{{- if and .headers .headers.strictTransportSecurity (ne .headers.strictTransportSecurity "") }}
- name: STRICT_TRANSPORT_SECURITY
  value: {{ .headers.strictTransportSecurity | quote }}
{{- end }}
{{- if and .headers .headers.contentSecurityPolicy (ne .headers.contentSecurityPolicy "") }}
- name: CONTENT_SECURITY_POLICY
  value: {{ .headers.contentSecurityPolicy | quote }}
{{- end }}
{{- if and .headers .headers.contentSecurityPolicyReportOnly (ne .headers.contentSecurityPolicyReportOnly "") }}
- name: CONTENT_SECURITY_POLICY_REPORT_ONLY
  value: {{ .headers.contentSecurityPolicyReportOnly | quote }}
{{- end }}
{{- if and .headers .headers.xFrameOptions (ne .headers.xFrameOptions "") }}
- name: X_FRAME_OPTIONS
  value: {{ .headers.xFrameOptions | quote }}
{{- end }}
{{- if and .headers .headers.xContentTypeOptions (ne .headers.xContentTypeOptions "") }}
- name: X_CONTENT_TYPE_OPTIONS
  value: {{ .headers.xContentTypeOptions | quote }}
{{- end }}
{{- if and .headers .headers.referrerPolicy (ne .headers.referrerPolicy "") }}
- name: REFERRER_POLICY
  value: {{ .headers.referrerPolicy | quote }}
{{- end }}
{{- if and .headers .headers.removeHeaders (ne .headers.removeHeaders "") }}
- name: REMOVE_HEADERS
  value: {{ .headers.removeHeaders | quote }}
{{- end }}
{{- if and .headers .headers.customHeader (ne .headers.customHeader "") }}
- name: CUSTOM_HEADER
  value: {{ .headers.customHeader | quote }}
{{- end }}

# =============================================================================
# CORS CONFIGURATION
# =============================================================================
{{- if and .cors .cors.useCors (ne .cors.useCors "") }}
- name: USE_CORS
  value: {{ .cors.useCors | quote }}
{{- end }}
{{- if and .cors .cors.corsAllowOrigin (ne .cors.corsAllowOrigin "") }}
- name: CORS_ALLOW_ORIGIN
  value: {{ .cors.corsAllowOrigin | quote }}
{{- end }}
{{- if and .cors .cors.corsAllowMethods (ne .cors.corsAllowMethods "") }}
- name: CORS_ALLOW_METHODS
  value: {{ .cors.corsAllowMethods | quote }}
{{- end }}
{{- if and .cors .cors.corsAllowHeaders (ne .cors.corsAllowHeaders "") }}
- name: CORS_ALLOW_HEADERS
  value: {{ .cors.corsAllowHeaders | quote }}
{{- end }}
{{- if and .cors .cors.corsAllowCredentials (ne .cors.corsAllowCredentials "") }}
- name: CORS_ALLOW_CREDENTIALS
  value: {{ .cors.corsAllowCredentials | quote }}
{{- end }}

# =============================================================================
# DNSBL CHECKING
# =============================================================================
{{- if and .dnsbl .dnsbl.useDnsbl (ne .dnsbl.useDnsbl "") }}
- name: USE_DNSBL
  value: {{ .dnsbl.useDnsbl | quote }}
{{- end }}
{{- if and .dnsbl .dnsbl.dnsblList (ne .dnsbl.dnsblList "") }}
- name: DNSBL_LIST
  value: {{ .dnsbl.dnsblList | quote }}
{{- end }}

# =============================================================================
# BUNKERNET THREAT INTELLIGENCE
# =============================================================================
{{- if and .bunkerNet .bunkerNet.useBunkernet (ne .bunkerNet.useBunkernet "") }}
- name: USE_BUNKERNET
  value: {{ .bunkerNet.useBunkernet | quote }}
{{- end }}
{{- if and .bunkerNet .bunkerNet.bunkernetServer (ne .bunkerNet.bunkernetServer "") }}
- name: BUNKERNET_SERVER
  value: {{ .bunkerNet.bunkernetServer | quote }}
{{- end }}

# =============================================================================
# SESSION MANAGEMENT
# =============================================================================
{{- if and .sessions .sessions.sessionsSecret (ne .sessions.sessionsSecret "") }}
- name: SESSIONS_SECRET
  value: {{ .sessions.sessionsSecret | quote }}
{{- end }}
{{- if and .sessions .sessions.sessionsName (ne .sessions.sessionsName "") }}
- name: SESSIONS_NAME
  value: {{ .sessions.sessionsName | quote }}
{{- end }}
{{- if and .sessions .sessions.sessionsIdlingTimeout (ne .sessions.sessionsIdlingTimeout "") }}
- name: SESSIONS_IDLING_TIMEOUT
  value: {{ .sessions.sessionsIdlingTimeout | quote }}
{{- end }}
{{- if and .sessions .sessions.sessionsRollingTimeout (ne .sessions.sessionsRollingTimeout "") }}
- name: SESSIONS_ROLLING_TIMEOUT
  value: {{ .sessions.sessionsRollingTimeout | quote }}
{{- end }}
{{- if and .sessions .sessions.sessionsAbsoluteTimeout (ne .sessions.sessionsAbsoluteTimeout "") }}
- name: SESSIONS_ABSOLUTE_TIMEOUT
  value: {{ .sessions.sessionsAbsoluteTimeout | quote }}
{{- end }}
{{- if and .sessions .sessions.sessionsCheckIp (ne .sessions.sessionsCheckIp "") }}
- name: SESSIONS_CHECK_IP
  value: {{ .sessions.sessionsCheckIp | quote }}
{{- end }}
{{- if and .sessions .sessions.sessionsCheckUserAgent (ne .sessions.sessionsCheckUserAgent "") }}
- name: SESSIONS_CHECK_USER_AGENT
  value: {{ .sessions.sessionsCheckUserAgent | quote }}
{{- end }}

# =============================================================================
# METRICS AND MONITORING
# =============================================================================
{{- if and .metrics .metrics.useMetrics (ne .metrics.useMetrics "") }}
- name: USE_METRICS
  value: {{ .metrics.useMetrics | quote }}
{{- end }}
{{- if and .metrics .metrics.metricsMemorySize (ne .metrics.metricsMemorySize "") }}
- name: METRICS_MEMORY_SIZE
  value: {{ .metrics.metricsMemorySize | quote }}
{{- end }}
{{- if and .metrics .metrics.metricsMaxBlockedRequests (ne .metrics.metricsMaxBlockedRequests "") }}
- name: METRICS_MAX_BLOCKED_REQUESTS
  value: {{ .metrics.metricsMaxBlockedRequests | quote }}
{{- end }}
{{- if and .metrics .metrics.metricsSaveToRedis (ne .metrics.metricsSaveToRedis "") }}
- name: METRICS_SAVE_TO_REDIS
  value: {{ .metrics.metricsSaveToRedis | quote }}
{{- end }}

# =============================================================================
# AUTH BASIC
# =============================================================================
{{- if and .authBasic .authBasic.useAuthBasic (ne .authBasic.useAuthBasic "") }}
- name: USE_AUTH_BASIC
  value: {{ .authBasic.useAuthBasic | quote }}
{{- end }}
{{- if and .authBasic .authBasic.authBasicLocation (ne .authBasic.authBasicLocation "") }}
- name: AUTH_BASIC_LOCATION
  value: {{ .authBasic.authBasicLocation | quote }}
{{- end }}
{{- if and .authBasic .authBasic.authBasicUser (ne .authBasic.authBasicUser "") }}
- name: AUTH_BASIC_USER
  value: {{ .authBasic.authBasicUser | quote }}
{{- end }}
{{- if and .authBasic .authBasic.authBasicPassword (ne .authBasic.authBasicPassword "") }}
- name: AUTH_BASIC_PASSWORD
  value: {{ .authBasic.authBasicPassword | quote }}
{{- end }}
{{- if and .authBasic .authBasic.authBasicText (ne .authBasic.authBasicText "") }}
- name: AUTH_BASIC_TEXT
  value: {{ .authBasic.authBasicText | quote }}
{{- end }}

# =============================================================================
# REDIRECTS
# =============================================================================
{{- if .redirect.redirectFrom }}
- name: REDIRECT_FROM
  value: {{ .redirect.redirectFrom | quote }}
{{- end }}
{{- if .redirect.redirectTo }}
- name: REDIRECT_TO
  value: {{ .redirect.redirectTo | quote }}
{{- end }}
{{- if .redirect.redirectToRequestUri }}
- name: REDIRECT_TO_REQUEST_URI
  value: {{ .redirect.redirectToRequestUri | quote }}
{{- end }}
{{- if .redirect.redirectType }}
- name: REDIRECT_TO_STATUS_CODE
  value: {{ .redirect.redirectToStatusCode | quote }}
{{- end }}

# =============================================================================
# ERROR PAGES
# =============================================================================
{{- if .errors.errors }}
- name: ERRORS
  value: {{ .errors.errors | quote }}
{{- end }}
{{- if .errors.interceptedErrorCodes }}
- name: INTERCEPTED_ERROR_CODES
  value: {{ .errors.interceptedErrorCodes | quote }}
{{- end }}

# =============================================================================
# HTML INJECTION
# =============================================================================
{{- if .htmlInjection.injectHead }}
- name: INJECT_HEAD
  value: {{ .htmlInjection.injectHead | quote }}
{{- end }}
{{- if .htmlInjection.injectBody }}
- name: INJECT_BODY
  value: {{ .htmlInjection.injectBody | quote }}
{{- end }}

# =============================================================================
# ROBOTS.TXT
# =============================================================================
{{- if and .robotsTxt .robotsTxt.useRobotsTxt (ne .robotsTxt.useRobotsTxt "") }}
- name: USE_ROBOTSTXT
  value: {{ .robotsTxt.useRobotsTxt | quote }}
{{- end }}
{{- if and .robotsTxt .robotsTxt.robotsTxtDarkvisitorsToken (ne .robotsTxt.robotsTxtDarkvisitorsToken "") }}
- name: ROBOTSTXT_DARKVISITORS_TOKEN
  value: {{ .robotsTxt.robotsTxtDarkvisitorsToken | quote }}
{{- end }}
{{- if and .robotsTxt .robotsTxt.robotsTxtCommunityLists (ne .robotsTxt.robotsTxtCommunityLists "") }}
- name: ROBOTSTXT_COMMUNITY_LISTS
  value: {{ .robotsTxt.robotsTxtCommunityLists | quote }}
{{- end }}
{{- if and .robotsTxt .robotsTxt.robotsTxtRule (ne .robotsTxt.robotsTxtRule "") }}
- name: ROBOTSTXT_RULE
  value: {{ .robotsTxt.robotsTxtRule | quote }}
{{- end }}
{{- if and .robotsTxt .robotsTxt.robotsTxtSitemap (ne .robotsTxt.robotsTxtSitemap "") }}
- name: ROBOTSTXT_SITEMAP
  value: {{ .robotsTxt.robotsTxtSitemap | quote }}
{{- end }}

# =============================================================================
# SECURITY.TXT
# =============================================================================
{{- if and .securityTxt .securityTxt.useSecurityTxt (ne .securityTxt.useSecurityTxt "") }}
- name: USE_SECURITYTXT
  value: {{ .securityTxt.useSecurityTxt | quote }}
{{- end }}
{{- if and .securityTxt .securityTxt.securityTxtContact (ne .securityTxt.securityTxtContact "") }}
- name: SECURITYTXT_CONTACT
  value: {{ .securityTxt.securityTxtContact | quote }}
{{- end }}
{{- if and .securityTxt .securityTxt.securityTxtExpires (ne .securityTxt.securityTxtExpires "") }}
- name: SECURITYTXT_EXPIRES
  value: {{ .securityTxt.securityTxtExpires | quote }}
{{- end }}
{{- if and .securityTxt .securityTxt.securityTxtPolicy (ne .securityTxt.securityTxtPolicy "") }}
- name: SECURITYTXT_POLICY
  value: {{ .securityTxt.securityTxtPolicy | quote }}
{{- end }}

# =============================================================================
# CROWDSEC INTEGRATION
# =============================================================================
{{- if and .crowdSec .crowdSec.useCrowdSec (ne .crowdSec.useCrowdSec "") }}
- name: USE_CROWDSEC
  value: {{ .crowdSec.useCrowdSec | quote }}
{{- end }}
{{- if and .crowdSec .crowdSec.crowdSecApi (ne .crowdSec.crowdSecApi "") }}
- name: CROWDSEC_API
  value: {{ .crowdSec.crowdSecApi | quote }}
{{- end }}
{{- if and .crowdSec .crowdSec.crowdSecApiKey (ne .crowdSec.crowdSecApiKey "") }}
- name: CROWDSEC_API_KEY
  value: {{ .crowdSec.crowdSecApiKey | quote }}
{{- end }}
{{- if and .crowdSec .crowdSec.crowdSecMode (ne .crowdSec.crowdSecMode "") }}
- name: CROWDSEC_MODE
  value: {{ .crowdSec.crowdSecMode | quote }}
{{- end }}
{{- if and .crowdSec .crowdSec.crowdSecAppsecUrl (ne .crowdSec.crowdSecAppsecUrl "") }}
- name: CROWDSEC_APPSEC_URL
  value: {{ .crowdSec.crowdSecAppsecUrl | quote }}
{{- end }}

# =============================================================================
# PHP INTEGRATION
# =============================================================================
{{- if and .php .php.remotePhp (ne .php.remotePhp "") }}
- name: REMOTE_PHP
  value: {{ .php.remotePhp | quote }}
{{- end }}
{{- if and .php .php.remotePhpPort (ne .php.remotePhpPort "") }}
- name: REMOTE_PHP_PORT
  value: {{ .php.remotePhpPort | quote }}
{{- end }}
{{- if and .php .php.remotePhpPath (ne .php.remotePhpPath "") }}
- name: REMOTE_PHP_PATH
  value: {{ .php.remotePhpPath | quote }}
{{- end }}
{{- if and .php .php.localPhp (ne .php.localPhp "") }}
- name: LOCAL_PHP
  value: {{ .php.localPhp | quote }}
{{- end }}
{{- if and .php .php.localPhpPath (ne .php.localPhpPath "") }}
- name: LOCAL_PHP_PATH
  value: {{ .php.localPhpPath | quote }}
{{- end }}

# =============================================================================
# GREYLIST (CONDITIONAL ACCESS)
# =============================================================================
{{- if and .greylist .greylist.useGreylist (ne .greylist.useGreylist "") }}
- name: USE_GREYLIST
  value: {{ .greylist.useGreylist | quote }}
{{- end }}
{{- if and .greylist .greylist.greylistIp (ne .greylist.greylistIp "") }}
- name: GREYLIST_IP
  value: {{ .greylist.greylistIp | quote }}
{{- end }}
{{- if and .greylist .greylist.greylistIpUrls (ne .greylist.greylistIpUrls "") }}
- name: GREYLIST_IP_URLS
  value: {{ .greylist.greylistIpUrls | quote }}
{{- end }}

# =============================================================================
# REVERSE SCAN
# =============================================================================
{{- if and .reverseScan .reverseScan.useReverseScan (ne .reverseScan.useReverseScan "") }}
- name: USE_REVERSE_SCAN
  value: {{ .reverseScan.useReverseScan | quote }}
{{- end }}
{{- if and .reverseScan .reverseScan.reverseScanPorts (ne .reverseScan.reverseScanPorts "") }}
- name: REVERSE_SCAN_PORTS
  value: {{ .reverseScan.reverseScanPorts | quote }}
{{- end }}
{{- if and .reverseScan .reverseScan.reverseScanTimeout (ne .reverseScan.reverseScanTimeout "") }}
- name: REVERSE_SCAN_TIMEOUT
  value: {{ .reverseScan.reverseScanTimeout | quote }}
{{- end }}

# =============================================================================
# BACKUP CONFIGURATION
# =============================================================================
{{- if and .backup .backup.useBackup (ne .backup.useBackup "") }}
- name: USE_BACKUP
  value: {{ .backup.useBackup | quote }}
{{- end }}
{{- if and .backup .backup.backupSchedule (ne .backup.backupSchedule "") }}
- name: BACKUP_SCHEDULE
  value: {{ .backup.backupSchedule | quote }}
{{- end }}
{{- if and .backup .backup.backupRotation (ne .backup.backupRotation "") }}
- name: BACKUP_ROTATION
  value: {{ .backup.backupRotation | quote }}
{{- end }}
{{- if and .backup .backup.backupDirectory (ne .backup.backupDirectory "") }}
- name: BACKUP_DIRECTORY
  value: {{ .backup.backupDirectory | quote }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Syslog address for UI logs
Returns the configured syslog address if set, otherwise the UI sidecar service address
*/}}
{{- define "bunkerweb.syslogAddress" -}}
{{- if and .Values.ui.logs.syslogAddress (ne .Values.ui.logs.syslogAddress "") -}}
  {{- .Values.ui.logs.syslogAddress -}}
{{- else -}}
  {{- printf "ui-%s.%s.svc.%s:514" (include "bunkerweb.fullname" .) (include "bunkerweb.namespace" .) .Values.settings.kubernetes.domainName -}}
{{- end -}}
{{- end -}}