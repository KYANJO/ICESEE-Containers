#!/usr/bin/env bash
set -euo pipefail

log(){ echo "[build_icepack] $*"; }
die(){ echo "[build_icepack][ERROR] $*" >&2; exit 1; }

ICEPACK_REPO="${ICEPACK_REPO:-https://github.com/icepack/icepack.git}"
ICEPACK_BRANCH="${ICEPACK_BRANCH:-master}"
ICEPACK_PREFIX="${ICEPACK_PREFIX:-/opt/icepack}"

if [[ -f /opt/runtime-env/firedrake-env.sh ]]; then
  # shellcheck disable=SC1091
  source /opt/runtime-env/firedrake-env.sh
  unset PETSC_ARCH || true
fi

[[ -f /opt/venv-firedrake/bin/activate ]] || die "Missing /opt/venv-firedrake"
# shellcheck disable=SC1091
source /opt/venv-firedrake/bin/activate

python -m pip install --upgrade pip setuptools wheel
python -m pip install patchelf

clone_default_branch() {
  log "Requested branch '${ICEPACK_BRANCH}' not found; cloning repository default branch instead"
  rm -rf "${ICEPACK_PREFIX}"
  git clone --depth=1 "${ICEPACK_REPO}" "${ICEPACK_PREFIX}"
}

if [[ ! -d "${ICEPACK_PREFIX}/.git" ]]; then
  log "Cloning Icepack from ${ICEPACK_REPO} (branch=${ICEPACK_BRANCH})"
  if git ls-remote --exit-code --heads "${ICEPACK_REPO}" "${ICEPACK_BRANCH}" >/dev/null 2>&1; then
    git clone --branch "${ICEPACK_BRANCH}" --depth=1 "${ICEPACK_REPO}" "${ICEPACK_PREFIX}"
  else
    clone_default_branch
  fi
else
  log "Refreshing existing Icepack checkout"

  if git ls-remote --exit-code --heads "${ICEPACK_REPO}" "${ICEPACK_BRANCH}" >/dev/null 2>&1; then
    git -C "${ICEPACK_PREFIX}" fetch --depth=1 origin "${ICEPACK_BRANCH}"
    git -C "${ICEPACK_PREFIX}" checkout "${ICEPACK_BRANCH}"
    git -C "${ICEPACK_PREFIX}" reset --hard "origin/${ICEPACK_BRANCH}"
  else
    log "Branch '${ICEPACK_BRANCH}' not found upstream; keeping existing checkout on repo default branch"
    git -C "${ICEPACK_PREFIX}" fetch --depth=1 origin || true
    DEFAULT_REMOTE_HEAD="$(git -C "${ICEPACK_PREFIX}" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
    if [[ -n "${DEFAULT_REMOTE_HEAD}" ]]; then
      DEFAULT_BRANCH="${DEFAULT_REMOTE_HEAD#origin/}"
      git -C "${ICEPACK_PREFIX}" checkout "${DEFAULT_BRANCH}" || true
      git -C "${ICEPACK_PREFIX}" reset --hard "origin/${DEFAULT_BRANCH}" || true
    fi
  fi
fi

python -m pip install --editable "${ICEPACK_PREFIX}"
python -m pip install gmsh ipykernel

python -c "import firedrake; print('firedrake import OK')"
python -c "import icepack; print('icepack import OK')"

log "Done."