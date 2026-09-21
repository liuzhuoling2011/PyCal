#!/usr/bin/env bash
# Exercises the Flutter release publish script extracted from
# .github/workflows/flutter-release.yml.
#
# A required-platform failure must still upload the artifacts that were built,
# must pass --clobber, and must not delete a preexisting Swift DMG. The script
# then exits non-zero so the workflow stays red. Unsigned iOS is optional.
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
      printf 'mac' > "${work}/dist/PyCal-0.2.1-macos.zip"
      printf 'apk' > "${work}/dist/PyCal-0.2.1-android.apk"
      printf '%s\n' "PyCal-0.2.1.dmg" > "${work}/fake/assets.txt"
      : > "${work}/fake/exists"
      ;;
    required-no-ios)
      printf 'web' > "${work}/dist/PyCal-0.2.1-web.tar.gz"
      printf 'linux' > "${work}/dist/PyCal-0.2.1-linux-x64.tar.gz"
      printf 'win' > "${work}/dist/PyCal-0.2.1-windows-x64.zip"
      printf 'mac' > "${work}/dist/PyCal-0.2.1-macos.zip"
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
      printf 'mac' > "${work}/dist/PyCal-0.2.1-macos.zip"
      printf 'apk' > "${work}/dist/PyCal-0.2.1-android.apk"
      printf 'ios' > "${work}/dist/PyCal-0.2.1-ios-unsigned.zip"
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
      if [[ "${arg}" == *.dmg ]]; then
        echo "refusing to upload dmg: $*" >&2
        exit 1
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
      if [[ "${arg}" == *.dmg ]]; then
        echo "refusing to upload dmg on create: $*" >&2
        exit 1
      fi
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
      grep -q 'PyCal-0.2.1.dmg' "${work}/fake/notes.md" || fail "${label}: notes dropped the Swift DMG"
      grep -q 'does not replace or delete' "${work}/fake/notes.md" || fail "${label}: notes no longer protect the DMG"
      grep -q 'PyCal-0.2.1-windows-x64.zip' "${work}/fake/notes.md" || fail "${label}: notes omit the missing windows asset"
      grep -q 'job result: failure' "${work}/fake/notes.md" || fail "${label}: notes omit the windows job result"
      grep -q 'Failing this job so the workflow stays red' "${stderr}" || fail "${label}: job did not fail closed"
      ;;
    required-no-ios)
      grep -q -- '--clobber' "${work}/fake/calls.log" || fail "${label}: missing --clobber"
      grep -q 'Unsigned iOS is best-effort' "${work}/fake/notes.md" || fail "${label}: missing iOS note"
      if grep -q 'Some required builds were not produced' "${work}/fake/notes.md"; then
        fail "${label}: treated optional iOS as a required miss"
      fi
      if grep -q 'Failing this job so the workflow stays red' "${stderr}"; then
        fail "${label}: optional iOS failure failed the publish job"
      fi
      grep -q 'PyCal-0.2.1.dmg' "${work}/fake/notes.md" || fail "${label}: notes dropped the Swift DMG"
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
      if grep -q '\.dmg' "${work}/fake/calls.log"; then
        fail "${label}: create arguments included a dmg"
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
run_case required-no-ios 0 required-no-ios

run_case empty 1 empty

run_case create 0 create

echo "flutter release publish checks ok"
