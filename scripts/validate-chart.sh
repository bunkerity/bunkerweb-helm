#!/bin/bash

# =============================================================================
# BunkerWeb Helm Chart Validation Script
# =============================================================================
# This script performs comprehensive validation of the BunkerWeb Helm chart
# including syntax validation, template generation, and configuration testing.

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CHART_PATH="charts/bunkerweb"
TEMP_DIR=$(mktemp -d)
EXIT_CODE=0

# Cleanup function
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    EXIT_CODE=1
}

# Check if required tools are available
check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v helm &> /dev/null; then
        log_error "Helm is not installed or not in PATH"
        return 1
    fi

    log_success "Prerequisites check completed"
}

# Run helm lint
run_helm_lint() {
    log_info "Running helm lint..."

    local lint_output
    if lint_output=$(helm lint "$CHART_PATH" 2>&1); then
        log_success "Helm lint passed"

        # Check for warnings
        if echo "$lint_output" | grep -q "\[WARNING\]"; then
            log_warning "Helm lint found warnings:"
            echo "$lint_output" | grep "\[WARNING\]" | sed 's/^/  /'
        fi

        # Check for info messages
        if echo "$lint_output" | grep -q "\[INFO\]"; then
            log_info "Helm lint info messages:"
            echo "$lint_output" | grep "\[INFO\]" | sed 's/^/  /'
        fi
    else
        log_error "Helm lint failed:"
        echo "$lint_output" | sed 's/^/  /'
        return 1
    fi
}

# Test template generation with various configurations
test_template_generation() {
    log_info "Testing template generation with various configurations..."

    local test_configs=(
        "default configuration"
        "redis.useConfigFile=true:Redis with config file"
        "redis.useConfigFile=false:Redis without config file"
        "bunkerweb.kind=Deployment:BunkerWeb as Deployment"
        "bunkerweb.kind=DaemonSet:BunkerWeb as DaemonSet"
        "bunkerweb.kind=StatefulSet:BunkerWeb as StatefulSet"
        "bunkerweb.hpa.enabled=true:With HPA"
        "bunkerweb.podDisruptionBudget.enabled=true:With Pod Disruption Budget"
        "prometheus.enabled=true,grafana.enabled=true:With monitoring"
        "grafana.enabled=true,grafana.ingress.enabled=true,grafana.ingress.serverName=grafana.test.com:With Grafana Ingress"
        "grafana.enabled=true,grafana.persistence.enabled=true:With Grafana PVC"
        "networkPolicy.enabled=true:With network policies"
        "mariadb.enabled=false:Without MariaDB"
        "redis.enabled=false:Without Redis"
        "ui.enabled=false:Without UI"
        "ui.logs.enabled=true:With UI logs (syslog sidecar)"
        "ui.logs.enabled=true,ui.logs.syslogAddress=:With UI logs (default address)"
        "ui.logs.enabled=true,ui.logs.syslogAddress=custom.syslog:514:With UI logs (custom address)"
        "scheduler.enabled=false:Without Scheduler"
        "controller.enabled=false:Without Controller"
        "api.enabled=false:Without API"
        "api.enabled=true,settings.api.useBearerToken.token=test-token,settings.api.ingress.enabled=true,settings.api.ingress.serverName=api.test.com:With API Ingress"
        "settings.ui.ingress.enabled=true,settings.ui.ingress.serverName=ui.test.com:With UI Ingress"
        "ingressClass.name=bw-custom:With custom IngressClass name"
    )

    for config in "${test_configs[@]}"; do
        local key="${config%%:*}"
        local description="${config##*:}"

        log_info "  Testing: $description"

        local helm_args=()
        if [[ "$key" != "default configuration" ]]; then
            IFS=',' read -ra SETTINGS <<< "$key"
            for setting in "${SETTINGS[@]}"; do
                helm_args+=(--set "$setting")
            done
        fi

        local output_file="$TEMP_DIR/test-${key//[^a-zA-Z0-9]/-}.yaml"

        if helm template test-release "$CHART_PATH" "${helm_args[@]}" --dry-run > "$output_file" 2>&1; then
            log_success "    ✓ Template generation successful"
        else
            log_error "    ✗ Template generation failed:"
            cat "$output_file" | sed 's/^/      /'
            return 1
        fi
    done

    log_success "Template generation tests completed"
}

# --- Test helpers for test_bunkerweb_specific ---

# Render `helm template test $CHART_PATH <args>`, capturing combined output into $output.
# Returns helm's exit status; does no logging.
render() {
    output=$(helm template test "$CHART_PATH" "$@" 2>&1)
}

# Render with --dry-run expecting success. Logs "<desc> works" / "<desc> failed".
assert_renders() {
    local desc=$1; shift
    if helm template test "$CHART_PATH" "$@" --dry-run > /dev/null 2>&1; then
        log_success "    ✓ $desc works"
    else
        log_error "    ✗ $desc failed"
        return 1
    fi
}

# Render with --dry-run expecting failure (auth/validation guards).
# $1 = message logged if it unexpectedly succeeds, $2 = message logged if it correctly fails.
assert_render_fails() {
    local fail_msg=$1 success_msg=$2; shift 2
    if helm template test "$CHART_PATH" "$@" --dry-run > /dev/null 2>&1; then
        log_error "    ✗ $fail_msg"
        return 1
    else
        log_success "    ✓ $success_msg"
    fi
}

