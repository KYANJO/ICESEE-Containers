#!/usr/bin/env bash
set -euo pipefail

log(){ echo "[build_icesee] $*"; }
die(){ echo "[build_icesee][ERROR] $*" >&2; exit 1; }

# Load the Firedrake/OpenMPI/PETSc environment if present
if [[ -f /opt/runtime-env/firedrake-env.sh ]]; then
  # Lean-style environment
  # shellcheck disable=SC1091
  source /opt/runtime-env/firedrake-env.sh
  unset PETSC_ARCH || true
elif [[ -f /opt/spack-src/share/spack/setup-env.sh ]]; then
  # Fallback for builder images that still use Spack activation directly
  # shellcheck disable=SC1091
  source /opt/spack-src/share/spack/setup-env.sh
  spack env activate /opt/spack-environment
  # PETSC_HASH="$(spack find -Lv 'petsc@3.24.0' | awk '/petsc@3.24.0/ {print $1; exit}')"
  # MPI_HASH="$(spack spec -Il /${PETSC_HASH} | awk '/openmpi@/ {gsub("^/","",$1); print $1; exit}')"
  export MPI_DIR="$(spack location -i 'openmpi@5.0.10')"
  export HDF5_DIR="$(spack location -i hdf5@1.14.5)"
  export PATH="/opt/venv-icesee/bin:${MPI_DIR}/bin:\${PATH}"
  export LD_LIBRARY_PATH="${MPI_DIR}/lib:${HDF5_DIR}/lib:\${LD_LIBRARY_PATH:-}"
  export CC="${MPI_DIR}/bin/mpicc"
  export CXX="${MPI_DIR}/bin/mpicxx"
  export FC="${MPI_DIR}/bin/mpifort"
  export MPICC="${MPI_DIR}/bin/mpicc"
  export MPICXX="${MPI_DIR}/bin/mpicxx"
  export MPIFC="${MPI_DIR}/bin/mpifort"
  export HDF5_MPI=ON
  unset PETSC_ARCH || true
else
  die "Could not find a runtime environment to activate."
fi

# Activate the Python environment used by Firedrake/Icepack
if [[ ! -f /opt/venv-firedrake/bin/activate ]]; then
  die "Expected virtual environment not found: /opt/venv-firedrake"
fi
# shellcheck disable=SC1091
source /opt/venv-firedrake/bin/activate

# ICESEE imports as 'ICESEE', so /opt must be on PYTHONPATH
export PYTHONPATH="/opt:${PYTHONPATH:-}"

mkdir -p /opt/requirements

# Clone or refresh ICESEE source
if [[ ! -d /opt/ICESEE/.git ]]; then
  log "Cloning ICESEE..."
  git clone --depth=1 https://github.com/ICESEE-project/ICESEE.git /opt/ICESEE
else
  log "ICESEE already present; refreshing..."
  git -C /opt/ICESEE fetch --depth=1 origin main || true
  git -C /opt/ICESEE checkout main || true
  git -C /opt/ICESEE pull || true
fi

[[ -f /opt/ICESEE/pyproject.toml ]] || die "Missing /opt/ICESEE/pyproject.toml"
[[ -f /opt/build-scripts/gen_pip_reqs.py ]] || die "Missing /opt/build-scripts/gen_pip_reqs.py"

log "Generating pip requirements from pyproject.toml..."
python /opt/build-scripts/gen_pip_reqs.py \
  --pyproject /opt/ICESEE/pyproject.toml \
  --out /opt/requirements/pip.auto.txt \
  --extras mpi,viz

log "Installing ICESEE Python dependencies..."
python -m pip install --no-cache-dir -r /opt/requirements/pip.auto.txt

log "Installing ICESEE in editable mode..."
python -m pip install --no-cache-dir -e /opt/ICESEE

log "Sanity check..."
python -c "import ICESEE; print('ICESEE import OK')"

log "Done."