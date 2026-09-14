#!/usr/bin/env python3
"""Test the production analysis contract on the host, without a mobile app build.

The Apple Foundation Models and Android runtime branches still need native QA.
Use Xcode's DEVELOPER_DIR on macOS so Swift Testing is available.
"""
from pathlib import Path
import shutil
import subprocess
import tempfile

project = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix="dut-analysis-tests-") as directory:
    root = Path(directory)
    (root / "Package.swift").write_text('''// swift-tools-version: 6.1
import PackageDescription
let package = Package(name: "AnalysisChecks", platforms: [.macOS(.v14)], targets: [
    .target(name: "DontUnplugThatShared"),
    .target(name: "DontUnplugThat", dependencies: ["DontUnplugThatShared"]),
    .testTarget(name: "AnalysisTests", dependencies: ["DontUnplugThat"])
])
''')
    shutil.copytree(project / "Shared/Sources/DontUnplugThatShared",
                    root / "Sources/DontUnplugThatShared")
    (root / "Sources/DontUnplugThat").mkdir()
    shutil.copy(project / "App/Sources/DontUnplugThat/OnDeviceAnalyzer.swift",
                root / "Sources/DontUnplugThat")
    (root / "Tests/AnalysisTests").mkdir(parents=True)
    shutil.copy(project / "App/Tests/DontUnplugThatTests/OnDeviceAnalyzerTests.swift",
                root / "Tests/AnalysisTests")
    subprocess.run(["xcrun", "swift", "test", "--package-path", str(root)], check=True)
