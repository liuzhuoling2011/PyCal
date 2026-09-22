#!/usr/bin/env bash
# Exercises the Flutter release publish script extracted from
# .github/workflows/flutter-release.yml.
#
# A required-platform failure must still upload the artifacts that were built,
# must pass --clobber, and must not delete preexisting assets. The script then
# exits non-zero so the workflow stays red. macOS is PyCal-<version>.dmg.
# Unsigned iOS is not built.
set -euo pipefail

if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  echo "This test needs bash 4 or newer (the publish script uses associative arrays)." >&2
  exit 1
fi

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
workflow="${repo_root}/.github/workflows/flutter-release.yml"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

if [[ ! -f "${workflow}" ]]; then
  fail "missing ${workflow}"
fi

if grep -n 'reg add' "${workflow}"; then
  fail "flutter-release.yml must not call reg.exe; Git Bash rewrites /t /f /v /d"
fi

if grep -n "needs.windows.result == 'success'" "${workflow}"; then
  fail "publish must not require needs.windows.result == success"
fi

python3 - "${workflow}" <<'PY'
import sys
from pathlib import Path
text = Path(sys.argv[1]).read_text(encoding="utf-8")
start = text.find("      - name: Enable Windows symlink support\n")
if start < 0:
    sys.exit("Enable Windows symlink support step not found")
end = text.find("\n      - name: ", start + 10)
step = text[start:end]
if "shell: pwsh" not in step:
    sys.exit("Windows symlink step must set shell: pwsh")
if "reg.exe" in step.split("run: |", 1)[-1] and "reg add" in step:
    sys.exit("Windows symlink run block still calls reg add")
if 'if: "${{ always() && !cancelled() && needs.quality.result == \'success\' }}"' not in text:
    sys.exit("publish if-condition is not the partial-upload gate")
if "gh release upload" not in text or "--clobber" not in text:
    sys.exit("publish must keep gh release upload --clobber")
if 'GH_REPO: ${{ github.repository }}' not in text:
    sys.exit("publish must set GH_REPO so gh works without a checkout")
if '-R "${GITHUB_REPOSITORY}"' not in text:
    sys.exit("publish must pass -R ${GITHUB_REPOSITORY} to gh release commands")
if "flutter build ios" in text or "--no-codesign" in text:
    sys.exit("unsigned iOS build must be removed")
if "PyCal-${PYCAL_VERSION}-macos.zip" in text:
    sys.exit("macos zip must not be a release asset")
if "release-dmg.yml" in text:
    sys.exit("legacy Swift DMG workflow must not be referenced")
legacy = Path(sys.argv[1]).with_name("release-dmg.yml")
if legacy.exists():
    sys.exit(f"legacy workflow still present: {legacy}")
for needle in (
    "DEVELOPER_ID_P12_BASE64",
    "DEVELOPER_ID_P12_PASSWORD",
    "APPLE_TEAM_ID",
    "APP_STORE_CONNECT_KEY_ID",
    "APP_STORE_CONNECT_ISSUER_ID",
    "APP_STORE_CONNECT_API_KEY_P8",
    "Scripts/ci-import-signing.sh",
    "Scripts/make-macos-dmg.sh",
    "pycal_release_mode",
    "runs-on: macos-latest",
    "Refusing to upload an unsigned zip or DMG",
    'path: dist/PyCal-${{ needs.quality.outputs.version }}.dmg',
):
    if needle not in text:
        sys.exit(f"flutter-release.yml missing {needle}")
if "needs: [quality, web, linux, windows, macos, android, ios]" in text:
    sys.exit("publish still depends on the iOS job")
print("static workflow checks ok")
PY

tmp_root="$(mktemp -d)"
trap 'rm -rf "${tmp_root}"' EXIT

