#!/usr/bin/env bash
set -euo pipefail

log(){ echo "[build_icepack] $*"; }
die(){ echo "[build_icepack][ERROR] $*" >&2; exit 1; }

ICEPACK_REPO="${ICEPACK_REPO:-https://github.com/icepack/icepack.git}"
ICEPACK_BRANCH="${ICEPACK_BRANCH:-main}"
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

if [[ ! -d "${ICEPACK_PREFIX}/.git" ]]; then
  log "Cloning Icepack from ${ICEPACK_REPO} (${ICEPACK_BRANCH})"
  git clone --branch "${ICEPACK_BRANCH}" --depth=1 "${ICEPACK_REPO}" "${ICEPACK_PREFIX}"
else
  log "Refreshing existing Icepack checkout"
  git -C "${ICEPACK_PREFIX}" fetch --depth=1 origin "${ICEPACK_BRANCH}" || true
  git -C "${ICEPACK_PREFIX}" checkout "${ICEPACK_BRANCH}" || true
  git -C "${ICEPACK_PREFIX}" pull || true
fi

python -m pip install --editable "${ICEPACK_PREFIX}"
python -m pip install gmsh ipykernel

python -c "import firedrake; print('firedrake import OK')"
python -c "import icepack; print('icepack import OK')"

log "Done."