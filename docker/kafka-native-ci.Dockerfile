# Kafka native CI — generated. DO NOT EDIT.
# Builds libkafka_native and runs the direct, FFI, Python,
# and C test legs against a real Apache Kafka fixture,
# all inside the image.
#   docker build -f docker/kafka-native-ci.Dockerfile -t kafka-native-ci .
#   docker run --rm kafka-native-ci
FROM rust:1-bookworm
RUN apt-get update && apt-get install -y --no-install-recommends default-jdk-headless curl ca-certificates procps python3 gcc && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL https://downloads.apache.org/kafka/4.3.1/kafka_2.13-4.3.1.tgz -o /tmp/kafka.tgz && mkdir -p /opt/kafka && tar -xzf /tmp/kafka.tgz -C /opt/kafka --strip-components=1 && rm /tmp/kafka.tgz
ENV KAFKA_HOME=/opt/kafka
WORKDIR /src
COPY rust ./rust
COPY crates ./crates
COPY python ./python
COPY proto ./proto
COPY fixtures ./fixtures
COPY scripts/run-e2e.sh ./scripts/run-e2e.sh
CMD ["bash", "scripts/run-e2e.sh"]