python3 - "${workflow}" "${tmp_root}/blocks" <<'PY'
import sys
from pathlib import Path
text = Path(sys.argv[1]).read_text(encoding="utf-8")
out = Path(sys.argv[2])
out.mkdir(parents=True)
lines = text.splitlines()
blocks = []
i = 0
while i < len(lines):
    if lines[i].rstrip().endswith("run: |"):
        i += 1
        while i < len(lines) and lines[i].strip() == "":
            i += 1
        if i >= len(lines):
            break
        indent = len(lines[i]) - len(lines[i].lstrip(" "))
        body = [lines[i][indent:]]
        i += 1
        while i < len(lines):
            line = lines[i]
            if line.strip() == "":
                body.append("")
                i += 1
                continue
            if line.startswith(" " * indent):
                body.append(line[indent:])
                i += 1
                continue
            break
        blocks.append("\n".join(body) + "\n")
    else:
        i += 1
bash_blocks = [b for b in blocks if b.lstrip().startswith("set -euo pipefail")]
if not bash_blocks:
    sys.exit("no bash run blocks found")
publish = [b for b in bash_blocks if "gh release upload" in b]
if len(publish) != 1:
    sys.exit(f"expected one publish script, found {len(publish)}")
for n, block in enumerate(bash_blocks):
    (out / f"bash-{n}.sh").write_text(block, encoding="utf-8")
(out / "publish.sh").write_text(publish[0], encoding="utf-8")
print(f"extracted {len(bash_blocks)} bash blocks")
PY

shopt -s nullglob
for block in "${tmp_root}/blocks"/bash-*.sh; do
  bash -n "${block}" || fail "bash -n ${block}"
done
echo "bash -n ok"

publish_script="${tmp_root}/blocks/publish.sh"

run_case() {
  local label="$1"
  local expect_exit="$2"
  local mode="$3"
  local work="${tmp_root}/case-${label}"
  rm -rf "${work}"
  mkdir -p "${work}/dist" "${work}/bin" "${work}/runner-temp" "${work}/fake"
  : > "${work}/fake/assets.txt"
  : > "${work}/fake/calls.log"

  case "${mode}" in
    partial)
      printf 'web' > "${work}/dist/PyCal-0.2.1-web.tar.gz"
      printf 'linux' > "${work}/dist/PyCal-0.2.1-linux-x64.tar.gz"
      printf 'dmg' > "${work}/dist/PyCal-0.2.1.dmg"
      printf 'apk' > "${work}/dist/PyCal-0.2.1-android.apk"
      printf '%s\n' "PyCal-0.2.1.dmg" "PyCal-0.2.1-macos.zip" "PyCal-0.2.1-ios-unsigned.zip" > "${work}/fake/assets.txt"
      : > "${work}/fake/exists"
      ;;
    macos-missing)
      printf 'web' > "${work}/dist/PyCal-0.2.1-web.tar.gz"
      printf 'linux' > "${work}/dist/PyCal-0.2.1-linux-x64.tar.gz"
      printf 'win' > "${work}/dist/PyCal-0.2.1-windows-x64.zip"
      printf 'apk' > "${work}/dist/PyCal-0.2.1-android.apk"
      printf '%s\n' "PyCal-0.2.1.dmg" "PyCal-0.2.1-macos.zip" > "${work}/fake/assets.txt"
      : > "${work}/fake/exists"
      ;;
    complete)
      printf 'web' > "${work}/dist/PyCal-0.2.1-web.tar.gz"
      printf 'linux' > "${work}/dist/PyCal-0.2.1-linux-x64.tar.gz"
      printf 'win' > "${work}/dist/PyCal-0.2.1-windows-x64.zip"
      printf 'dmg' > "${work}/dist/PyCal-0.2.1.dmg"
      printf 'apk' > "${work}/dist/PyCal-0.2.1-android.apk"
      printf '%s\n' "PyCal-0.2.1.dmg" > "${work}/fake/assets.txt"
      : > "${work}/fake/exists"
      ;;
    empty)
      ;;
    create)
      printf 'web' > "${work}/dist/PyCal-0.2.1-web.tar.gz"
      printf 'linux' > "${work}/dist/PyCal-0.2.1-linux-x64.tar.gz"
      printf 'win' > "${work}/dist/PyCal-0.2.1-windows-x64.zip"
      printf 'dmg' > "${work}/dist/PyCal-0.2.1.dmg"
      printf 'apk' > "${work}/dist/PyCal-0.2.1-android.apk"
      ;;
    *)
      fail "unknown mode ${mode}"
      ;;
  esac

  cat > "${work}/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
