# Kafka native client

An in-process Kafka protocol client for native applications:
the Kafka wire implementation runs in your process — no proxy
process, no gRPC hop. It speaks the Kafka binary protocol to
Apache Kafka (KRaft) or Redpanda, negotiating API versions
per connection.

Three form factors share one wire implementation:

- **kafka-native** (this repo) — in-process library: Rust
  crate, C ABI, per-language FFI wrappers. Native only.
- **kafka-grpc** — generated client stubs over gRPC
  transports from [grpc-over-datachannels](https://github.com/browser-grpc/grpc-over-datachannels);
  browser OK, reaches a broker through the proxy.
- **kafka-proxy** — the [sidecar](https://github.com/browser-grpc/kafka-proxy)
  that bridges the two.

This repository is a generated export (version v0.42.0).

## Use

Rust:

```toml
kafka-native = "0.1"
```

```rust
let broker = kafka_native::Broker::new(config);
broker.create_topics(vec![("events".into(), 3, 1)], 30_000, false).await?;
```

C: link `libkafka_native` and include
`crates/kafka-native/include/kafka_native.h`. Calls take a
method name and the protobuf-encoded request and return the
protobuf-encoded response.

Python (stdlib `ctypes`, same generated messages as the
gRPC client):

```python
from grpcdc.kafka_native import NativeKafkaClient
client = NativeKafkaClient("127.0.0.1:9092")
```

Surface: metadata, produce/consume, producer sessions
(idempotence, transactions), consumer groups, and the admin
operations (configs, partitions, delete-records, groups,
ACLs, transactions) — see [KAFKA.md](KAFKA.md). Plaintext
brokers only for now; SASL/TLS stay on the sidecar path.

## Tests

```sh
docker build -f docker/kafka-native-ci.Dockerfile -t kafka-native-ci .
docker run --rm kafka-native-ci
```

GitHub Actions runs the same image on every push.
