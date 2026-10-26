#!/usr/bin/env bash
# Makes the Linux downloads from an exported Linux build:
#   JustSudoku-<version>-linux-x86_64.tar.gz   the game, its menu entry and icons, to unpack anywhere
#   JustSudoku-<version>-x86_64.AppImage       one file that runs on most distributions
# each with a .sha256 file next to it.
#   tools/build_linux_packages.sh <exported binary> <version> <output folder> [--no-appimage]
# The AppImage is put together by appimagetool, which this downloads (a pinned version, checked
# against its checksum) and runs: leave it out with --no-appimage to make the tar.gz alone.
# Needs squashfs-tools for the AppImage.
set -euo pipefail

binary=${1:?usage: build_linux_packages.sh <exported binary> <version> <output folder> [--no-appimage]}
version=${2:?version missing}
out=${3:?output folder missing}
with_appimage=1
[ "${4:-}" = "--no-appimage" ] && with_appimage=0

repo=$(cd "$(dirname "$0")/.." && pwd)
pkg="$repo/packaging/linux"
app_id=io.github.r0madeus.JustSudoku
appimagetool_version=1.9.1
appimagetool_sha256=ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0

mkdir -p "$out"
out=$(cd "$out" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# --- tar.gz -------------------------------------------------------------------------------
name="JustSudoku-$version-linux-x86_64"
mkdir -p "$work/$name"
install -m755 "$binary" "$work/$name/JustSudoku"
install -m644 "$repo/LICENSE" "$work/$name/LICENSE"
install -m644 "$pkg/$app_id.desktop" "$pkg/$app_id.metainfo.xml" "$pkg/$app_id.svg" "$pkg/$app_id.png" "$work/$name/"
cat > "$work/$name/README.txt" <<TXT
Just Sudoku $version for Linux (64-bit)

Run ./JustSudoku. Nothing to install; your games are kept in
~/.local/share/godot/app_userdata/Just Sudoku.

To get it into the applications menu, copy $app_id.desktop to
~/.local/share/applications/, the icon ($app_id.svg) to
~/.local/share/icons/hicolor/scalable/apps/, and put JustSudoku somewhere on your PATH
(or write its full path after Exec= in the .desktop file).
TXT
tar -C "$work" --owner=0 --group=0 -czf "$out/$name.tar.gz" "$name"
files=("$name.tar.gz")

# --- AppImage -------------------------------------------------------------------------------
if [ "$with_appimage" = 1 ]; then
	appdir="$work/AppDir"
	mkdir -p "$appdir/usr/bin" "$appdir/usr/share/applications" "$appdir/usr/share/metainfo" "$appdir/usr/share/icons/hicolor/scalable/apps"
	install -m755 "$binary" "$appdir/usr/bin/JustSudoku"
	install -m644 "$pkg/$app_id.desktop" "$appdir/usr/share/applications/"
	install -m644 "$pkg/$app_id.desktop" "$appdir/"
	install -m644 "$pkg/$app_id.metainfo.xml" "$appdir/usr/share/metainfo/"
	install -m644 "$pkg/$app_id.svg" "$appdir/usr/share/icons/hicolor/scalable/apps/"
	install -m644 "$pkg/$app_id.png" "$appdir/$app_id.png"
	ln -s "$app_id.png" "$appdir/.DirIcon"
	cat > "$appdir/AppRun" <<'RUN'
#!/bin/sh
here=$(dirname "$(readlink -f "$0")")
exec "$here/usr/bin/JustSudoku" "$@"
RUN
	chmod 755 "$appdir/AppRun"

	tool="$work/appimagetool"
	curl -fsSL -o "$tool" "https://github.com/AppImage/appimagetool/releases/download/$appimagetool_version/appimagetool-x86_64.AppImage"
	echo "$appimagetool_sha256  $tool" | sha256sum -c - >/dev/null
	chmod +x "$tool"
	# --appimage-extract-and-run: no FUSE needed (CI runners and containers have none)
	ARCH=x86_64 "$tool" --appimage-extract-and-run --no-appstream "$appdir" "$out/JustSudoku-$version-x86_64.AppImage" >/dev/null
	files+=("JustSudoku-$version-x86_64.AppImage")
fi

(cd "$out" && for f in "${files[@]}"; do sha256sum "$f" > "$f.sha256"; done)
ls -la "$out"
