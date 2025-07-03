#!/bin/bash

# CloudTuner Kubernetes Cost Metrics Collector Installation Script
# This script installs the CloudTuner Kubernetes Cost Metrics Collector using Helm

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
NAMESPACE="default"
RELEASE_NAME="kube-cost-metrics-collector"
CHART_VERSION="0.1.2"
REPO_URL="https://invinciblecodes.github.io/k8s-helm-chart"

# Print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if helm is installed
check_helm() {
    if ! command -v helm &> /dev/null; then
        print_error "Helm is not installed. Please install Helm first."
        print_info "Visit: https://helm.sh/docs/intro/install/"
        exit 1
    fi
    print_info "Helm is installed: $(helm version --short)"
}

# Check if kubectl is installed and configured
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        print_error "kubectl is not configured or cluster is not accessible."
        exit 1
    fi
    print_info "kubectl is configured and cluster is accessible"
}

# Add Helm repository
add_helm_repo() {
    print_info "Adding CloudTuner Helm repository..."
    helm repo add cloudtuner "$REPO_URL" || {
        print_error "Failed to add Helm repository"
        exit 1
    }
    
    print_info "Updating Helm repositories..."
    helm repo update || {
        print_error "Failed to update Helm repositories"
        exit 1
    }
}

# Install the chart
install_chart() {
    print_info "Installing CloudTuner Kubernetes Cost Metrics Collector..."
    
    # Create namespace if it doesn't exist
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Install the chart
    helm install "$RELEASE_NAME" cloudtuner/kube-cost-metrics-collector \
        --namespace "$NAMESPACE" \
        --version "$CHART_VERSION" \
        --wait \
        --timeout 300s || {
        print_error "Failed to install the chart"
        exit 1
    }
    
    print_info "Installation completed successfully!"
}

# Show installation status
show_status() {
    print_info "Checking installation status..."
    
    echo ""
    echo "Release Information:"
    helm list -n "$NAMESPACE" | grep "$RELEASE_NAME" || true
    
    echo ""
    echo "Pod Status:"
    kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=kube-cost-metrics-collector" || true
    
    echo ""
    echo "Service Status:"
    kubectl get svc -n "$NAMESPACE" -l "app.kubernetes.io/name=kube-cost-metrics-collector" || true
}

# Usage information
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -n, --namespace NAMESPACE    Kubernetes namespace (default: default)"
    echo "  -r, --release RELEASE_NAME   Helm release name (default: kube-cost-metrics-collector)"
    echo "  -v, --version VERSION        Chart version (default: 0.1.2)"
    echo "  -h, --help                   Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                           # Install with default settings"
    echo "  $0 -n monitoring             # Install in monitoring namespace"
    echo "  $0 -r my-collector -v 0.1.2  # Install with custom release name and version"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -r|--release)
            RELEASE_NAME="$2"
            shift 2
            ;;
        -v|--version)
            CHART_VERSION="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Main installation process
main() {
    print_info "CloudTuner Kubernetes Cost Metrics Collector Installation"
    print_info "=========================================================="
    
    check_helm
    check_kubectl
    add_helm_repo
    install_chart
    show_status
    
    print_info "Installation completed! You can now use the CloudTuner Kubernetes Cost Metrics Collector."
    print_info "For more information, visit: https://github.com/Invinciblecodes/k8s-helm-chart"
}

# Run main function
main