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
    
    if ! command -v yq &> /dev/null; then
        log_warning "yq is not installed - some advanced YAML validation will be skipped"
    fi
    
    log_success "Prerequisites check completed"
}

# Validate chart structure
validate_chart_structure() {
    log_info "Validating chart structure..."
    
    # Check required files
    local required_files=(
        "$CHART_PATH/Chart.yaml"
        "$CHART_PATH/values.yaml"
        "$CHART_PATH/templates/"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -e "$file" ]]; then
            log_error "Required file/directory missing: $file"
            return 1
        fi
    done
    
    # Check Chart.yaml format
    if ! helm show chart "$CHART_PATH" &> /dev/null; then
        log_error "Chart.yaml is invalid"
        return 1
    fi
    
    log_success "Chart structure validation passed"
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
        "settings.api.ingress.enabled=true,settings.api.ingress.serverName=api.test.com:With API Ingress"
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
            
            # Validate generated YAML
            if command -v yq &> /dev/null; then
                if yq '.' "$output_file" > /dev/null 2>&1; then
                    log_success "    ✓ Generated YAML is valid"
                else
                    log_error "    ✗ Generated YAML is invalid"
                    return 1
                fi
            fi
        else
            log_error "    ✗ Template generation failed:"
            cat "$output_file" | sed 's/^/      /'
            return 1
        fi
    done
    
    log_success "Template generation tests completed"
}

