FROM ubuntu:24.04

LABEL org.opencontainers.image.authors="Brian Kyanjo <briankyanjo@u.boisestate.edu>" \
      org.opencontainers.image.title="Spack Firedrake base" \
      org.opencontainers.image.description="Docker image with Spack-managed Python, MPI, PETSc, and Firedrake"

SHELL ["/bin/bash", "-lc"]

ENV DEBIAN_FRONTEND=noninteractive

# System packages needed for Spack and scientific builds
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    file \
    gfortran \
    git \
    gnupg \
    lsb-release \
    m4 \
    make \
    ninja-build \
    pkg-config \
    python3 \
    python3-venv \
    python3-pip \
    unzip \
    wget \
    zip \
    perl \
    tar \
    xz-utils \
    bzip2 \
    patch \
    cmake \
    flex \
    bison \
    libssl-dev \
    libffi-dev \
    libhwloc-dev \
    libnuma-dev \
    openssh-client \
    locales \
 && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Install Spack
WORKDIR /opt
RUN git clone --depth=1 https://github.com/spack/spack.git /opt/spack-src

ENV SPACK_ROOT=/opt/spack-src
ENV PATH=/opt/spack-src/bin:$PATH

# Copy custom repo and environment
WORKDIR /opt
COPY icesee-spack /opt/icesee-spack
COPY spack.yaml /opt/spack-environment/spack.yaml

# Concretize and install Spack environment
WORKDIR /opt/spack-environment
RUN . /opt/spack-src/share/spack/setup-env.sh && \
    spack env activate . && \
    spack repo list && \
    spack repo add /opt/icesee-spack || true && \
    spack concretize -f && \
    spack install -j"$(nproc)"

# Make a stable Python/MPI/PETSc environment available
RUN . /opt/spack-src/share/spack/setup-env.sh && \
    spack env activate /opt/spack-environment && \
    PYTHON="$(spack location -i python)/bin/python3" && \
    "$PYTHON" -m ensurepip --upgrade || true && \
    "$PYTHON" -m pip install --upgrade pip setuptools wheel

# Install Firedrake in a venv on top of the Spack Python stack
WORKDIR /opt
RUN . /opt/spack-src/share/spack/setup-env.sh && \
    spack env activate /opt/spack-environment && \
    PYTHON="$(spack location -i python)/bin/python3" && \
    MPI_DIR="$(spack location -i openmpi)" && \
    PETSC_DIR="$(spack location -i petsc)" && \
    export PATH="${MPI_DIR}/bin:${PATH}" && \
    export LD_LIBRARY_PATH="${MPI_DIR}/lib:${PETSC_DIR}/lib:${LD_LIBRARY_PATH:-}" && \
    export CC="${MPI_DIR}/bin/mpicc" && \
    export CXX="${MPI_DIR}/bin/mpicxx" && \
    export FC="${MPI_DIR}/bin/mpifort" && \
    export MPICC="${MPI_DIR}/bin/mpicc" && \
    export MPICXX="${MPI_DIR}/bin/mpicxx" && \
    export MPIFC="${MPI_DIR}/bin/mpifort" && \
    export PETSC_DIR="${PETSC_DIR}" && \
    unset PETSC_ARCH && \
    export HDF5_MPI=ON && \
    "$PYTHON" -m venv --system-site-packages /opt/venv-firedrake && \
    source /opt/venv-firedrake/bin/activate && \
    python -m pip install --upgrade pip && \
    printf "setuptools<81\nnumpy<2\npetsc4py==3.24.0\n" > /tmp/constraints.txt && \
    export PIP_CONSTRAINT=/tmp/constraints.txt && \
    python -m pip install "firedrake[check]"

# Helper activation script
RUN cat > /usr/local/bin/activate-spack-firedrake.sh <<'EOF'
#!/bin/bash
set -e
source /opt/spack-src/share/spack/setup-env.sh
spack env activate /opt/spack-environment
export MPI_DIR="$(spack location -i openmpi)"
export PETSC_DIR="$(spack location -i petsc)"
export PATH="/opt/venv-firedrake/bin:${MPI_DIR}/bin:${PATH}"
export LD_LIBRARY_PATH="${MPI_DIR}/lib:${PETSC_DIR}/lib:${LD_LIBRARY_PATH:-}"
export CC="${MPI_DIR}/bin/mpicc"
export CXX="${MPI_DIR}/bin/mpicxx"
export FC="${MPI_DIR}/bin/mpifort"
export MPICC="${MPI_DIR}/bin/mpicc"
export MPICXX="${MPI_DIR}/bin/mpicxx"
export MPIFC="${MPI_DIR}/bin/mpifort"
export HDF5_MPI=ON
unset PETSC_ARCH
exec "$@"
EOF

RUN chmod +x /usr/local/bin/activate-spack-firedrake.sh

ENTRYPOINT ["/usr/local/bin/activate-spack-firedrake.sh"]
CMD ["/bin/bash"]