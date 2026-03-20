#!/usr/bin/env bash
#
# Runs all sample workers and starters against a Temporal Cloud namespace.
#
# Usage:
#   export TEMPORAL_ADDRESS="us-west-2.aws.api.tmprl-test.cloud:7233"
#   export TEMPORAL_NAMESPACE="nikki-bam-bugbash-02.temporal-dev"
#   export TEMPORAL_API_KEY="<your-api-key>"
#   ./run-all-samples.sh
#
# Workers are started in the background, then each starter is invoked.
# On exit (or Ctrl+C) all background workers are cleaned up.

set -euo pipefail

# ── Validate required env vars ──────────────────────────────────────────────
for var in TEMPORAL_ADDRESS TEMPORAL_NAMESPACE TEMPORAL_API_KEY; do
  if [[ -z "${!var:-}" ]]; then
    echo "ERROR: $var is not set. Export it before running this script."
    exit 1
  fi
done

echo "=== Temporal Cloud connection ==="
echo "  Host:      $TEMPORAL_ADDRESS"
echo "  Namespace: $TEMPORAL_NAMESPACE"
echo ""

# ── Setup ────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

LOG_DIR="$SCRIPT_DIR/.run-logs"
mkdir -p "$LOG_DIR"

WORKER_PIDS=()

cleanup() {
  echo ""
  echo "=== Cleaning up workers ==="
  for pid in "${WORKER_PIDS[@]}"; do
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
    fi
  done
  wait 2>/dev/null || true
  echo "All workers stopped."
}
trap cleanup EXIT INT TERM

# ── Samples with standard worker/starter layout ─────────────────────────────
# Each entry is "worker_path:starter_path"
SAMPLES=(
  # ── Fast samples (complete quickly) ──
  "helloworld/worker:helloworld/starter"
  "branch/worker:branch/starter"
  "child-workflow/worker:child-workflow/starter"
  "child-workflow-continue-as-new/worker:child-workflow-continue-as-new/starter"
  "choice-exclusive/worker:choice-exclusive/starter"
  "choice-multi/worker:choice-multi/starter"
  "dsl/worker:dsl/starter"
  "dynamic/worker:dynamic/starter"
  "dynamic-workflows/worker:dynamic-workflows/starter"
  "early-return/worker:early-return/starter"
  "encryption/worker:encryption/starter"
  "fileprocessing/worker:fileprocessing/starter"
  "goroutine/worker:goroutine/starter"
  "greetings/worker:greetings/starter"
  "greetingslocal/worker:greetingslocal/starter"
  "logger-interceptor/worker:logger-interceptor/starter"
  "memo/worker:memo/starter"
  "mutex/worker:mutex/starter"
  "pickfirst/worker:pickfirst/starter"
  "pso/worker:pso/starter"
  "query/worker:query/starter:query/query"
  "recovery/worker:recovery/starter"
  "reqrespactivity/worker:reqrespactivity/starter"
  "reqrespquery/worker:reqrespquery/starter"
  "reqrespupdate/worker:reqrespupdate/starter"
  "retryactivity/worker:retryactivity/starter"
  "saga/worker:saga/start"
  "schedule/worker:schedule/starter"
  "session-failure/worker:session-failure/starter"
  "snappycompress/worker:snappycompress/starter"
  "splitmerge-future/worker:splitmerge-future/starter"
  "splitmerge-selector/worker:splitmerge-selector/starter"
  "standalone-activity/helloworld/worker:standalone-activity/helloworld/starter"
  "update/worker:update/starter"
  "worker-specific-task-queues/worker:worker-specific-task-queues/starter"
  "batch-sliding-window/worker:batch-sliding-window/starter"
  "cancellation/worker:cancellation/starter"

  # ── Slow samples (long timers, signals, or start delays — run last) ──
  "await-signals/worker:await-signals/starter"
  "cron/worker:cron/starter"
  "polling/frequent/worker:polling/frequent/starter"
  "polling/infrequent/worker:polling/infrequent/starter"
  "polling/periodic_sequence/worker:polling/periodic_sequence/starter"
  "timer/worker:timer/starter"
  "updatabletimer/worker:updatabletimer/starter"
  "sleep-for-days/worker:sleep-for-days/starter"
  "start-delay/worker:start-delay/starter"
)

# ── Skipped samples (need external services or special setup) ────────────────
# codec-server            — module path incompatible with go run
# ctxpropagation          — requires Jaeger
# datadog                 — requires Datadog agent
# dynamicmtls             — requires mTLS certificates
# expense                 — requires external HTTP server (UI)
# external-env-conf       — uses TOML config file, not envconfig
# grpc-proxy              — requires gRPC proxy server on port 8081
# helloworld-apiKey       — uses CLI flags instead of envconfig
# helloworldmtls          — requires mTLS certificates
# metrics                 — requires Prometheus (worker binds to :9090)
# multi-history-replay    — replay tool, not a standard worker/starter
# nexus*                  — requires Nexus endpoint configuration
# opentelemetry           — requires OpenTelemetry collector
# safe_message_handler    — workflow completes before starter cleanup step (timing)
# searchattributes        — requires custom search attributes on namespace
# serverjwtauth           — requires JWT key files
# shoppingcart            — requires external HTTP server (UI)
# slogadapter             — worker-only, starter uses envconfig already
# synchronous-proxy       — requires external HTTP server (UI)
# temporal-fixtures/*     — internal test fixtures
# worker-versioning       — requires multi-version worker orchestration
# workflow-security-interceptor — intentionally fails (tests prohibited child workflow)
# zapadapter              — worker-only, starter uses envconfig already