# Extract the YAML document for "# Source: bunkerweb/templates/<path>" from $output.
source_block() {
    echo "$output" | awk -v src="^# Source: bunkerweb/templates/$1" '$0 ~ src {f=1} /^---/{f=0} f'
}

# True if haystack $1 contains fixed string $2.
contains() {
    [[ $(echo "$1" | grep -cF -- "$2" || true) -gt 0 ]]
}

# Extract only the named container's env from a rendered workload.
container_env() {
    source_block "$1" | awk -v container="$2" '
        /^        - name:/ { selected = ($3 == container); env = 0 }
        selected && /^          env:/ { env = 1; next }
        env && /^          [^ ]/ { env = 0 }
        env { print }
    '
}

# Require one literal env entry with the expected value, in the selected container.
assert_env_value() {
    local env=$1 name=$2 value=$3
    if ! awk -v name="$name" -v value="\"$value\"" '
        $1 == "-" && $2 == "name:" && $3 == name {
            count++; getline; sub(/^ +value: /, ""); if ($0 == value) matched++
        }
        END { exit !(count == 1 && matched == 1) }
    ' <<< "$env"; then
        log_error "    ✗ $name missing, duplicated, or incorrect (expected: $value)"
        return 1
    fi
}

# Print "<document> <container> <name>" for each env name rendered more than once
# in one container's env list of $output. Names legitimately repeat across containers.
duplicate_env_names() {
    awk '
        /^---/ { src = ""; container = ""; env = 0; next }
        /^# Source:/ { src = $3; next }
        /^        - name:/ { container = $3; env = 0; next }
        /^          env:/ { env = 1; next }
        env && /^          [^ ]/ { env = 0 }
        env && /^            - name:/ { if (seen[src SUBSEP container SUBSEP $3]++) print src " " container " " $3 }
    ' <<< "$output"
}

# Print the value of env entry $2 in the env list $1 ("<valueFrom>" for a valueFrom
# entry, quotes stripped). Fails unless the name appears exactly once.
env_entry() {
    awk -v name="$2" '
        $1 == "-" && $2 == "name:" && $3 == name {
            n++; getline
            if ($1 == "valueFrom:") v = "<valueFrom>"
            else { sub(/^ +value: /, ""); gsub(/^"|"$/, ""); v = $0 }
        }
        END { if (n != 1) exit 1; print v }
    ' <<< "$1"
}

# Require env entry $3 of container $2 in rendered workload $1 to appear once with value $4.
assert_env_entry() {
    local env got
    env=$(container_env "$1" "$2")
    if ! got=$(env_entry "$env" "$3") || [[ "$got" != "$4" ]]; then
        log_error "    ✗ $2 env $3 missing, duplicated, or not '$4' (got: ${got:-none})"
        return 1
    fi
}

