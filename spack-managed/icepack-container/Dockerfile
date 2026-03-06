FROM docker.io/bkyanjo/spack-firedrake:latest

LABEL org.opencontainers.image.authors="Brian Kyanjo <briankyanjo@u.boisestate.edu>" \
      org.opencontainers.image.title="Spack Icepack base" \
      org.opencontainers.image.description="Icepack installed on top of the Spack Firedrake base image"

SHELL ["/bin/bash", "-lc"]
ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /opt

# Minimal runtime/build helpers for pip installs and git clone
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    ca-certificates \
    curl \
 && rm -rf /var/lib/apt/lists/*

# Install Icepack into the existing Firedrake venv
RUN source /opt/spack-src/share/spack/setup-env.sh && \
    spack env activate /opt/spack-environment && \
    export MPI_DIR="$(spack location -i openmpi)" && \
    export PETSC_DIR="$(spack location -i petsc)" && \
    export PATH="/opt/venv-firedrake/bin:${MPI_DIR}/bin:${PATH}" && \
    export LD_LIBRARY_PATH="${MPI_DIR}/lib:${PETSC_DIR}/lib:${LD_LIBRARY_PATH:-}" && \
    export CC="${MPI_DIR}/bin/mpicc" && \
    export CXX="${MPI_DIR}/bin/mpicxx" && \
    export FC="${MPI_DIR}/bin/mpifort" && \
    export MPICC="${MPI_DIR}/bin/mpicc" && \
    export MPICXX="${MPI_DIR}/bin/mpicxx" && \
    export MPIFC="${MPI_DIR}/bin/mpifort" && \
    export HDF5_MPI=ON && \
    unset PETSC_ARCH && \
    source /opt/venv-firedrake/bin/activate && \
    python -m pip install --upgrade pip && \
    python -m pip install patchelf && \
    git clone --depth=1 https://github.com/icepack/icepack.git /opt/icepack && \
    python -m pip install --editable /opt/icepack && \
    python -m pip install gmsh ipykernel

# Optional strip pass
RUN set -euo pipefail; \
    for ROOT in /opt/venv-firedrake; do \
      [ -d "$ROOT" ] || continue; \
      find -L "$ROOT" -type f -exec readlink -f '{}' \; | sort -u | \
        xargs -r file -i | \
        awk -F: '/charset=binary/ && /x-executable|x-sharedlib/ {print $1}' | \
        xargs -r strip --strip-unneeded 2>/dev/null || true; \
    done

# Helper script for Icepack runtime
RUN cat > /usr/local/bin/activate-spack-icepack.sh <<'EOF'
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

RUN chmod +x /usr/local/bin/activate-spack-icepack.sh

ENTRYPOINT ["/usr/local/bin/activate-spack-icepack.sh"]
CMD ["/bin/bash"]