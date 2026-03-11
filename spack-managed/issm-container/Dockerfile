# =========================
# Stage 1: build everything
# =========================
FROM mathworks/matlab:r2024b AS builder

LABEL org.opencontainers.image.authors="Brian Kyanjo <briankyanjo@u.boisestate.edu>" \
      org.opencontainers.image.title="ISSM builder" \
      org.opencontainers.image.description="Builder stage for MATLAB + Spack-managed MPICH/PETSc toolchain and ISSM"

SHELL ["/bin/bash", "-lc"]
USER root
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    binutils \
    ca-certificates \
    curl \
    file \
    gfortran \
    git \
    make \
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
    flex \
    bison \
    libssl-dev \
    libffi-dev \
    libhwloc-dev \
    libnuma-dev \
    libblas-dev \
    liblapack-dev \
    zlib1g-dev \
    locales \
    cmake \
    gmsh \
 && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

WORKDIR /opt

# Install Spack
RUN git clone --depth=1 https://github.com/spack/spack.git /opt/spack-src

ENV SPACK_ROOT=/opt/spack-src
ENV PATH=/opt/spack-src/bin:$PATH

# Copy Spack environment and ISSM build helper
COPY spack.yaml /opt/spack-environment/spack.yaml
COPY scripts/build_issm_spack.sh /opt/build_issm_spack.sh

RUN chmod +x /opt/build_issm_spack.sh

# Install Spack toolchain
WORKDIR /opt/spack-environment
RUN source /opt/spack-src/share/spack/setup-env.sh && \
    spack env activate . && \
    spack concretize -f && \
    spack install -j"$(nproc)"

# Ensure pip tooling exists in Spack Python
RUN source /opt/spack-src/share/spack/setup-env.sh && \
    spack env activate /opt/spack-environment && \
    PYTHON="$(spack location -i python)/bin/python3" && \
    "$PYTHON" -m ensurepip --upgrade || true && \
    "$PYTHON" -m pip install --upgrade pip setuptools wheel

# Build ISSM using the Spack-managed MPICH/PETSc stack
RUN export ISSM_DIR="/opt/ISSM" && /opt/build_issm_spack.sh

# Precompute runtime environment so final image does not need Spack activation
RUN source /opt/spack-src/share/spack/setup-env.sh && \
    spack env activate /opt/spack-environment && \
    mkdir -p /opt/runtime-env && \
    MPI_DIR="$(spack location -i mpich)" && \
    PETSC_DIR="/opt/ISSM/externalpackages/petsc/src" && \
    PYTHON_DIR="$(spack location -i python)" && \
    MATLABROOT="${MATLABROOT:-/opt/matlab/R2024b}" && \
    cat > /opt/runtime-env/issm-env.sh <<EOF
export MPI_DIR="${MPI_DIR}"
export PETSC_DIR="${PETSC_DIR}"
export PYTHON_DIR="${PYTHON_DIR}"
export MATLABROOT="${MATLABROOT}"
export ISSM_DIR="/opt/ISSM"
export PATH="${MPI_DIR}/bin:/opt/ISSM/bin:\${PATH}"
export LD_LIBRARY_PATH="${MPI_DIR}/lib:${PETSC_DIR}/lib:\${LD_LIBRARY_PATH:-}"
export HDF5_MPI=ON
export MLM_LICENSE_FILE=1711@matlablic.ecs.gatech.edu
EOF

# Runtime helper
RUN cat > /usr/local/bin/activate-issm-nospack.sh <<'EOF'
#!/bin/bash
set -e
source /opt/runtime-env/issm-env.sh

# Ensure MATLAB uses GCC libstdc++ (fix for GLIBCXX_3.4.31)
# if command -v spack >/dev/null 2>&1; then
#   GCC_PREFIX="$(spack location -i gcc@13)"
#   if [[ -n "$GCC_PREFIX" ]]; then
#     PRELOAD="$GCC_PREFIX/lib64/libstdc++.so.6"
#     [[ -f "$PRELOAD" ]] || PRELOAD="$GCC_PREFIX/lib/libstdc++.so.6"
#     if [[ -f "$PRELOAD" ]]; then
#       export LD_PRELOAD="${PRELOAD}${LD_PRELOAD:+:$LD_PRELOAD}"
#     fi
#   fi
# fi

# Add ISSM environment
if [ -f /opt/ISSM/etc/environment.sh ]; then
    set +u
    . /opt/ISSM/etc/environment.sh
    set -u
fi

exec "$@"
EOF

RUN chmod +x /usr/local/bin/activate-issm-nospack.sh

# Optional strip pass
RUN set -euo pipefail; \
    for ROOT in /opt/spack /opt/ISSM; do \
      [ -d "$ROOT" ] || continue; \
      find -L "$ROOT" -type f -exec readlink -f '{}' \; | sort -u | \
        xargs -r file -i | \
        awk -F: '/charset=binary/ && /x-executable|x-sharedlib/ {print $1}' | \
        xargs -r strip --strip-unneeded 2>/dev/null || true; \
    done

# Build-time sanity checks
RUN source /opt/runtime-env/issm-env.sh && \
    test -x /opt/ISSM/bin/issm.exe -o -d /opt/ISSM/bin && \
    test -f /opt/ISSM/etc/environment.sh && \
    mpicc --version && \
    python3 --version


# =========================
# Stage 2: lean runtime image
# =========================
FROM mathworks/matlab:r2024b AS runtime

LABEL org.opencontainers.image.authors="Brian Kyanjo <briankyanjo@u.boisestate.edu>" \
      org.opencontainers.image.title="ISSM lean runtime" \
      org.opencontainers.image.description="Lean runtime image for MATLAB + Spack-built ISSM without Spack activation at startup"

SHELL ["/bin/bash", "-lc"]
USER root
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    file \
    gfortran \
    git \
    locales \
    perl \
    python3 \
    python3-venv \
    xz-utils \
    zlib1g \
    libffi8 \
    libhwloc15 \
    libnuma1 \
 && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Copy only what is needed at runtime
COPY --from=builder /opt/spack /opt/spack
COPY --from=builder /opt/ISSM /opt/ISSM
COPY --from=builder /opt/runtime-env /opt/runtime-env
COPY --from=builder /usr/local/bin/activate-issm-nospack.sh /usr/local/bin/activate-issm-nospack.sh

ENV OMP_NUM_THREADS=1
ENV OPENBLAS_NUM_THREADS=1
ENV HDF5_MPI=ON
ENV ISSM_DIR=/opt/ISSM

RUN chmod +x /usr/local/bin/activate-issm-nospack.sh

ENTRYPOINT ["/usr/local/bin/activate-issm-nospack.sh"]
CMD ["/bin/bash"]