# extraEnvs never duplicate a chart-generated env name (issue #147) and win over it.
test_extra_envs_dedupe() {
    log_info "Testing extraEnvs dedupe (issue #147) and PDB fields..."
    local output kind dups env last
    local wa="$TEMP_DIR/wa142.yaml" every="$TEMP_DIR/extra-envs-everywhere.yaml"

    # The workaround posted on issue #142: extraEnvs naming chart-generated log envs.
    cat > "$wa" <<'EOF'
ui:
  logs:
    enabled: true
scheduler:
  extraEnvs:
    - name: ACCESS_LOG_1
      value: "syslog:server=ui-bunkerweb.bunkerweb.svc.cluster.local:514,tag=bunkerweb_access"
    - name: ERROR_LOG_1
      value: "syslog:server=ui-bunkerweb.bunkerweb.svc.cluster.local:514,tag=bunkerweb"
bunkerweb:
  extraEnvs:
    - name: LOG_TYPES
      value: "stderr syslog"
    - name: LOG_SYSLOG_ADDRESS
      value: "ui-bunkerweb.bunkerweb.svc.cluster.local:514"
EOF
    for kind in Deployment DaemonSet StatefulSet; do
        log_info "  Testing #142 workaround values on $kind"
        if ! render -f "$wa" --set bunkerweb.kind="$kind" --set controller.enabled=true --set api.enabled=true; then
            log_error "    ✗ Failed to render the #142 workaround values"
            echo "$output"
            return 1
        fi
        dups=$(duplicate_env_names)
        if [[ -n "$dups" ]]; then
            log_error "    ✗ Duplicate env names with the #142 workaround: $dups"
            return 1
        fi
        assert_env_entry "bunkerweb-${kind,,}.yaml" bunkerweb LOG_TYPES "stderr syslog" \
            && assert_env_entry "bunkerweb-${kind,,}.yaml" bunkerweb LOG_SYSLOG_ADDRESS "ui-bunkerweb.bunkerweb.svc.cluster.local:514" \
            && assert_env_entry scheduler-deployment.yaml bunkerweb-scheduler ACCESS_LOG_1 "syslog:server=ui-bunkerweb.bunkerweb.svc.cluster.local:514,tag=bunkerweb_access" \
            && assert_env_entry scheduler-deployment.yaml bunkerweb-scheduler ERROR_LOG_1 "syslog:server=ui-bunkerweb.bunkerweb.svc.cluster.local:514,tag=bunkerweb" \
            || return 1
    done
    log_success "    ✓ #142 workaround renders unique env names with the user's values"

    # Every template that renders extraEnvs: override a chart-generated name, set a
    # valueFrom override, repeat a name inside extraEnvs, and add an extra-only name.
    cat > "$every" <<'EOF'
api:
  extraEnvs:
    - {name: API_ROOT_PATH, value: user-api}
controller:
  extraEnvs:
    - {name: KUBERNETES_MODE, value: user-controller}
    - {name: CTRL_ONLY, value: kept}
grafana:
  enabled: true
  extraEnvs:
    - {name: GF_SECURITY_ADMIN_USER, value: user-grafana}
    - {name: GF_DUP, value: first}
    - {name: GF_DUP, value: last}
mariadb:
  extraEnvs:
    - {name: MARIADB_RANDOM_ROOT_PASSWORD, value: user-mariadb}
redis:
  extraEnvs:
    - name: REDIS_PASSWORD
      valueFrom: {secretKeyRef: {name: user-secret, key: pw}}
scheduler:
  extraEnvs:
    - {name: SERVER_NAME, value: user.example.com}
    - {name: BUNKERWEB_INSTANCES, value: user-instances}
ui:
  extraEnvs:
    - {name: OVERRIDE_ADMIN_CREDS, value: user-ui}
bunkerweb:
  extraEnvs:
    - {name: DNS_RESOLVERS, value: user-bunkerweb}
EOF
    for kind in Deployment DaemonSet StatefulSet; do
        log_info "  Testing extraEnvs on every component ($kind)"
        if ! render -f "$every" --set bunkerweb.kind="$kind" --set controller.enabled=true --set api.enabled=true; then
            log_error "    ✗ Failed to render extraEnvs on every component"
            echo "$output"
            return 1
        fi
        dups=$(duplicate_env_names)
        if [[ -n "$dups" ]]; then
            log_error "    ✗ Duplicate env names with extraEnvs overrides: $dups"
            return 1
        fi
        assert_env_entry api-deployment.yaml bunkerweb-api API_ROOT_PATH user-api \
            && assert_env_entry controller-deployment.yaml bunkerweb-controller KUBERNETES_MODE user-controller \
            && assert_env_entry controller-deployment.yaml bunkerweb-controller CTRL_ONLY kept \
            && assert_env_entry grafana-deployment.yaml grafana GF_SECURITY_ADMIN_USER user-grafana \
            && assert_env_entry grafana-deployment.yaml grafana GF_DUP last \
            && assert_env_entry mariadb-deployment.yaml mariadb MARIADB_RANDOM_ROOT_PASSWORD user-mariadb \
            && assert_env_entry redis-deployment.yaml redis REDIS_PASSWORD "<valueFrom>" \
            && assert_env_entry scheduler-deployment.yaml bunkerweb-scheduler SERVER_NAME user.example.com \
            && assert_env_entry scheduler-deployment.yaml bunkerweb-scheduler BUNKERWEB_INSTANCES user-instances \
            && assert_env_entry ui-deployment.yaml bunkerweb-ui OVERRIDE_ADMIN_CREDS user-ui \
            && assert_env_entry "bunkerweb-${kind,,}.yaml" bunkerweb DNS_RESOLVERS user-bunkerweb \
            || return 1
        # extraEnvs entries stay after the chart's own entries
        env=$(container_env grafana-deployment.yaml grafana)
        last=$(awk '$1 == "-" && $2 == "name:" {n = $3} END {print n}' <<< "$env")
        if [[ "$last" != GF_DUP ]]; then
            log_error "    ✗ Grafana extraEnvs must render after the chart's env (last entry: $last)"
            return 1
        fi
    done
    log_success "    ✓ extraEnvs win, repeat-last, keep valueFrom, and render after chart env on every component"

    log_info "  Testing scheduler BUNKERWEB_INSTANCES default without extraEnvs"
    if ! render || ! assert_env_entry scheduler-deployment.yaml bunkerweb-scheduler BUNKERWEB_INSTANCES ""; then
        log_error "    ✗ BUNKERWEB_INSTANCES must render once with the chart default"
        return 1
    fi
    log_success "    ✓ BUNKERWEB_INSTANCES chart default preserved"

    log_info "  Testing extraEnvs that is not a list fails with a clear message"
    if render --set-json 'scheduler.extraEnvs={"name":"X","value":"y"}' \
        || ! contains "$output" "extraEnvs must be a list"; then
        log_error "    ✗ extraEnvs given as a map must fail with the 'extraEnvs must be a list' message"
        return 1
    fi
    log_success "    ✓ non-list extraEnvs is rejected with a clear message"

    log_info "  Testing PodDisruptionBudget renders one of minAvailable / maxUnavailable"
    if ! render --set bunkerweb.replicas=2 --set bunkerweb.pdb.minAvailable=1 --set bunkerweb.pdb.maxUnavailable=1; then
        log_error "    ✗ Failed to render the PodDisruptionBudget"
        return 1
    fi
    local pdb
    pdb=$(source_block bunkerweb-poddisruptionbudget.yaml)
    if ! contains "$pdb" "minAvailable: 1" || contains "$pdb" "maxUnavailable"; then
        log_error "    ✗ PDB with minAvailable set must not render maxUnavailable"
        return 1
    fi
    render --set bunkerweb.replicas=2
    pdb=$(source_block bunkerweb-poddisruptionbudget.yaml)
    if ! contains "$pdb" "maxUnavailable: 1" || contains "$pdb" "minAvailable"; then
        log_error "    ✗ Default PDB must render only maxUnavailable: 1"
        return 1
    fi
    # Zero is a real budget: only null and "" count as unset.
    local case_args want_field want_value other
    for case_args in \
        "minAvailable|0|--set bunkerweb.pdb.minAvailable=0" \
        "minAvailable|0|--set-string bunkerweb.pdb.minAvailable=0 --set bunkerweb.pdb.maxUnavailable=2" \
        "minAvailable|50%|--set-string bunkerweb.pdb.minAvailable=50%" \
        "maxUnavailable|0|--set bunkerweb.pdb.maxUnavailable=0" \
        "maxUnavailable|0|--set-string bunkerweb.pdb.maxUnavailable=0" \
        "maxUnavailable|1|--set-string bunkerweb.pdb.maxUnavailable=" \
        "maxUnavailable|25%|--set-string bunkerweb.pdb.maxUnavailable=25%"; do
        IFS='|' read -r want_field want_value case_args <<< "$case_args"
        other=minAvailable; [[ $want_field == minAvailable ]] && other=maxUnavailable
        # shellcheck disable=SC2086  # the case's --set flags are meant to split
        if ! render --set bunkerweb.replicas=2 $case_args; then
            log_error "    ✗ Failed to render PDB case: $case_args"
            return 1
        fi
        pdb=$(source_block bunkerweb-poddisruptionbudget.yaml)
        if ! contains "$pdb" "  $want_field: $want_value" || contains "$pdb" "$other"; then
            log_error "    ✗ PDB case '$case_args' must render only '$want_field: $want_value'"
            echo "$pdb"
            return 1
        fi
    done
    log_success "    ✓ PDB renders minAvailable alone, maxUnavailable by default, and keeps a zero budget"

    log_success "extraEnvs dedupe tests completed"
}

