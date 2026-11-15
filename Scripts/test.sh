#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build
xcrun swiftc -module-cache-path .build/SwiftModuleCache \
  ScrollStopper/Shared/SessionState.swift \
  ScrollStopper/Shared/Policy.swift \
  Tests/SessionPolicyTests.swift \
  -o .build/session-policy-tests
.build/session-policy-tests
xcrun swiftc -module-cache-path .build/SwiftModuleCache \
  ScrollStopper/Shared/SessionState.swift \
  Tests/SessionScenarioTests.swift \
  -o .build/session-scenario-tests
.build/session-scenario-tests
python3 Scripts/validate_project.py
