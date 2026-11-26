# AGENTS.md

This repository is a **generated export** of grpc-over-datachannels v0.48.5 (source commit `346cf7831e1e20150020ae22b8f8b221ee21ed9a`), produced by the
project's code generator. It is a release snapshot, not the
development tree.

## For AI agents and contributors

- Do not treat this tree as the source of truth: generated files
  are overwritten on every release, and changes to generated
  files here cannot be merged upstream.
- Use this repo as a library/examples snapshot: embed the in-process Kafka client (Rust crate, C ABI, Python bindings).
- Build/test: cargo build/test in crates/kafka-native + crates/kafka-service; FFI smoke test in crates/kafka-service/tests/.
- Report bugs or request features in the main repository:
  https://github.com/browser-grpc/grpc-over-datachannels/issues
  (include the release version above and the language).
- Docs: https://browser-grpc.github.io/grpc-over-datachannels/
