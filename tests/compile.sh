#!/bin/bash
# Compiles every QML file of the package with the installed modules and our plugin's build
set -e
cd "$(dirname "$0")/.."
ui=package/contents/ui
mapfile -t files < <(cd "$ui" && find . -name '*.qml' | sed 's|^\./||' | sort)
status=0
output=$(QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 \
    QML_IMPORT_PATH="$PWD/build/bin:${QML_IMPORT_PATH}" \
    timeout 120 qml6 tests/compile.qml -- "${files[@]}" "file://$PWD/$ui/" 2>&1) || status=$?
grep -E '^(qml: )?(FAIL|[0-9]+ of [0-9]+ compiled)' <<<"$output" || echo "$output"
exit "$status"