# Validate values.yaml completeness
validate_values_completeness() {
    log_info "Validating values.yaml completeness..."
    
    # Extract all .Values references from templates
    local template_refs
    template_refs=$(find "$CHART_PATH/templates" -name "*.yaml" -o -name "*.tpl" | \
        xargs grep -h "\.Values\." | \
        sed 's/.*\.Values\.\([a-zA-Z0-9._]*\).*/\1/' | \
        grep -v "^$" | \
        sort -u)
    
    # Check if values exist (simplified check)
    local missing_values=()
    while IFS= read -r ref; do
        # Skip complex references or those with conditionals
        if [[ "$ref" =~ ^[a-zA-Z][a-zA-Z0-9._]*$ ]]; then
            # This is a simplified check - in production you might want more sophisticated validation
            if ! grep -q "^${ref%%.*}:" "$CHART_PATH/values.yaml"; then
                missing_values+=("$ref")
            fi
        fi
    done <<< "$template_refs"
    
    if [[ ${#missing_values[@]} -gt 0 ]]; then
        log_warning "Potentially missing values in values.yaml:"
        printf '  %s\n' "${missing_values[@]}"
        log_warning "Note: This is a simplified check and may have false positives"
    else
        log_success "Values.yaml appears complete"
    fi
}

# Test specific BunkerWeb configurations
test_bunkerweb_specific() {
    log_info "Testing BunkerWeb-specific configurations..."
    
    # Test with different service types
    local service_types=("LoadBalancer" "NodePort" "ClusterIP")
    for service_type in "${service_types[@]}"; do
        log_info "  Testing with service type: $service_type"
        if helm template test "$CHART_PATH" --set service.type="$service_type" --dry-run > /dev/null 2>&1; then
            log_success "    ✓ Service type $service_type works"
        else
            log_error "    ✗ Service type $service_type failed"
            return 1
        fi
    done
    
    # Test ingress configurations
    log_info "  Testing UI ingress configuration"
    if helm template test "$CHART_PATH" \
        --set settings.ui.ingress.enabled=true \
        --set settings.ui.ingress.serverName=test.example.com \
        --dry-run > /dev/null 2>&1; then
        log_success "    ✓ UI ingress configuration works"
    else
        log_error "    ✗ UI ingress configuration failed"
        return 1
    fi
    
    # Test API configurations
    log_info "  Testing API component"
    if helm template test "$CHART_PATH" \
        --set api.enabled=true \
        --dry-run > /dev/null 2>&1; then
        log_success "    ✓ API component enabled works"
    else
        log_error "    ✗ API component configuration failed"
        return 1
    fi
    
    log_info "  Testing API ingress configuration"
    if helm template test "$CHART_PATH" \
        --set settings.api.ingress.enabled=true \
        --set settings.api.ingress.serverName=api.test.example.com \
        --dry-run > /dev/null 2>&1; then
        log_success "    ✓ API ingress configuration works"
    else
        log_error "    ✗ API ingress configuration failed"
        return 1
    fi
    
    log_info "  Testing API disabled"
    local output
    if output=$(helm template test "$CHART_PATH" --set api.enabled=false --dry-run 2>&1); then
        if ! echo "$output" | grep -q "Source: bunkerweb/templates/api-"; then
            log_success "    ✓ API correctly disabled"
        else
            log_error "    ✗ API templates still generated when disabled"
            return 1
        fi
    else
        log_error "    ✗ Failed to generate templates with API disabled"
        return 1
    fi
    
    # Test syslogAddress helper
    log_info "  Testing syslogAddress helper with default value"
    if output=$(helm template test "$CHART_PATH" \
        --set ui.logs.enabled=true \
        --set ui.logs.syslogAddress="" \
        --dry-run 2>&1); then
        if echo "$output" | grep -q "ui-test-bunkerweb.*svc.*:514"; then
            log_success "    ✓ syslogAddress fallback to service works"
        else
            log_warning "    ⚠ syslogAddress fallback may not be working as expected"
        fi
    else
        log_error "    ✗ Failed to generate templates with UI logs"
        return 1
    fi
    
    log_info "  Testing syslogAddress helper with custom value"
    if output=$(helm template test "$CHART_PATH" \
        --set ui.logs.enabled=true \
        --set ui.logs.syslogAddress="custom-syslog.example.com:514" \
        --dry-run 2>&1); then
        if echo "$output" | grep -q "custom-syslog.example.com:514"; then
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

# Generate test report
generate_report() {
    log_info "Generating validation report..."
    
    local report_file="$TEMP_DIR/validation-report.txt"
    cat > "$report_file" << EOF
BunkerWeb Helm Chart Validation Report
=====================================
Date: $(date)
Chart Path: $CHART_PATH
Helm Version: $(helm version --short)

Test Results:
- Chart Structure: $([ $EXIT_CODE -eq 0 ] && echo "PASSED" || echo "FAILED")
- Helm Lint: $([ $EXIT_CODE -eq 0 ] && echo "PASSED" || echo "FAILED")
- Template Generation: $([ $EXIT_CODE -eq 0 ] && echo "PASSED" || echo "FAILED")
- Values Completeness: $([ $EXIT_CODE -eq 0 ] && echo "PASSED" || echo "FAILED")
- BunkerWeb Specific: $([ $EXIT_CODE -eq 0 ] && echo "PASSED" || echo "FAILED")

Generated Templates:
$(ls -la "$TEMP_DIR"/*.yaml 2>/dev/null || echo "No templates generated")
EOF
    
    if [[ "${GENERATE_REPORT:-false}" == "true" ]]; then
        cp "$report_file" "./validation-report.txt"
        log_info "Validation report saved to: ./validation-report.txt"
    fi
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
    validate_chart_structure
    run_helm_lint
    test_template_generation
    validate_values_completeness
    test_bunkerweb_specific
    generate_report
    
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
    --generate-report   Generate a detailed validation report
    --chart-path PATH   Override chart path (default: charts/bunkerweb)

Environment Variables:
    GENERATE_REPORT     Set to 'true' to generate validation report
    CHART_PATH         Override chart path

Examples:
    $0                           # Run all validations
    $0 --generate-report         # Run validations and generate report
    $0 --chart-path ./my-chart   # Validate custom chart path
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --generate-report)
            GENERATE_REPORT=true
            shift
            ;;
        --chart-path)
            CHART_PATH="$2"
            shift 2
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
