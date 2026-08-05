#!/bin/bash
#
# String Catalog（PocketRT/Localizable.xcstrings）をソースコードと同期する。
#
# xcodebuild は .stringsdata を生成するだけで、カタログへの反映は行わない
# （それは Xcode.app の役割）。コマンドラインでは xcstringstool sync が代替となる。
# CI はこのスクリプトを実行し、差分が出たらカタログが古いと判断して失敗する。
#
# 使い方: app/ ディレクトリから ./tools/sync-strings.sh
set -euo pipefail

cd "$(dirname "$0")/.."

CATALOG="PocketRT/Localizable.xcstrings"

if [ ! -f "$CATALOG" ]; then
  echo "error: $CATALOG が見つかりません" >&2
  exit 1
fi

echo "==> プロジェクトを生成"
xcodegen generate

# Pick an available iPhone simulator at runtime; names differ by Xcode version.
echo "==> シミュレータを選択"
# grep がマッチ0件だと終了コード1を返し、pipefail 下ではパイプライン全体が
# 失敗扱いになって set -e がここで即座にスクリプトを止めてしまう。
# それでは直後の「見つかりません」診断に到達できないため、grep の非0終了を
# 明示的に飲み込み、判定は必ず次の [ -z "$SIM" ] に委ねる。
SIM=$(xcrun simctl list devices available \
      | { grep -oE '^ +iPhone [^(]+' || true; } \
      | sed 's/^ *//; s/ *$//' \
      | head -1)
if [ -z "$SIM" ]; then
  echo "error: 利用可能な iPhone シミュレータが見つかりません" >&2
  xcrun simctl list devices available >&2
  exit 1
fi
echo "    $SIM"

echo "==> ビルド（.stringsdata の生成）"
BUILD_LOG=$(mktemp)
trap 'rm -f "$BUILD_LOG"' EXIT
if ! xcodebuild build \
      -project PocketRT.xcodeproj \
      -scheme PocketRT \
      -destination "platform=iOS Simulator,name=$SIM" \
      CODE_SIGNING_ALLOWED=NO > "$BUILD_LOG" 2>&1; then
  echo "error: ビルドに失敗しました" >&2
  tail -40 "$BUILD_LOG" >&2
  exit 1
fi

# BUILD_DIR points at .../Build/Products; .stringsdata lives under Intermediates.noindex.
#
# Test the assignment inside `if !` rather than swallowing the status with `|| true`.
# Commands in an `if` condition are exempt from `set -e`, so this both captures the
# output and honours the exit status. With `|| true`, a run that printed BUILD_DIR
# and *then* failed would pass the emptiness check below and carry on syncing a
# possibly stale extraction set — reporting success while xcodebuild had failed.
if ! BUILD_SETTINGS=$(xcodebuild -project PocketRT.xcodeproj -scheme PocketRT -showBuildSettings 2>&1); then
  echo "error: xcodebuild -showBuildSettings に失敗しました" >&2
  printf '%s\n' "$BUILD_SETTINGS" | tail -40 >&2
  exit 1
fi
BUILD_DIR=$(printf '%s\n' "$BUILD_SETTINGS" | awk -F' = ' '/ BUILD_DIR = /{print $2; exit}')
if [ -z "$BUILD_DIR" ]; then
  echo "error: 出力に BUILD_DIR が見つかりません" >&2
  printf '%s\n' "$BUILD_SETTINGS" | tail -40 >&2
  exit 1
fi
DERIVED_ROOT="${BUILD_DIR%/Build/Products}"

# Collect only the app target's .stringsdata. The test target writes to the same
# "Localizable" table, so including it would push test-only literals
# (e.g. AlphaBetaPreset(label: "A")) into the shipped catalog and offer them
# for translation. The app target's objects live under
# .../Intermediates.noindex/PocketRT.build/<config>/PocketRT.build/Objects-normal/,
# which the path pattern below matches while excluding PocketRTTests.build.
SEARCH_ROOT="$DERIVED_ROOT/Build/Intermediates.noindex"
echo "==> .stringsdata を収集（アプリターゲットのみ）"
# Bash does not propagate a process substitution's exit status to the `while`,
# so a `find` that lists some paths and then fails would leave ARGS non-empty and
# the script would sync an incomplete set while reporting success. Write to a temp
# file under an explicit status check instead.
FOUND_LIST=$(mktemp)
trap 'rm -f "$BUILD_LOG" "$FOUND_LIST"' EXIT
if ! find "$SEARCH_ROOT" -path "*/PocketRT.build/Objects-normal/*" -name '*.stringsdata' > "$FOUND_LIST" 2>&1; then
  echo "error: .stringsdata の探索に失敗しました（探索先: ${SEARCH_ROOT}）" >&2
  tail -20 "$FOUND_LIST" >&2
  exit 1
fi
ARGS=()
while IFS= read -r f; do
  ARGS+=(--stringsdata "$f")
done < "$FOUND_LIST"

if [ ${#ARGS[@]} -eq 0 ]; then
  echo "error: アプリターゲットの .stringsdata が1件も見つかりません（探索先: $SEARCH_ROOT/**/PocketRT.build/Objects-normal/）。SWIFT_EMIT_LOC_STRINGS が YES か、ターゲット名が PocketRT のままか確認してください" >&2
  exit 1
fi
echo "    $(( ${#ARGS[@]} / 2 )) ファイル"

# xcstringstool matches the .xcstrings filename against the table name recorded
# in the .stringsdata (here: "Localizable"). A renamed copy silently drops
# every entry, so always sync the file in place.
echo "==> カタログを同期"
xcrun xcstringstool sync "$CATALOG" "${ARGS[@]}"

# コマンド置換を echo の引数に埋め込むと、set -e はその失敗を検知できず
# 件数欄が空のまま正常終了してしまう（このスクリプトが自分の成果物を
# 検証する唯一の箇所のため、ここは握りつぶさず先に変数へ落として失敗させる）。
COUNT=$(python3 -c "import json,sys; print(len(json.load(open('$CATALOG'))['strings']))") || {
  echo "error: 同期後のカタログ件数を取得できませんでした" >&2
  exit 1
}
echo "==> 完了: ${COUNT} 件"
