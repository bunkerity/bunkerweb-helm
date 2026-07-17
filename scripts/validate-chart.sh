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
        "controller.enabled=false:Without Controller"
        "api.enabled=false:Without API"
        "api.enabled=true,settings.api.useBearerToken.token=test-token,settings.api.ingress.enabled=true,settings.api.ingress.serverName=api.test.com:With API Ingress"
        "settings.ui.ingress.enabled=true,settings.ui.ingress.serverName=ui.test.com:With UI Ingress"
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

    log_info "  Testing API auth guard (enabled without auth must fail)"
    assert_render_fails \
        "API enabled without auth should have failed to render" \
        "API auth guard correctly blocks unauthenticated API" \
        --set api.enabled=true || return 1

    log_info "  Testing MCP auto-enables API (must require auth)"
    assert_render_fails \
        "MCP enabled without API auth should have failed to render" \
        "MCP auto-enables API and enforces the auth guard" \
        --set mcp.enabled=true || return 1

    log_info "  Testing API disabled"
    if render --set api.enabled=false --dry-run; then
        if ! contains "$output" "Source: bunkerweb/templates/api-"; then
            log_success "    ✓ API correctly disabled"
        else
            log_error "    ✗ API templates still generated when disabled"
            return 1
        fi
    else
        log_error "    ✗ Failed to generate templates with API disabled"
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

    # Test syslogAddress helper
    log_info "  Testing syslogAddress helper with default value"
    if render --set ui.logs.enabled=true; then
        # Use grep -c instead of grep -q to avoid SIGPIPE with pipefail
        if contains "$output" "ui-test-bunkerweb"; then
            log_success "    ✓ syslogAddress fallback to service works"
        else
            log_warning "    ⚠ syslogAddress fallback may not be working as expected"
        fi
    else
        log_error "    ✗ Failed to generate templates with UI logs"
        return 1
    fi

    log_info "  Testing syslogAddress helper with custom value"
    if render \
        --set ui.logs.enabled=true \
        --set "ui.logs.syslogAddress=custom-syslog.example.com:514"; then
        if contains "$output" "custom-syslog.example.com:514"; then
            log_success "    ✓ Custom syslogAddress works"
        else
            log_error "    ✗ Custom syslogAddress not applied correctly"
            return 1
        fi
    else
        log_error "    ✗ Failed to generate templates with custom syslog address"
        return 1
    fi

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