log="${FAKE_GH_DIR}/calls.log"
assets="${FAKE_GH_DIR}/assets.txt"
printf '%s\n' "$*" >> "${log}"
cmd="${1:-}"
sub="${2:-}"
if [[ "${cmd}" != "release" ]]; then
  echo "unexpected gh command: $*" >&2
  exit 1
fi
copy_notes() {
  local notes_next=0
  local arg
  for arg in "$@"; do
    if [[ "${notes_next}" -eq 1 ]]; then
      cp "${arg}" "${FAKE_GH_DIR}/notes.md"
      notes_next=0
      continue
    fi
    if [[ "${arg}" == "--notes-file" ]]; then
      notes_next=1
    fi
  done
}
case "${sub}" in
  view)
    if [[ ! -f "${FAKE_GH_DIR}/exists" ]]; then
      echo "release not found" >&2
      exit 1
    fi
    if [[ "$*" == *"--json assets"* ]]; then
      sort "${assets}"
    fi
    ;;
  upload)
    local_clobber=0
    arg=""
    for arg in "$@"; do
      if [[ "${arg}" == "--clobber" ]]; then
        local_clobber=1
      fi
      if [[ -f "${arg}" ]]; then
        basename "${arg}" >> "${assets}"
      fi
    done
    if [[ "${local_clobber}" -ne 1 ]]; then
      echo "upload missing --clobber: $*" >&2
      exit 1
    fi
    ;;
  edit)
    copy_notes "$@"
    ;;
  create)
    arg=""
    for arg in "$@"; do
      if [[ -f "${arg}" ]]; then
        basename "${arg}" >> "${assets}"
      fi
    done
    copy_notes "$@"
    : > "${FAKE_GH_DIR}/exists"
    ;;
  *)
    echo "unexpected gh release subcommand: $*" >&2
    exit 1
    ;;