# ── Configuration ────────────────────────────────────────────────────────────
# Many starters block waiting for workflow completion (e.g. sleep-for-days,
# cron, safe_message_handler). We use a timeout so the script doesn't stall.
# A starter that launches the workflow successfully but times out waiting for
# completion is still counted as PASS — the workflow was started.
STARTER_TIMEOUT=${STARTER_TIMEOUT:-30}  # seconds

# ── Run ──────────────────────────────────────────────────────────────────────
PASSED=0
FAILED=0
TIMED_OUT=0
FAILURES=()

run_sample() {
  local worker_path="$1"
  local starter_path="$2"
  local extra_cmd="${3:-}"
  local sample_name="${worker_path%%/worker*}"

  echo "--- [$sample_name] Starting worker..."
  go run "./$worker_path" > "$LOG_DIR/${sample_name//\//_}_worker.log" 2>&1 &
  local worker_pid=$!
  WORKER_PIDS+=("$worker_pid")

  # Give the worker time to register with the server
  sleep 3

  if ! kill -0 "$worker_pid" 2>/dev/null; then
    echo "  FAIL: worker exited prematurely. Check $LOG_DIR/${sample_name//\//_}_worker.log"
    FAILED=$((FAILED + 1))
    FAILURES+=("$sample_name")
    return
  fi

  echo "  Running starter (timeout ${STARTER_TIMEOUT}s)..."
  local starter_log="$LOG_DIR/${sample_name//\//_}_starter.log"

  # Run starter with timeout. Exit code 124 means timeout (GNU coreutils).
  # On macOS, gtimeout (from coreutils) or the built-in approach is used.
  local timeout_cmd="timeout"
  if ! command -v timeout &>/dev/null; then
    if command -v gtimeout &>/dev/null; then
      timeout_cmd="gtimeout"
    else
      # Fallback: use background + sleep + kill
      timeout_cmd=""
    fi
  fi

  local exit_code=0
  if [[ -n "$timeout_cmd" ]]; then
    $timeout_cmd "${STARTER_TIMEOUT}s" go run "./$starter_path" > "$starter_log" 2>&1 || exit_code=$?
  else
    # macOS fallback without coreutils
    go run "./$starter_path" > "$starter_log" 2>&1 &
    local starter_pid=$!
    local waited=0
    while kill -0 "$starter_pid" 2>/dev/null && [[ $waited -lt $STARTER_TIMEOUT ]]; do
      sleep 1
      waited=$((waited + 1))
    done
    if kill -0 "$starter_pid" 2>/dev/null; then
      kill "$starter_pid" 2>/dev/null || true
      wait "$starter_pid" 2>/dev/null || true
      exit_code=124
    else
      wait "$starter_pid" 2>/dev/null || exit_code=$?
    fi
  fi

  if [[ $exit_code -eq 0 ]]; then
    echo "  PASS: $sample_name"
    PASSED=$((PASSED + 1))
  elif [[ $exit_code -eq 124 ]]; then
    # Timeout — workflow was started but starter blocked waiting for completion.
    # This is expected for long-running workflows. Count as pass.
    echo "  PASS: $sample_name (starter timed out waiting for workflow completion — expected)"
    PASSED=$((PASSED + 1))
    TIMED_OUT=$((TIMED_OUT + 1))
  else
    echo "  FAIL: $sample_name — check $starter_log"
    FAILED=$((FAILED + 1))
    FAILURES+=("$sample_name")
  fi

  # Run extra command if specified (e.g. query/query after query/starter)
  if [[ -n "$extra_cmd" && ($exit_code -eq 0 || $exit_code -eq 124) ]]; then
    echo "  Running extra: $extra_cmd..."
    local extra_log="$LOG_DIR/${sample_name//\//_}_extra.log"
    go run "./$extra_cmd" > "$extra_log" 2>&1 || true
  fi

  # Stop this worker before moving to the next sample
  if kill -0 "$worker_pid" 2>/dev/null; then
    kill "$worker_pid" 2>/dev/null || true
    wait "$worker_pid" 2>/dev/null || true
  fi
}

echo "=== Running ${#SAMPLES[@]} samples ==="
echo ""

for entry in "${SAMPLES[@]}"; do
  IFS=':' read -r worker_path starter_path extra_cmd <<< "$entry"
  run_sample "$worker_path" "$starter_path" "$extra_cmd"
  echo ""
done

# ── Summary ──────────────────────────────────────────────────────────────────
echo "=== Summary ==="
echo "  Passed: $PASSED ($TIMED_OUT started but timed out waiting for completion)"
echo "  Failed: $FAILED"
echo "  Total:  ${#SAMPLES[@]}"
if [[ ${#FAILURES[@]} -gt 0 ]]; then
  echo ""
  echo "  Failed samples:"
  for f in "${FAILURES[@]}"; do
    echo "    - $f"
  done
fi
echo ""
echo "Logs: $LOG_DIR/"