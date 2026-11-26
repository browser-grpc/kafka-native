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
echo "== building crates (kafka-native + kafka-service)"
(cd "$ROOT/crates/kafka-native" && cargo build) || FAILED=1
(cd "$ROOT/crates/kafka-service" && cargo build && cp target/debug/libkafka_service.so target/debug/libkafka_native.so) || FAILED=1
echo "== c ffi smoke"
cc -O1 -I"$ROOT/crates/kafka-service/include" "$ROOT/crates/kafka-service/tests/ffi_smoke.c" -L"$ROOT/crates/kafka-service/target/debug" -lkafka_native -Wl,-rpath,"$ROOT/crates/kafka-service/target/debug" -o "$TMP/ffi_smoke" && "$TMP/ffi_smoke" 127.0.0.1:19092 || FAILED=1
echo "== python native (apache kafka)"
mkdir -p "$TMP/grpcdc" && cp "$ROOT/python/grpcdc/kafka_native.py" "$ROOT/python/grpcdc/kafka_pb.py" "$TMP/grpcdc/" && touch "$TMP/grpcdc/__init__.py" && cp "$ROOT/crates/kafka-service/target/debug/libkafka_native.so" "$TMP/grpcdc/" && (cd "$TMP" && GRPC_DC_KAFKA_NATIVE_LIB="$TMP/grpcdc/libkafka_native.so" python3 "$ROOT/scripts/native_smoke.py" 127.0.0.1:19092) || FAILED=1
exit "$FAILED"
