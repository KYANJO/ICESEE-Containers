#!/usr/bin/env bash
set -euo pipefail

log(){ echo "[build_issm] $*"; }
die(){ echo "[build_issm][ERROR] $*" >&2; exit 1; }

# Activate Spack environment
if [[ ! -f /opt/spack-src/share/spack/setup-env.sh ]]; then
  die "Spack setup script not found at /opt/spack-src/share/spack/setup-env.sh"
fi

# shellcheck disable=SC1091
source /opt/spack-src/share/spack/setup-env.sh
spack env activate /opt/spack-environment

export ISSM_PREFIX="${ISSM_PREFIX:-/opt/ISSM}"
export ISSM_DIR="${ISSM_PREFIX}"
export ISSM_REPO="${ISSM_REPO:-https://github.com/ISSMteam/ISSM.git}"
export ISSM_BRANCH="${ISSM_BRANCH:-main}"
export ISSM_NUMTHREADS="${ISSM_NUMTHREADS:-2}"
export MAKE_JOBS="${MAKE_JOBS:-$(nproc)}"

MATLABROOT="${MATLABROOT:-/opt/matlab/R2024b}"
[[ -d "${MATLABROOT}" ]] || die "MATLABROOT not found: ${MATLABROOT}"

MPI_DIR="$(spack location -i mpich)"
PETSC_DIR="$(spack location -i 'petsc@3.22.3 ^mpich@4.2.3' 2>/dev/null || spack location -i petsc)"

[[ -d "${MPI_DIR}" ]] || die "MPICH prefix not found: ${MPI_DIR}"
[[ -d "${PETSC_DIR}" ]] || die "PETSc prefix not found: ${PETSC_DIR}"

export PATH="${MPI_DIR}/bin:${PATH}"
export LD_LIBRARY_PATH="${MPI_DIR}/lib:${PETSC_DIR}/lib:${LD_LIBRARY_PATH:-}"
export CC="${MPI_DIR}/bin/mpicc"
export CXX="${MPI_DIR}/bin/mpicxx"
export FC="${MPI_DIR}/bin/mpifort"
export MPICC="${MPI_DIR}/bin/mpicc"
export MPICXX="${MPI_DIR}/bin/mpicxx"
export MPIFC="${MPI_DIR}/bin/mpifort"
export HDF5_MPI=ON

GFORTRAN_LIBDIR="$(dirname "$(gfortran -print-file-name=libgfortran.so)")"
FORTRAN_LIBFLAGS="-L${GFORTRAN_LIBDIR} -lgfortran"

mkdir -p /opt

if [[ ! -d "${ISSM_PREFIX}/.git" ]]; then
  log "Cloning ISSM from ${ISSM_REPO} (${ISSM_BRANCH})"
  git clone --branch "${ISSM_BRANCH}" --depth 1 "${ISSM_REPO}" "${ISSM_PREFIX}"
else
  log "ISSM already present; refreshing checkout"
  git -C "${ISSM_PREFIX}" fetch --depth 1 origin "${ISSM_BRANCH}" || true
  git -C "${ISSM_PREFIX}" checkout "${ISSM_BRANCH}" || true
  git -C "${ISSM_PREFIX}" pull || true
fi

cd "${ISSM_PREFIX}"

log "Installing autotools external package"
cd "${ISSM_PREFIX}/externalpackages/autotools"
./install-linux.sh

if [[ -x "${ISSM_PREFIX}/externalpackages/autotools/install/bin/autoreconf" ]]; then
  export PATH="${ISSM_PREFIX}/externalpackages/autotools/install/bin:${PATH}"
fi

log "Installing triangle"
cd "${ISSM_PREFIX}/externalpackages/triangle"
./install-linux.sh

log "Installing m1qn3"
cd "${ISSM_PREFIX}/externalpackages/m1qn3"
./install-linux.sh

TRIANGLE_DIR="${ISSM_PREFIX}/externalpackages/triangle/install"
M1QN3_DIR="${ISSM_PREFIX}/externalpackages/m1qn3/install"

[[ -d "${TRIANGLE_DIR}" ]] || die "Triangle install directory missing: ${TRIANGLE_DIR}"
[[ -d "${M1QN3_DIR}" ]] || die "m1qn3 install directory missing: ${M1QN3_DIR}"

cd "${ISSM_PREFIX}"

log "Running autoreconf"
autoreconf -ivf

log "Configuring ISSM"
./configure \
  --prefix="${ISSM_PREFIX}" \
  --with-matlab-dir="${MATLABROOT}" \
  --with-fortran-lib="${FORTRAN_LIBFLAGS}" \
  --with-mpi-include="${MPI_DIR}/include" \
  --with-mpi-libflags="-L${MPI_DIR}/lib -lmpi -lmpicxx -lmpifort" \
  --with-triangle-dir="${TRIANGLE_DIR}" \
  --with-petsc-dir="${PETSC_DIR}" \
  --with-metis-dir="${PETSC_DIR}" \
  --with-parmetis-dir="${PETSC_DIR}" \
  --with-blas-lapack-dir="${PETSC_DIR}" \
  --with-scalapack-dir="${PETSC_DIR}" \
  --with-mumps-dir="${PETSC_DIR}" \
  --with-m1qn3-dir="${M1QN3_DIR}" \
  --with-numthreads="${ISSM_NUMTHREADS}"

log "Building ISSM"
make -j"${MAKE_JOBS}"

log "Installing ISSM"
make install

log "Checking install"
[[ -f "${ISSM_PREFIX}/etc/environment.sh" ]] || die "ISSM environment.sh missing after install"
[[ -d "${ISSM_PREFIX}/bin" ]] || die "ISSM bin directory missing after install"

log "Done. ISSM installed in ${ISSM_PREFIX}"