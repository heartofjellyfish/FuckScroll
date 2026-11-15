#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
TASK_BUILD=".build/multi-app-tests"
mkdir -p "$TASK_BUILD"
for MODULE in ManagedSettings FamilyControls DeviceActivity; do
    TASK_LINK=()
    if [[ "$MODULE" != ManagedSettings ]]; then TASK_LINK=(-lManagedSettings); fi
    xcrun swiftc ${TASK_LINK[@]+"${TASK_LINK[@]}"} -module-cache-path .build/SwiftModuleCache -emit-library -emit-module -module-name "$MODULE" -I "$TASK_BUILD" -L "$TASK_BUILD" Tests/MonitoringDoubles/"$MODULE".swift -o "$TASK_BUILD/lib$MODULE.dylib" -emit-module-path "$TASK_BUILD/$MODULE.swiftmodule"
done
xcrun swiftc -D MONITOR_TESTS -module-cache-path .build/SwiftModuleCache -I "$TASK_BUILD" -L "$TASK_BUILD" -lManagedSettings -lFamilyControls -lDeviceActivity ScrollStopper/Shared/SessionState.swift ScrollStopper/Shared/Policy.swift ScrollStopper/Shared/SharedStore.swift ScrollStopper/Shared/ReminderTrial.swift Tests/MultiAppMonitoringTests.swift -o "$TASK_BUILD/run"
DYLD_LIBRARY_PATH="$PWD/$TASK_BUILD" "$TASK_BUILD/run"
