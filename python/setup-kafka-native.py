# Marks the wheel as platform-specific (it bundles
# libkafka_native) instead of py3-none-any. Wheels carry
# a prebuilt library; the sdist carries the crate sources
# and BuildPy compiles them with cargo at install time.
import glob
import os
import shutil
import subprocess

from setuptools import setup
from setuptools.command.build_py import build_py
from wheel.bdist_wheel import bdist_wheel

LIB_NAMES = ("libkafka_native.so", "libkafka_native.dylib", "kafka_native.dll")


class PlatformWheel(bdist_wheel):
    def finalize_options(self):
        super().finalize_options()
        self.root_is_pure = False


class BuildPy(build_py):
    def run(self):
        super().run()
        dest_dir = os.path.join(self.build_lib, "grpcdc")
        if any(os.path.exists(os.path.join(dest_dir, n)) for n in LIB_NAMES):
            return
        here = os.path.dirname(os.path.abspath(__file__))
        crate = next(
            (
                c
                for c in (
                    os.path.join(here, "crates", "kafka-native"),
                    os.path.join(here, "..", "crates", "kafka-native"),
                )
                if os.path.exists(os.path.join(c, "Cargo.toml"))
            ),
            os.path.join(here, "crates", "kafka-native"),
        )
        subprocess.check_call(["cargo", "build", "--release"], cwd=crate)
        built = []
        for name in LIB_NAMES:
            built += glob.glob(os.path.join(crate, "target", "release", name))
        if not built:
            raise RuntimeError("cargo build produced no libkafka_native library")
        os.makedirs(dest_dir, exist_ok=True)
        shutil.copy(built[0], dest_dir)


setup(cmdclass={"bdist_wheel": PlatformWheel, "build_py": BuildPy})