# Test specific BunkerWeb configurations
test_bunkerweb_specific() {
    log_info "Testing BunkerWeb-specific configurations..."
    local output

    # Test with different service types
    local service_types=("LoadBalancer" "NodePort" "ClusterIP")
    for service_type in "${service_types[@]}"; do
        log_info "  Testing with service type: $service_type"
        assert_renders "Service type $service_type" --set service.type="$service_type" || return 1
    done

    # Test ingress configurations
    log_info "  Testing UI ingress configuration"
    assert_renders "UI ingress configuration" \
        --set settings.ui.ingress.enabled=true \
        --set settings.ui.ingress.serverName=test.example.com || return 1

    log_info "  Testing chart Ingresses follow a custom IngressClass name"
    if render --set ingressClass.name=bw-custom --set settings.ui.ingress.enabled=true --set settings.ui.ingress.serverName=ui.test.com --dry-run; then
        if contains "$(source_block ui-ingress.yaml)" "ingressClassName: bw-custom"; then
            log_success "    ✓ UI Ingress uses the custom IngressClass name"
        else
            log_error "    ✗ UI Ingress did not use the custom IngressClass name"
            return 1
        fi
    else
        log_error "    ✗ Failed to render the UI Ingress with a custom IngressClass name"
        return 1
    fi

    log_info "  Testing API auth guard (enabled without a token must fail)"
    assert_render_fails \
        "API enabled without a token should have failed to render" \
        "API auth guard correctly blocks tokenless API" \
        --set api.enabled=true --set settings.apiToken.generate=false || return 1

    log_info "  Testing default generated token reaches API-facing workloads"
    if render --set api.enabled=true --dry-run; then
        local token_ref='name: "test-bunkerweb-api-token"'
        local worker_doc scheduler_doc ui_doc api_doc
        worker_doc=$(source_block bunkerweb-deployment.yaml)
        scheduler_doc=$(source_block scheduler-deployment.yaml)
        ui_doc=$(source_block ui-deployment.yaml)
        api_doc=$(source_block api-deployment.yaml)
        if contains "$worker_doc" "$token_ref" \
            && contains "$scheduler_doc" "$token_ref" \
            && contains "$ui_doc" "$token_ref" \
            && contains "$api_doc" "$token_ref"; then
            log_success "    ✓ Default token is shared by worker, scheduler, UI, and API"
        else
            log_error "    ✗ Default token was not shared by all API-facing workloads"
            return 1
        fi
    else
        log_error "    ✗ Failed to render API with the default generated token"
        return 1
    fi

    log_info "  Testing MCP auto-enables API (must require a token)"
    assert_render_fails \
        "MCP enabled without a token should have failed to render" \
        "MCP auto-enables API and enforces the token guard" \
        --set mcp.enabled=true --set settings.apiToken.generate=false || return 1

    log_info "  Testing API disabled"
    if render --set api.enabled=false --dry-run; then
        local api_templates
        api_templates=$(echo "$output" | grep -F "Source: bunkerweb/templates/api-" | grep -vF "api-token-secret.yaml" || true)
        if [[ -z "$api_templates" ]]; then
            log_success "    ✓ API correctly disabled"
        else
            log_error "    ✗ API templates still generated when disabled"
            return 1
        fi
    else
        log_error "    ✗ Failed to generate templates with API disabled"
        return 1
    fi

    log_info "  Testing scheduler disabled"
    if render --set scheduler.enabled=false --dry-run; then
        if [[ -z "$(source_block scheduler-deployment.yaml)" ]]; then
            log_success "    ✓ Scheduler correctly disabled"
        else
            log_error "    ✗ Scheduler Deployment still generated when disabled"
            return 1
        fi
    else
        log_error "    ✗ Failed to generate templates with scheduler disabled"
        return 1
    fi

    log_info "  Testing numeric zero in scheduler feature values"
    if render --dry-run \
        && ! contains "$(source_block scheduler-deployment.yaml)" "name: DATABASE_READ_TIMEOUT" \
        && render --set scheduler.features.databasePool.databaseReadTimeout=0 --dry-run; then
        local timeout_block
        timeout_block=$(source_block scheduler-deployment.yaml | grep -A1 'name: DATABASE_READ_TIMEOUT' || true)
        if contains "$timeout_block" 'value: "0"'; then
            log_success "    ✓ DATABASE_READ_TIMEOUT is omitted by default and numeric zero renders as a string"
        else
            log_error "    ✗ Numeric zero DATABASE_READ_TIMEOUT did not render as a string"
            return 1
        fi
    else
        log_error "    ✗ Failed to render scheduler feature timeout or default timeout was not omitted"
        return 1
    fi

    # Test scheduler custom-plugin volumes/volumeMounts/initContainers (issue #87)
    log_info "  Testing scheduler initContainers/volumes/volumeMounts (custom plugins)"
    if render \
        --set-json 'scheduler.initContainers=[{"name":"bunkerweb-scheduler-init","image":"alpine/git","command":["/bin/sh","-c"],"args":["git clone https://github.com/bunkerity/bunkerweb-plugins /data/plugins && chown -R 101:101 /data/plugins"],"volumeMounts":[{"mountPath":"/data/plugins","name":"vol-plugins"}]}]' \
        --set-json 'scheduler.volumes=[{"name":"vol-plugins","persistentVolumeClaim":{"claimName":"pvc-bunkerweb-plugins"}}]' \
        --set-json 'scheduler.volumeMounts=[{"mountPath":"/data/plugins","name":"vol-plugins"}]' \
        --dry-run; then
        scheduler_doc=$(source_block scheduler-deployment.yaml)
        if contains "$scheduler_doc" "bunkerweb-scheduler-init" \
            && contains "$scheduler_doc" "initContainers:" \
            && contains "$scheduler_doc" "pvc-bunkerweb-plugins" \
            && contains "$scheduler_doc" "/data/plugins"; then
            log_success "    ✓ Scheduler custom-plugin volumes/initContainers render correctly"
        else
            log_error "    ✗ Scheduler volumes/initContainers did not render as expected"
            return 1
        fi
    else
        log_error "    ✗ Failed to render scheduler volumes/initContainers"
        echo "$output" | sed 's/^/      /'
        return 1
    fi

    # Test worker probes: strict startupProbe gate and strict readinessProbe (issue #97)
    log_info "  Testing worker startupProbe/readinessProbe on every kind"
    local kind doc_name probe_doc startup_block readiness_block
    for kind in Deployment DaemonSet StatefulSet; do
        doc_name="bunkerweb-${kind,,}.yaml"
        if ! render --set bunkerweb.kind="$kind" --dry-run; then
            log_error "    ✗ Failed to render the $kind worker"
            return 1
        fi
        probe_doc=$(source_block "$doc_name")
        startup_block=$(echo "$probe_doc" | awk '/^ +startupProbe:/{f=1;next} f&&/^ +[a-zA-Z]+Probe:/{f=0} f')
        readiness_block=$(echo "$probe_doc" | awk '/^ +readinessProbe:/{f=1;next} f&&/^ +[a-zA-Z]+:/&&!/^ {12}/{f=0} f')
        if contains "$startup_block" "healthcheck.sh" && contains "$startup_block" "- ok" \
            && contains "$readiness_block" "healthcheck.sh" && contains "$readiness_block" "- ok"; then
            log_success "    ✓ $kind: strict startupProbe and readinessProbe"
        else
            log_error "    ✗ $kind: startupProbe/readinessProbe did not render as expected"
            return 1
        fi
        # Helm merges {} into the default map, so only null removes the probe
        if render --set bunkerweb.kind="$kind" --set-json "bunkerweb.startupProbe=null" --dry-run \
            && ! contains "$(source_block "$doc_name")" "startupProbe:"; then
            log_success "    ✓ $kind: startupProbe=null removes the probe"
        else
            log_error "    ✗ $kind: startupProbe=null did not remove the probe"
            return 1
        fi
    done

    # Test parity: initContainers on bunkerweb and controller
    log_info "  Testing bunkerweb/controller initContainers parity"
    if render \
        --set controller.enabled=true \
        --set-json 'bunkerweb.initContainers=[{"name":"bw-init","image":"busybox"}]' \
        --set-json 'controller.initContainers=[{"name":"ctrl-init","image":"busybox"}]' \
        --dry-run; then
        if contains "$output" "bw-init" && contains "$output" "ctrl-init"; then
            log_success "    ✓ bunkerweb/controller initContainers render correctly"
        else
            log_error "    ✗ bunkerweb/controller initContainers did not render"
            return 1
        fi
    else
        log_error "    ✗ Failed to render bunkerweb/controller initContainers"
        echo "$output" | sed 's/^/      /'
        return 1
    fi

    # Test PRO_LICENSE_KEY sourcing from existingSecret (PR #84)
    log_info "  Testing PRO_LICENSE_KEY from existingSecret (secretKeyRef, optional)"
    if render --set settings.existingSecret=mysecret --dry-run; then
        scheduler_doc=$(source_block scheduler-deployment.yaml)
        pro_block=$(echo "$scheduler_doc" | grep -A5 "name: PRO_LICENSE_KEY" || true)
        if contains "$pro_block" "secretKeyRef" \
            && contains "$pro_block" "key: pro-license-key" \
            && contains "$pro_block" "optional: true"; then
            log_success "    ✓ PRO_LICENSE_KEY sourced from existingSecret with optional secretKeyRef"
        else
            log_error "    ✗ PRO_LICENSE_KEY existingSecret env did not render as expected"
            return 1
        fi
    else
        log_error "    ✗ Failed to render scheduler with existingSecret"
        echo "$output" | sed 's/^/      /'
        return 1
    fi

    # Test PRO_LICENSE_KEY sourcing from plain proLicenseKey value (PR #84)
    log_info "  Testing PRO_LICENSE_KEY from plain proLicenseKey value"
    if render --set scheduler.proLicenseKey=TESTKEY --dry-run; then
        scheduler_doc=$(source_block scheduler-deployment.yaml)
        pro_block=$(echo "$scheduler_doc" | grep -A2 "name: PRO_LICENSE_KEY" || true)
        if contains "$pro_block" "TESTKEY"; then
            log_success "    ✓ PRO_LICENSE_KEY sourced from plain proLicenseKey value"
        else
            log_error "    ✗ PRO_LICENSE_KEY plain value env did not render as expected"
            return 1
        fi
    else
        log_error "    ✗ Failed to render scheduler with proLicenseKey"
        echo "$output" | sed 's/^/      /'
        return 1
    fi

    # Test feature secrets sourcing from existingSecret (secretKeyRef, optional)
    log_info "  Testing feature secrets from existingSecret (CROWDSEC_API_KEY, SESSIONS_SECRET)"
    if render --set settings.existingSecret=mysecret --dry-run; then
        scheduler_doc=$(source_block scheduler-deployment.yaml)
        crowdsec_block=$(echo "$scheduler_doc" | grep -A5 "name: CROWDSEC_API_KEY" || true)
        sessions_block=$(echo "$scheduler_doc" | grep -A5 "name: SESSIONS_SECRET" || true)
        if contains "$crowdsec_block" "secretKeyRef" \
            && contains "$crowdsec_block" "key: crowdsec-api-key" \
            && contains "$crowdsec_block" "optional: true" \
            && contains "$sessions_block" "secretKeyRef" \
            && contains "$sessions_block" "key: sessions-secret" \
            && contains "$sessions_block" "optional: true"; then
            log_success "    ✓ Feature secrets sourced from existingSecret with optional secretKeyRef"
        else
            log_error "    ✗ Feature secrets existingSecret envs did not render as expected"
            return 1
        fi
    else
        log_error "    ✗ Failed to render scheduler feature secrets with existingSecret"
        echo "$output" | sed 's/^/      /'
        return 1
    fi

    # Test Redis ConfigMap does not leak existingSecret name as requirepass (bug fix)
    # redis.config.file="" forces the chart's built-in redis.conf template (the buggy path)
    log_info "  Testing Redis ConfigMap requirepass with existingSecret + useConfigFile"
    if render \
        --set settings.existingSecret=mysecret \
        --set redis.enabled=true \
        --set redis.useConfigFile=true \
        --set redis.config.file="" \
        --dry-run; then
        redis_cm=$(source_block redis-configmap.yaml)
        redis_deploy=$(source_block redis-deployment.yaml)
        if ! contains "$redis_cm" "requirepass mysecret" \
            && contains "$redis_deploy" "key: redis-password" \
            && contains "$redis_deploy" "--requirepass"; then
            log_success "    ✓ Redis ConfigMap omits secret-name requirepass; deployment injects password from secret"
        else
            log_error "    ✗ Redis ConfigMap/deployment auth did not render as expected (existingSecret)"
            return 1
        fi
    else
        log_error "    ✗ Failed to render Redis with existingSecret + useConfigFile"
        echo "$output" | sed 's/^/      /'
        return 1
    fi

    # Test Redis ConfigMap keeps plain requirepass when no existingSecret
    # redis.config.file="" forces the chart's built-in redis.conf template
    log_info "  Testing Redis ConfigMap plain requirepass without existingSecret"
    if render \
        --set redis.enabled=true \
        --set redis.useConfigFile=true \
        --set redis.config.file="" \
        --set redis.config.password=changeme \
        --dry-run; then
        redis_cm=$(source_block redis-configmap.yaml)
        if contains "$redis_cm" "requirepass changeme"; then
            log_success "    ✓ Redis ConfigMap carries plain requirepass from redis.config.password"
        else
            log_error "    ✗ Redis ConfigMap plain requirepass did not render as expected"
            return 1
        fi
    else
        log_error "    ✗ Failed to render Redis with useConfigFile (plain)"
        echo "$output" | sed 's/^/      /'
        return 1
    fi

    # Issue #142: inspect actual container env, not matching strings elsewhere in the chart.
    local logging_mode address component env duplicates
    local logging_args=()
    for kind in Deployment DaemonSet StatefulSet; do
        for logging_mode in disabled default custom; do
            logging_args=(--set ui.logs.enabled=false)
            address="ui-test-bunkerweb.default.svc.cluster.local:514"
            if [[ "$logging_mode" != disabled ]]; then
                logging_args=(--set ui.logs.enabled=true --set ui.logs.syslogAddress=)
                if [[ "$logging_mode" == custom ]]; then
                    address="custom-syslog.example.com:1514"
                    logging_args+=(--set "ui.logs.syslogAddress=$address")
                fi
            fi
            log_info "  Testing $kind logging: $logging_mode"
            if ! render --set bunkerweb.kind="$kind" --set scheduler.enabled=true \
                --set controller.enabled=true --set ui.enabled=true --set api.enabled=true \
                "${logging_args[@]}"; then
                log_error "    ✗ Failed to render $kind logging: $logging_mode"
                echo "$output"
                return 1
            fi
            for component in bunkerweb scheduler controller ui api; do
                doc_name="$component-deployment.yaml"
                local container="bunkerweb-$component"
                if [[ "$component" == bunkerweb ]]; then
                    doc_name="bunkerweb-${kind,,}.yaml"
                    container=bunkerweb
                fi
                env=$(container_env "$doc_name" "$container")
                if [[ -z "$env" ]]; then
                    log_error "    ✗ $doc_name: $container env missing"
                    return 1
                fi
                duplicates=$(awk '$1 == "-" && $2 == "name:" {print $3}' <<< "$env" | sort | uniq -d)
                if [[ -n "$duplicates" ]]; then
                    log_error "    ✗ $container has duplicate env names: $duplicates"
                    return 1
                fi
                if [[ "$logging_mode" == disabled ]]; then
                    if contains "$env" 'name: LOG_TYPES' || contains "$env" 'name: LOG_SYSLOG_ADDRESS' \
                        || contains "$env" 'name: ACCESS_LOG_1' || contains "$env" 'name: ERROR_LOG_1'; then
                        log_error "    ✗ $container has automatic syslog env with logging disabled"
                        return 1
                    fi
                else
                    log_info "    Checking $container logging env"
                    assert_env_value "$env" LOG_TYPES "stderr syslog" || return 1
                    assert_env_value "$env" LOG_SYSLOG_ADDRESS "$address" || return 1
                    if [[ "$component" == bunkerweb || "$component" == scheduler ]]; then
                        assert_env_value "$env" ACCESS_LOG_1 "syslog:server=$address,tag=bunkerweb_access" || return 1
                        assert_env_value "$env" ERROR_LOG_1 "syslog:server=$address,tag=bunkerweb" || return 1
                    fi
                fi
            done
            log_success "    ✓ $kind logging: $logging_mode env values and unique names"
        done
    done
    log_info "  Testing scheduler extraEnvs override NGINX log destinations"
    if ! render --set ui.logs.enabled=true --set scheduler.enabled=true \
        --set-json 'scheduler.extraEnvs=[{"name":"ACCESS_LOG_1","value":"/dev/stdout"},{"name":"ERROR_LOG_1","value":"stderr"}]'; then
        log_error "    ✗ Failed to render scheduler NGINX log overrides"
        echo "$output"
        return 1
    fi
    env=$(container_env scheduler-deployment.yaml bunkerweb-scheduler)
    local log_name log_value
    for log_name in ACCESS_LOG_1 ERROR_LOG_1; do
        log_value=/dev/stdout
        if [[ "$log_name" == ERROR_LOG_1 ]]; then
            log_value=stderr
        fi
        if ! awk -v name="$log_name" -v value="$log_value" '
            $1 == "-" && $2 == "name:" && $3 == name {
                getline; sub(/^ +value: /, ""); last = $0; found = 1
            }
            END { exit !(found && (last == value || last == "\"" value "\"")) }
        ' <<< "$env"; then
            log_error "    ✗ Scheduler $log_name override must appear last (expected: $log_value)"
            return 1
        fi
    done
    log_success "    ✓ Scheduler extraEnvs override both NGINX log destinations"

    if ! render --set ui.logs.enabled=true --set scheduler.enabled=false \
        || [[ -n "$(source_block scheduler-deployment.yaml)" ]]; then
        log_error "    ✗ UI logging must not enable the disabled scheduler"
        return 1
    fi
    log_success "    ✓ UI logging preserves scheduler.enabled=false"

    # Test DaemonSet rollout controls
    log_info "  Testing DaemonSet rollout controls (defaults)"
    if render --set bunkerweb.kind=DaemonSet; then
        local ds
        ds=$(source_block bunkerweb-daemonset.yaml)
        if contains "$ds" "type: RollingUpdate" && contains "$ds" "maxUnavailable: 1" && contains "$ds" "minReadySeconds: 0"; then
            log_success "    ✓ DaemonSet renders RollingUpdate, maxUnavailable 1, minReadySeconds 0"
        else
            log_error "    ✗ DaemonSet rollout defaults did not render as expected"
            return 1
        fi
    else
        log_error "    ✗ Failed to render DaemonSet with default rollout settings"
        return 1
    fi

    log_info "  Testing DaemonSet custom rollout budgets"
    for budget in 2 50%; do
        if render --set bunkerweb.kind=DaemonSet --set "bunkerweb.updateStrategy.rollingUpdate.maxUnavailable=$budget"; then
            ds=$(source_block bunkerweb-daemonset.yaml)
            if ! contains "$ds" "maxUnavailable: $budget"; then
                log_error "    ✗ Custom DaemonSet maxUnavailable was not preserved"
                return 1
            fi
        else
            log_error "    ✗ Failed to render custom DaemonSet maxUnavailable"
            return 1
        fi
    done
    if render --set bunkerweb.kind=DaemonSet --set bunkerweb.hostPorts=false \
        --set bunkerweb.updateStrategy.rollingUpdate.maxUnavailable=0 \
        --set bunkerweb.updateStrategy.rollingUpdate.maxSurge=1; then
        ds=$(source_block bunkerweb-daemonset.yaml)
        if ! contains "$ds" "maxUnavailable: 0" || ! contains "$ds" "maxSurge: 1" || contains "$ds" "hostPort:"; then
            log_error "    ✗ Surge rollout settings did not render as expected"
            return 1
        fi
    else
        log_error "    ✗ Failed to render DaemonSet surge strategy without host ports"
        return 1
    fi
    log_success "    ✓ Custom integer/percentage budgets and surge settings are preserved"

    log_info "  Testing DaemonSet OnDelete strategy and custom minReadySeconds"
    if render \
        --set bunkerweb.kind=DaemonSet \
        --set bunkerweb.updateStrategy.type=OnDelete \
        --set bunkerweb.minReadySeconds=30; then
        ds=$(source_block bunkerweb-daemonset.yaml)
        if contains "$ds" "type: OnDelete" && ! contains "$ds" "rollingUpdate:" && contains "$ds" "minReadySeconds: 30"; then
            log_success "    ✓ OnDelete omits rollingUpdate and honours minReadySeconds"
        else
            log_error "    ✗ OnDelete rollout settings did not render as expected"
            return 1
        fi
    else
        log_error "    ✗ Failed to render DaemonSet with OnDelete strategy"
        return 1
    fi

    log_info "  Testing Deployment/StatefulSet ignore DaemonSet rollout controls"
    if render --set bunkerweb.kind=Deployment --set bunkerweb.minReadySeconds=30 \
        && ! contains "$(source_block bunkerweb-deployment.yaml)" "minReadySeconds" \
        && ! contains "$(source_block bunkerweb-deployment.yaml)" "updateStrategy" \
        && render --set bunkerweb.kind=StatefulSet --set bunkerweb.minReadySeconds=30 \
        && ! contains "$(source_block bunkerweb-statefulset.yaml)" "minReadySeconds" \
        && ! contains "$(source_block bunkerweb-statefulset.yaml)" "updateStrategy"; then
        log_success "    ✓ Deployment and StatefulSet carry no DaemonSet rollout fields"
    else
        log_error "    ✗ DaemonSet rollout fields leaked into Deployment or StatefulSet"
        return 1
    fi

    # Test the production release publishes the exact chart archive that passed validation
    log_info "  Testing prebuilt chart publication"
    local publish_test_dir publish_chart publish_args
    publish_test_dir=$(mktemp -d)
    publish_chart="$publish_test_dir/bunkerweb-test.tgz"
    publish_args="$publish_test_dir/curl-args"
    printf 'validated chart archive\n' > "$publish_chart"
    curl() {
        printf '%s\n' "$@" > "$PUBLISH_ARGS_FILE"
    }
    export -f curl
    if PUBLISH_ARGS_FILE="$publish_args" REPO_BEARER_TOKEN=test \
        ./scripts/publish-chart.sh prod "$publish_chart" \
        && contains "$(cat "$publish_args")" "chart=@$publish_chart;type=application/gzip"; then
        log_success "    ✓ Publisher reuses the validated chart archive"
    else
        unset -f curl
        rm -r "$publish_test_dir"
        log_error "    ✗ Publisher did not reuse the validated chart archive"
        return 1
    fi
    unset -f curl
    rm -r "$publish_test_dir"

    log_success "BunkerWeb-specific tests completed"
}

# Main execution
main() {
    echo "========================================"
    echo "BunkerWeb Helm Chart Validation"
    echo "========================================"
    echo

    # Change to repository root if script is run from scripts directory
    if [[ $(basename "$(pwd)") == "scripts" ]]; then
        cd ..
    fi

    # Verify we're in the right directory
    if [[ ! -d "$CHART_PATH" ]]; then
        log_error "Chart not found at $CHART_PATH. Are you in the right directory?"
        exit 1
    fi

    # Run all validation steps
    check_prerequisites
    run_helm_lint
    test_template_generation
    test_bunkerweb_specific
    test_extra_envs_dedupe

    echo
    echo "========================================"
    if [[ $EXIT_CODE -eq 0 ]]; then
        log_success "All validations passed! 🎉"
        echo "Your BunkerWeb Helm chart is ready for deployment."
    else
        log_error "Some validations failed! ❌"
        echo "Please review the errors above and fix them before deployment."
    fi
    echo "========================================"

    exit $EXIT_CODE
}

# Show help
show_help() {
    cat << EOF
BunkerWeb Helm Chart Validation Script

Usage: $0 [options]

Options:
    -h, --help          Show this help message

Examples:
    $0                           # Run all validations
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Run main function
main "$@"
