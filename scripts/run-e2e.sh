#!/usr/bin/env bash
# Run the kafka-native legs (Rust direct, Rust FFI, C
# smoke, Python) against a real Apache Kafka broker
# started here and killed on exit.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KAFKA_HOME="${KAFKA_HOME:-/opt/kafka}"
TMP="$(mktemp -d)"
PIDS=()
cleanup() {
  for pid in "${PIDS[@]:-}"; do
    [ -n "$pid" ] && kill "$pid" 2>/dev/null || true
  done
  rm -rf "$TMP"
}
trap cleanup EXIT
port_open() {
  (exec 3<>"/dev/tcp/${1%:*}/${1##*:}") 2>/dev/null && exec 3>&- 3<&-
}
wait_port() {
  local deadline=$((SECONDS + $2))
  while ! port_open "$1"; do
    if [ $SECONDS -ge $deadline ]; then
      echo "FAIL: $3 did not open $1 within $2s" >&2
      return 1
    fi
    sleep 1
  done
  echo "ok: $3 listening on $1"
}
start_kafka() {
  local props="$TMP/kafka.properties"
  cat > "$props" <<EOF
process.roles=broker,controller
node.id=1
listeners=PLAINTEXT://0.0.0.0:19092,CONTROLLER://0.0.0.0:19094
advertised.listeners=PLAINTEXT://127.0.0.1:19092
controller.listener.names=CONTROLLER
controller.quorum.voters=1@127.0.0.1:19094
log.dirs=$TMP/kafka-logs
offsets.topic.replication.factor=1
transaction.state.log.replication.factor=1
transaction.state.log.min.isr=1
group.initial.rebalance.delay.ms=0
num.partitions=1
EOF
  local cluster_id
  cluster_id="$("$KAFKA_HOME/bin/kafka-storage.sh" random-uuid)" || return 1
  "$KAFKA_HOME/bin/kafka-storage.sh" format -t "$cluster_id" -c "$props" --ignore-formatted >"$TMP/kafka-format.log" 2>&1 || return 1
  "$KAFKA_HOME/bin/kafka-server-start.sh" "$props" >"$TMP/kafka.log" 2>&1 &
  PIDS+=($!)
  wait_port 127.0.0.1:19092 180 kafka || { tail -20 "$TMP/kafka.log" >&2; return 1; }
}
FAILED=0
start_kafka || exit 1
echo "== rust direct + admin (apache kafka)"
(cd "$ROOT/rust" && KAFKA_PROXY_E2E_BROKER=127.0.0.1:19092 cargo test --test kafka_direct_e2e --test kafka_admin_e2e) || FAILED=1
echo "== rust ffi (apache kafka)"
(cd "$ROOT/rust" && KAFKA_PROXY_E2E_BROKER=127.0.0.1:19092 cargo test --test kafka_native_ffi_e2e) || FAILED=1
echo "== building libkafka_native"
(cd "$ROOT/crates/kafka-native" && cargo build) || FAILED=1
echo "== c ffi smoke"
cc -O1 -I"$ROOT/crates/kafka-native/include" "$ROOT/crates/kafka-native/tests/ffi_smoke.c" -L"$ROOT/crates/kafka-native/target/debug" -lkafka_native -Wl,-rpath,"$ROOT/crates/kafka-native/target/debug" -o "$TMP/ffi_smoke" && "$TMP/ffi_smoke" 127.0.0.1:19092 || FAILED=1
echo "== python native (apache kafka)"
(cd "$ROOT/python" && KAFKA_E2E_BROKER=127.0.0.1:19092 GRPC_DC_KAFKA_NATIVE_LIB="$ROOT/crates/kafka-native/target/debug/libkafka_native.so" python3 -m unittest tests.test_kafka_native) || FAILED=1
exit "$FAILED"
