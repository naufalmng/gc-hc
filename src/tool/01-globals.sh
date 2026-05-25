# Mutable globals: CLI flags, runtime state, and Grafana Cloud credentials.
# Defaults are intentionally tolerant; validate_config enforces correctness
# before any network call.

ACTION="help"
INTERVAL="5m"
TIMEOUT="10"
QUIET="false"
JSON="false"
YES="false"
FORCE="false"
LAST_STEP="init"

GCLOUD_HOSTED_METRICS_URL="${GCLOUD_HOSTED_METRICS_URL:-}"
GCLOUD_HOSTED_METRICS_ID="${GCLOUD_HOSTED_METRICS_ID:-}"
GCLOUD_HOSTED_LOGS_URL="${GCLOUD_HOSTED_LOGS_URL:-}"
GCLOUD_HOSTED_LOGS_ID="${GCLOUD_HOSTED_LOGS_ID:-}"
GCLOUD_FM_URL="${GCLOUD_FM_URL:-}"
GCLOUD_RW_API_KEY="${GCLOUD_RW_API_KEY:-}"

GC_HC_TIMEOUT="${GC_HC_TIMEOUT:-10}"
GC_HC_RETRIES="${GC_HC_RETRIES:-2}"
GC_HC_RETRY_DELAY="${GC_HC_RETRY_DELAY:-2}"
GC_HC_DNS="${GC_HC_DNS:-true}"
GC_HC_TLS="${GC_HC_TLS:-true}"
GC_HC_LOKI_WRITE="${GC_HC_LOKI_WRITE:-true}"
GC_HC_PROM_QUERY="${GC_HC_PROM_QUERY:-true}"
GC_HC_FLEET="${GC_HC_FLEET:-true}"

CHECKS=()
PASS=0
WARN=0
FAIL=0
SKIP=0
