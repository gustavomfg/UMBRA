#!/usr/bin/env bash
# Builds the Nocturne.Presentation QML module into build/qml/. The plugin uses
# Qt's QPA native interface, so it must be built against the exact Qt version
# that will load it (build inside the VM guest for the guest).
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source_dir="$project_root/presentation"
build_dir="$project_root/build/presentation"
module_dir="$project_root/build/qml/Nocturne/Presentation"
protocol_xml="${PRESENTATION_TIME_XML:-/usr/share/wayland-protocols/stable/presentation-time/presentation-time.xml}"
moc="${QT_MOC:-/usr/lib/qt6/moc}"
qt_version="$(pkg-config --modversion Qt6Gui)"

mkdir -p "$build_dir" "$module_dir"
wayland-scanner client-header "$protocol_xml" "$build_dir/presentation-time-client-protocol.h"
wayland-scanner private-code "$protocol_xml" "$build_dir/presentation-time-protocol.c"

qt_include="$(pkg-config --variable=includedir Qt6Gui)"
read -r -a qt_flags <<< "$(pkg-config --cflags Qt6Quick Qt6Qml Qt6Gui wayland-client)"
read -r -a qt_libs <<< "$(pkg-config --libs Qt6Quick Qt6Qml Qt6Gui wayland-client)"

"$moc" "${qt_flags[@]}" "$source_dir/presentationprobe.h" -o "$build_dir/moc_presentationprobe.cpp"
"$moc" "${qt_flags[@]}" "$source_dir/plugin.cpp" -o "$build_dir/plugin.moc"

cc -c -fPIC -O2 "$build_dir/presentation-time-protocol.c" -o "$build_dir/presentation-time-protocol.o"
c++ -std=c++17 -shared -fPIC -O2 -Wall -Wextra \
    "${qt_flags[@]}" \
    -I"$qt_include/QtGui/$qt_version" -I"$qt_include/QtGui/$qt_version/QtGui" \
    -I"$qt_include/QtCore/$qt_version" -I"$qt_include/QtCore/$qt_version/QtCore" \
    -I"$source_dir" -I"$build_dir" \
    "$source_dir/presentationprobe.cpp" "$source_dir/plugin.cpp" "$build_dir/moc_presentationprobe.cpp" \
    "$build_dir/presentation-time-protocol.o" \
    "${qt_libs[@]}" \
    -o "$module_dir/libnocturnepresentation.so"
cp -- "$source_dir/qmldir" "$module_dir/qmldir"

printf 'Built Nocturne.Presentation for Qt %s at %s\n' "$qt_version" "$module_dir"
