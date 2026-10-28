#!/usr/bin/env bash
# Beta 4.1 (updates plan, U1): a Shorebird release or patch of FITOS, built in
# WSL (Windows Smart App Control blocks the Shorebird CLI). Called by
# tool/hosted.ps1 -Shorebird / tool/patch.ps1, never by hand.
#
#   shorebird.sh release <sha> <version> <build> <target-platform>
#   shorebird.sh patch   <sha> <version> <build>
#
# It builds the committed <sha>, never the working tree, in a clone on WSL's
# own disk (~/fitos-build), so the Windows checkout and its build/ are left
# alone and a release can be rebuilt exactly. Passed in the environment (WSLENV):
#   FITOS_DEFINES         the --dart-define arguments, one per line
#   FITOS_REPO            the Windows checkout (a WSL path)
#   FITOS_DEBUG_KEYSTORE  Windows' debug keystore, which signs every hosted
#                         APK: an update must carry the same signature
#   FITOS_OUT             where the release APK goes (a WSL path)
set -euo pipefail

mode=$1 sha=$2 version=$3 build=$4 platform=${5:-android-arm64}
work=$HOME/fitos-build
sb=$HOME/.shorebird/bin/shorebird
export ANDROID_HOME=$HOME/Android
export ANDROID_SDK_ROOT=$ANDROID_HOME
export JAVA_HOME=${JAVA_HOME:-/usr/lib/jvm/java-21-openjdk-amd64}
export PATH=$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH

[[ $sha =~ ^[0-9a-f]{40}$ ]] || { echo "not a commit: $sha" >&2; exit 2; }
[[ -x $JAVA_HOME/bin/java ]] || { echo "no Java 21 in WSL ($JAVA_HOME)" >&2; exit 2; }
[[ -d $ANDROID_HOME/platforms ]] || { echo "no Android SDK in WSL ($ANDROID_HOME)" >&2; exit 2; }

# The same signing key as every FITOS APK so far.
mkdir -p "$HOME/.android"
if ! cmp -s "$FITOS_DEBUG_KEYSTORE" "$HOME/.android/debug.keystore"; then
  cp "$FITOS_DEBUG_KEYSTORE" "$HOME/.android/debug.keystore"
  chmod 600 "$HOME/.android/debug.keystore"
fi

# The Windows checkout belongs to another user as WSL sees it.
src=(git -c "safe.directory=$FITOS_REPO")
if [[ ! -d $work/.git ]]; then "${src[@]}" clone --quiet --no-checkout "$FITOS_REPO" "$work"; fi
"${src[@]}" -C "$work" fetch --quiet --force "$FITOS_REPO"   '+refs/heads/*:refs/remotes/win/*' '+refs/tags/*:refs/tags/*'
git -C "$work" checkout --quiet --force --detach "$sha"
# Untracked files go; ignored build caches stay (a faster second build).
git -C "$work" clean -fdq

cd "$work/apps/mobile"
# CI's Flutter pin: the release and its patches must use the same Flutter.
flutter_version=$(grep -oP 'flutter-version:\s*\K[\w.-]+' "$work/.github/workflows/ci-mobile.yml")
mapfile -t defines <<<"$FITOS_DEFINES"
echo "shorebird $mode $version+$build at ${sha:0:7}, Flutter $flutter_version"

case $mode in
  release)
    "$sb" release android --artifact apk --target-platform "$platform" \
      --flutter-version "$flutter_version" \
      --build-name "$version" --build-number "$build" "${defines[@]}"
    cp build/app/outputs/flutter-apk/app-release.apk "$FITOS_OUT"
    ;;
  patch)
    # Shorebird itself refuses a patch with native or asset changes.
    "$sb" patch android --release-version "$version+$build" \
      --build-name "$version" --build-number "$build" "${defines[@]}"
    ;;
  *) echo "release or patch, not $mode" >&2; exit 2 ;;
esac