esac
EOF
  chmod +x "${work}/bin/gh"

  local stdout="${work}/stdout" stderr="${work}/stderr" summary="${work}/summary.md"
  local code=0
  (
    cd "${work}"
    export FAKE_GH_DIR="${work}/fake"
    export PATH="${work}/bin:${PATH}"
    export GH_TOKEN="test-token"
    export RUNNER_TEMP="${work}/runner-temp"
    export GITHUB_STEP_SUMMARY="${summary}"
    export GITHUB_SERVER_URL="https://github.com"
    export GITHUB_REPOSITORY="liuzhuoling2011/PyCal"
    export GITHUB_RUN_ID="1"
    export PYCAL_VERSION="0.2.1"
    export PYCAL_BUILD_NAME="0.2.1"
    export PYCAL_TAG="v0.2.1"
    export PYCAL_RESULT_WEB="${RESULT_WEB}"
    export PYCAL_RESULT_LINUX="${RESULT_LINUX}"
    export PYCAL_RESULT_WINDOWS="${RESULT_WINDOWS}"
    export PYCAL_RESULT_MACOS="${RESULT_MACOS}"
    export PYCAL_RESULT_ANDROID="${RESULT_ANDROID}"
    bash "${publish_script}"
  ) >"${stdout}" 2>"${stderr}" || code=$?

  if [[ "${code}" -ne "${expect_exit}" ]]; then
    echo "---- stdout (${label}) ----" >&2
    cat "${stdout}" >&2 || true
    echo "---- stderr (${label}) ----" >&2
    cat "${stderr}" >&2 || true
    fail "${label}: exit ${code}, expected ${expect_exit}"
  fi

  case "${mode}" in
    partial)
      grep -q 'release upload' "${work}/fake/calls.log" || fail "${label}: did not upload"
      grep -q -- '--clobber' "${work}/fake/calls.log" || fail "${label}: upload was not --clobber"
      if grep -q 'release create' "${work}/fake/calls.log"; then
        fail "${label}: created a new release instead of uploading onto the existing one"
      fi
      if grep -q 'delete-asset' "${work}/fake/calls.log"; then
        fail "${label}: deleted a release asset"
      fi
      grep -q 'PyCal-0.2.1-web.tar.gz' "${work}/fake/calls.log" || fail "${label}: web asset was not uploaded"
      if grep 'release upload' "${work}/fake/calls.log" | grep -q 'windows-x64'; then
        fail "${label}: uploaded a windows zip that was not built"
      fi
      [[ -f "${work}/fake/notes.md" ]] || fail "${label}: release notes were not written"
      grep -q 'PyCal-0.2.1.dmg' "${work}/fake/notes.md" || fail "${label}: notes dropped the DMG"
      grep -q 'Developer ID signed, notarized, and stapled' "${work}/fake/notes.md" || fail "${label}: notes do not describe the Flutter DMG"
      grep -q 'This workflow no longer builds it' "${work}/fake/notes.md" || fail "${label}: notes dropped historical zip/iOS assets"
      grep -q 'does not delete other assets' "${work}/fake/notes.md" || fail "${label}: notes no longer say preexisting assets are kept"
      grep -q 'PyCal-0.2.1-windows-x64.zip' "${work}/fake/notes.md" || fail "${label}: notes omit the missing windows asset"
      grep -q 'job result: failure' "${work}/fake/notes.md" || fail "${label}: notes omit the windows job result"
      if grep -q 'ios-unsigned.zip' "${work}/fake/calls.log"; then
        fail "${label}: uploaded an unsigned iOS zip"
      fi
      grep -q 'Failing this job so the workflow stays red' "${stderr}" || fail "${label}: job did not fail closed"
      ;;
    macos-missing)
      grep -q -- '--clobber' "${work}/fake/calls.log" || fail "${label}: missing --clobber"
      if grep 'release upload' "${work}/fake/calls.log" | grep -q '\.dmg'; then
        fail "${label}: uploaded a DMG that was not built"
      fi
      grep -q 'this run did not upload a replacement' "${work}/fake/notes.md" || fail "${label}: notes claim the old DMG was replaced"
      grep -q 'PyCal-0.2.1.dmg' "${work}/fake/notes.md" || fail "${label}: notes dropped the preexisting DMG"
      grep -q 'This workflow no longer builds it' "${work}/fake/notes.md" || fail "${label}: notes dropped the historical macOS zip"
      grep -q 'job result: failure' "${work}/fake/notes.md" || fail "${label}: notes omit the macOS job result"
      grep -q 'Failing this job so the workflow stays red' "${stderr}" || fail "${label}: job did not fail closed"
      ;;
    complete)
      grep -q -- '--clobber' "${work}/fake/calls.log" || fail "${label}: missing --clobber"
      grep -q 'Developer ID signed, notarized, and stapled' "${work}/fake/notes.md" || fail "${label}: missing notarized DMG note"
      grep -q 'drag PyCal to Applications' "${work}/fake/notes.md" || fail "${label}: missing install instructions"
      if grep -q 'Some required builds were not produced' "${work}/fake/notes.md"; then
        fail "${label}: treated a successful run as a required miss"
      fi
      if grep -q 'best-effort' "${work}/fake/notes.md"; then
        fail "${label}: still describes unsigned iOS as best-effort"
      fi
      if grep -q 'Failing this job so the workflow stays red' "${stderr}"; then
        fail "${label}: complete publish failed the job"
      fi
      grep -q 'PyCal-0.2.1.dmg' "${work}/fake/assets.txt" || fail "${label}: DMG was not uploaded"
      if grep -q 'ios-unsigned' "${work}/fake/assets.txt"; then
        fail "${label}: uploaded unsigned iOS"
      fi
      ;;
    empty)
      if [[ -s "${work}/fake/calls.log" ]]; then
        fail "${label}: called gh when there was nothing to publish"
      fi
      ;;
    create)
      grep -q 'release create' "${work}/fake/calls.log" || fail "${label}: did not create the release"
      if grep -q 'delete-asset' "${work}/fake/calls.log"; then
        fail "${label}: deleted a release asset"
      fi
      grep -q 'PyCal-0.2.1.dmg' "${work}/fake/assets.txt" || fail "${label}: DMG missing after create"
      grep -q 'Developer ID signed, notarized, and stapled' "${work}/fake/notes.md" || fail "${label}: create notes omit the DMG"
      if grep -q 'ios-unsigned' "${work}/fake/assets.txt"; then
        fail "${label}: create uploaded unsigned iOS"
      fi
      grep -q 'PyCal-0.2.1-windows-x64.zip' "${work}/fake/assets.txt" || fail "${label}: windows asset missing after create"
      ;;
  esac
  echo "case ${label} ok"
}

