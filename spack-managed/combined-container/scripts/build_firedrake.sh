#!/usr/bin/env bash
set -euo pipefail

log(){ echo "[build_firedrake] $*"; }
die(){ echo "[build_firedrake][ERROR] $*" >&2; exit 1; }

# Activate Spack environment
if [[ ! -f /opt/spack-src/share/spack/setup-env.sh ]]; then
  die "Spack setup script not found at /opt/spack-src/share/spack/setup-env.sh"
fi

# shellcheck disable=SC1091
source /opt/spack-src/share/spack/setup-env.sh
spack env activate /opt/spack-environment

# Resolve prefixes
PYTHON="$(spack location -i python)/bin/python3"
MPI_DIR="$(spack location -i openmpi)"
PETSC_DIR="$(spack location -i 'petsc@3.24.0 ^openmpi@5.0.6' 2>/dev/null || spack location -i petsc)"

[[ -x "${PYTHON}" ]] || die "Python executable not found: ${PYTHON}"
[[ -d "${MPI_DIR}" ]] || die "OpenMPI prefix not found: ${MPI_DIR}"
[[ -d "${PETSC_DIR}" ]] || die "PETSc prefix not found: ${PETSC_DIR}"

# Export build/runtime environment
export PATH="${MPI_DIR}/bin:${PATH}"
export LD_LIBRARY_PATH="${MPI_DIR}/lib:${PETSC_DIR}/lib:${LD_LIBRARY_PATH:-}"
export CC="${MPI_DIR}/bin/mpicc"
export CXX="${MPI_DIR}/bin/mpicxx"
export FC="${MPI_DIR}/bin/mpifort"
export MPICC="${MPI_DIR}/bin/mpicc"
export MPICXX="${MPI_DIR}/bin/mpicxx"
export MPIFC="${MPI_DIR}/bin/mpifort"
export PETSC_DIR="${PETSC_DIR}"
export HDF5_MPI=ON
unset PETSC_ARCH || true

# Recreate venv cleanly
if [[ -d /opt/venv-firedrake ]]; then
  log "Removing existing /opt/venv-firedrake"
  rm -rf /opt/venv-firedrake
fi

log "Creating Firedrake virtual environment"
"${PYTHON}" -m venv --system-site-packages /opt/venv-firedrake

# shellcheck disable=SC1091
source /opt/venv-firedrake/bin/activate

log "Upgrading pip tooling"
python -m pip install --upgrade "pip<26" setuptools wheel

cat > /tmp/constraints.txt <<'EOF'
setuptools<81
numpy<2
petsc4py==3.24.0
EOF
export PIP_CONSTRAINT=/tmp/constraints.txt

FIREDRAKE_VERSION="${FIREDRAKE_VERSION:-2025.10.2}"

log "Installing Firedrake ${FIREDRAKE_VERSION}"
python -m pip install "firedrake[check]==${FIREDRAKE_VERSION}"

log "Running sanity checks"
python -c "import firedrake; print('firedrake import OK')"
python -c "import petsc4py; print('petsc4py import OK')"
python -c "from mpi4py import MPI; print('mpi4py OK:', MPI.Get_version())"

log "Done."