#!/usr/bin/env bash
set -euo pipefail

log(){ echo "[build_issm] $*"; }
die(){ echo "[build_issm][ERROR] $*" >&2; exit 1; }

# Activate Spack environment
source /opt/spack-src/share/spack/setup-env.sh
spack env activate /opt/spack-environment

# Define the paths for dependencies sourced from ISSM
export ISSM_DIR="/opt/ISSM"
PETSC_DIR="${ISSM_DIR}/externalpackages/petsc/src"  # ISSM's PETSC directory
PETSC_PREFIX="${ISSM_DIR}/externalpackages/petsc/install"  # PETSC install directory after building
METIS_DIR="${PETSC_PREFIX}"
PARMETIS_DIR="${PETSC_PREFIX}"
BLAS_DIR="${PETSC_PREFIX}"
LAPACK_DIR="${PETSC_PREFIX}"
SCALAPACK_DIR="${PETSC_PREFIX}"
MUMPS_DIR="${PETSC_PREFIX}"

export ISSM_PREFIX="${ISSM_DIR}"
# export PETSC_DIR="${PETSC_DIR}"
export ISSM_REPO="${ISSM_REPO:-https://github.com/ISSMteam/ISSM.git}"
export ISSM_BRANCH="${ISSM_BRANCH:-main}"
export ISSM_NUMTHREADS="${ISSM_NUMTHREADS:-2}"
export MAKE_JOBS="${MAKE_JOBS:-$(nproc)}"

MATLABROOT="${MATLABROOT:-/opt/matlab/R2024b}"
[[ -d "${MATLABROOT}" ]] || die "MATLABROOT not found: ${MATLABROOT}"

# Get MPICH location from Spack
MPI_DIR="$(spack location -i mpich@4.2.3)"

# Set necessary environment variables
export PATH="${MPI_DIR}/bin:${PATH}"
export LD_LIBRARY_PATH="${MPI_DIR}/lib:${PETSC_DIR}/lib:${METIS_DIR}/lib:${PARMETIS_DIR}/lib:${BLAS_DIR}/lib:${LAPACK_DIR}/lib:${SCALAPACK_DIR}/lib:${MUMPS_DIR}/lib:${LD_LIBRARY_PATH:-}"
export CC="${MPI_DIR}/bin/mpicc"
export CXX="${MPI_DIR}/bin/mpicxx"
export FC="${MPI_DIR}/bin/mpifort"
export MPICC="${MPI_DIR}/bin/mpicc"
export MPICXX="${MPI_DIR}/bin/mpicxx"
export MPIFC="${MPI_DIR}/bin/mpifort"
export HDF5_MPI=ON

GFORTRAN_LIBFILE="$(gfortran -print-file-name=libgfortran.so)"
GFORTRAN_LIBDIR="$(dirname "${GFORTRAN_LIBFILE}")"
FORTRAN_LIBFLAGS="-L${GFORTRAN_LIBDIR} -lgfortran"

# Clone or update ISSM repository
if [[ ! -d "${ISSM_PREFIX}/.git" ]]; then
  log "Cloning ISSM repository..."
  git clone --branch "${ISSM_BRANCH}" --depth 1 "${ISSM_REPO}" "${ISSM_PREFIX}"
else
  log "ISSM repository already present, updating..."
  git -C "${ISSM_PREFIX}" fetch --depth 1 origin "${ISSM_BRANCH}" || true
  git -C "${ISSM_PREFIX}" checkout "${ISSM_BRANCH}" || true
  git -C "${ISSM_PREFIX}" pull || true
fi

cd "${ISSM_PREFIX}"

log "Installing external dependencies..."

# Install Autotools, Triangle, and M1QN3
cd externalpackages/autotools
./install-linux.sh
export PATH="${ISSM_PREFIX}/externalpackages/autotools/install/bin:${PATH}"

cd "${ISSM_PREFIX}/externalpackages/triangle"
./install-linux.sh

cd "${ISSM_PREFIX}/externalpackages/m1qn3"
./install-linux.sh

TRIANGLE_DIR="${ISSM_PREFIX}/externalpackages/triangle/install"
M1QN3_DIR="${ISSM_PREFIX}/externalpackages/m1qn3/install"

log "Installing PETSc for ISSM..."

# Ensure PETSc is downloaded and installed
cd ${ISSM_DIR}/externalpackages/petsc
VER="3.22.3"

# Environment
if [ -z ${LDFLAGS+x} ]; then
	LDFLAGS=""
fi

# Download PETSc source code if not already downloaded
${ISSM_DIR}/scripts/DownloadExternalPackage.sh "https://web.cels.anl.gov/projects/petsc/download/release-snapshots/petsc-${VER}.tar.gz" "petsc-${VER}.tar.gz"

# Unpack source
tar -zxvf petsc-${VER}.tar.gz

# Cleanup
rm -rf ${PETSC_PREFIX} ${PETSC_DIR}
mkdir -p ${PETSC_DIR}

mv petsc-${VER}/* ${PETSC_DIR}
rm -rf petsc-${VER}

# Configure PETSc with Spack-managed MPICH
cd ${PETSC_DIR}
./configure \
  --prefix="${PETSC_PREFIX}" \
  --PETSC_DIR="${PETSC_DIR}" \
  --with-debugging=0 \
  --with-valgrind=0 \
  --with-x=0 \
  --with-ssl=0 \
  --with-pic=1 \
  --with-mpi-dir="${MPI_DIR}" \
  --download-fblaslapack=1 \
  --download-metis=1 \
  --download-mumps=1 \
  --download-parmetis=1 \
  --download-scalapack=1 \
  --download-zlib=1

make -j"${MAKE_JOBS}" 
make install 

# Source ISSM environment after each package installation
if [ -f /opt/ISSM/etc/environment.sh ]; then
    set +u
    . /opt/ISSM/etc/environment.sh
    set -u
fi

cd "${ISSM_PREFIX}"
autoreconf -ivf

log "Configuring ISSM with dependencies from ISSM and Spack..."
export PETSC_DIR="${PETSC_DIR}"  # Point to the installed PETSc from ISSM
# Configure ISSM with PETSC and other dependencies from ISSM directory
./configure \
  --prefix="${ISSM_PREFIX}" \
  --with-matlab-dir="${MATLABROOT}" \
  --with-fortran-lib="${FORTRAN_LIBFLAGS}" \
  --with-mpi-include="${MPI_DIR}/include" \
  --with-mpi-libflags="-L${MPI_DIR}/lib -lmpi -lmpicxx -lmpifort" \
  --with-metis-dir="${METIS_DIR}" \
  --with-parmetis-dir="${PARMETIS_DIR}" \
  --with-blas-lapack-dir="${BLAS_DIR}" \
  --with-scalapack-dir="${SCALAPACK_DIR}" \
  --with-mumps-dir="${MUMPS_DIR}" \
  --with-petsc-dir="${PETSC_PREFIX}" \
  --with-triangle-dir="${TRIANGLE_DIR}" \
  --with-m1qn3-dir="${M1QN3_DIR}" \
  --with-numthreads="${ISSM_NUMTHREADS}"

log "Building ISSM..."
make -j"${MAKE_JOBS}"

log "Installing ISSM..."
make install

log "Checking install..."
test -f "${ISSM_PREFIX}/etc/environment.sh" || die "ISSM environment.sh missing after install"

log "Done. ISSM installed in ${ISSM_PREFIX}"