RESULT_WEB=success
RESULT_LINUX=success
RESULT_WINDOWS=failure
RESULT_MACOS=success
RESULT_ANDROID=success
run_case partial 1 partial

RESULT_WINDOWS=success
RESULT_MACOS=failure
run_case macos-missing 1 macos-missing

RESULT_MACOS=success
run_case complete 0 complete

run_case empty 1 empty

run_case create 0 create

lib="${repo_root}/Scripts/lib-macos-release.sh"
# shellcheck source=lib-macos-release.sh
source "${lib}"

mode="$(env -i PATH="${PATH}" bash -c 'source "$1"; pycal_release_mode' _ "${lib}")" \
  || fail "empty secrets should return unsigned, not fail"
[[ "${mode}" == "unsigned" ]] || fail "expected unsigned mode, got ${mode}"

if env -i PATH="${PATH}" DEVELOPER_ID_P12_BASE64=dummy \
  bash -c 'source "$1"; pycal_release_mode' _ "${lib}"; then
  fail "partial signing secrets should fail"
fi

if env -i PATH="${PATH}" GITHUB_ACTIONS=true \
  DEVELOPER_ID_P12_BASE64=a DEVELOPER_ID_P12_PASSWORD=b APPLE_TEAM_ID=TEAMID1234 \
  bash -c 'source "$1"; pycal_release_mode' _ "${lib}"; then
  fail "signing without notarization must fail in CI"
fi

mode="$(env -i PATH="${PATH}" \
  DEVELOPER_ID_P12_BASE64=a DEVELOPER_ID_P12_PASSWORD=b APPLE_TEAM_ID=TEAMID1234 \
  APP_STORE_CONNECT_KEY_ID=KEY APP_STORE_CONNECT_ISSUER_ID=ISS APP_STORE_CONNECT_API_KEY_P8=p8 \
  bash -c 'source "$1"; pycal_release_mode' _ "${lib}")" \
  || fail "complete secrets should be notarized"
[[ "${mode}" == "notarized" ]] || fail "expected notarized mode, got ${mode}"

name="$(pycal_dmg_basename 0.2.1)" || fail "dmg basename 0.2.1"
[[ "${name}" == "PyCal-0.2.1.dmg" ]] || fail "unexpected basename ${name}"
name="$(pycal_dmg_basename 0.2.1-rc.1)" || fail "dmg basename rc"
[[ "${name}" == "PyCal-0.2.1-rc.1.dmg" ]] || fail "unexpected rc basename ${name}"
if pycal_dmg_basename 'not-a-version' >/dev/null; then
  fail "invalid DMG version was accepted"
fi

if ! grep -q 'pycal_codesign_app' "${repo_root}/Scripts/make-macos-dmg.sh"; then
  fail "make-macos-dmg.sh must sign nested code via pycal_codesign_app"
fi
if grep -nE 'codesign[^\n]*--sign[^\n]*--entitlements|codesign[^\n]*--entitlements[^\n]*--sign' "${lib}" | grep -v ':[ 	]*#'; then
  fail "Developer ID helper must not pass --entitlements when signing"
fi
if ! grep -q 'codesign -d --entitlements' "${lib}"; then
  fail "Developer ID helper should inspect entitlements after signing"
fi

echo "flutter release publish checks ok"
