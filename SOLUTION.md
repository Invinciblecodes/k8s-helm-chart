# CloudTuner Kubecost Integration Fix

## Problem Summary

The Kubecost collector was failing to send metrics to CloudTuner with continuous **HTTP 400 Bad Request** errors. The remote write endpoint was rejecting all requests from Prometheus.

## Root Cause Analysis

### Issue 1: Missing Cloud-Account-Id Header
- **Problem**: The `Cloud-Account-Id` header was not being included in remote write requests
- **Cause**: Helm chart template only adds authentication headers when remote write name equals "optscale"
- **Symptom**: HTTP 400 errors in diproxy logs

### Issue 2: Incorrect Remote Write Configuration
- **Problem**: Remote write was named "cloudtuner" instead of "optscale"
- **Cause**: Chart template has hardcoded condition `{{- if eq $value.name "optscale" }}`
- **Impact**: Authentication headers and basic auth were not being applied

### Issue 3: Missing Password Secret
- **Problem**: Password file `/etc/optscale/auth/passwd` was not available
- **Cause**: Required secret `prometheus-server-password-secret` was not created
- **Impact**: Basic authentication could not be performed

## Solution Implementation

### Step 1: Fix Remote Write Name
**File**: `values-local.yaml` and `values-production.yaml`
```yaml
# Changed from:
remote_write:
- name: cloudtuner  # ❌ Wrong name

# To:
remote_write:
- name: optscale    # ✅ Correct name
```

### Step 2: Create Password Secret
```bash
kubectl create secret generic kube-cost-metrics-collector-prometheus-server-password-secret \
  -n cloudtuner --from-literal=passwd=cloudtuner
```

### Step 3: Upgrade Helm Chart
```bash
helm upgrade kube-cost-metrics-collector ./charts/kube-cost-metrics-collector \
  --namespace cloudtuner \
  --values values-local.yaml
```

## Final Working Configuration

The corrected Prometheus configuration now includes:

```yaml
remote_write:
- name: optscale
  url: http://diproxy.default.svc.cluster.local/storage/api/v2/write
  headers:
    Cloud-Account-Id: f6a64c39-41ec-492f-ad39-242e5943d176
  basic_auth:
    username: cloudtuner
    password_file: /etc/optscale/auth/passwd
  tls_config:
    insecure_skip_verify: true
```

## Authentication Flow

1. **Prometheus** sends metrics with required headers:
   - `Cloud-Account-Id: f6a64c39-41ec-492f-ad39-242e5943d176`
   - `Authorization: Basic <base64-credentials>`

2. **diproxy** validates:
   - Checks Cloud-Account-Id header exists (prevents HTTP 400)
   - Validates credentials against stored cloud account config
   - Forwards authenticated requests to Thanos

3. **Thanos Receive** stores metrics with tenant isolation based on Cloud-Account-Id

## Verification

### Before Fix
```
# diproxy logs
WARNING:tornado.access:400 POST /storage/api/v2/write (10.244.8.105) 0.13ms

# Prometheus logs  
msg="non-recoverable error" err="server returned HTTP status 400 Bad Request: "
```

### After Fix
```
# diproxy logs
INFO:tornado.access:200 POST /storage/api/v2/write (10.244.8.149) 11.68ms

# Prometheus logs
msg="Done replaying WAL" duration=7.660670671s
```

## Key Learnings

1. **Chart Template Dependencies**: The Kubecost chart template has hardcoded expectations for remote write naming
2. **Authentication Requirements**: CloudTuner's diproxy requires both `Cloud-Account-Id` header and basic auth
3. **Error Code Mapping**: 
   - HTTP 400 = Missing Cloud-Account-Id header
   - HTTP 401 = Invalid/missing credentials
   - HTTP 422 = Cloud account not found/misconfigured

## Files Created/Modified

- ✅ `values-local.yaml` - Local development configuration
- ✅ `values-production.yaml` - Production deployment template  
- ✅ `install-local.sh` - Local installation script
- ✅ `install-production.sh` - Production installation script
- ✅ `README-deployment.md` - Complete deployment guide
- ✅ `SOLUTION.md` - This troubleshooting guide

## Production Deployment Notes

For production environments, ensure:
1. Update `dataSourceId` with actual CloudTuner data source ID
2. Replace `username`/`password` with production credentials  
3. Update `url` to point to your CloudTuner domain
4. Configure proper TLS certificates if using custom CA

The solution is now production-ready and can be deployed to any Kubernetes cluster that needs to send cost metrics to CloudTuner.