FROM docker.io/bkyanjo/spack-firedrake:latest

LABEL org.opencontainers.image.authors="Brian Kyanjo <briankyanjo@u.boisestate.edu>" \
      org.opencontainers.image.title="Spack ICESEE base" \
      org.opencontainers.image.description="ICESEE installed on top of the Spack Python/MPI stack"

SHELL ["/bin/bash", "-lc"]
ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /opt

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    ca-certificates \
    curl \
 && rm -rf /var/lib/apt/lists/*

# Copy helper script for generating pip-only requirements
RUN mkdir -p /opt/icesee-tools /opt/ICESEE /opt/requirements
COPY scripts/gen_pip_reqs.py /opt/icesee-tools/gen_pip_reqs.py

# Clone ICESEE source
RUN git clone --depth=1 https://github.com/ICESEE-project/ICESEE.git /opt/ICESEE

# Install ICESEE pip-managed dependencies, excluding ABI-sensitive ones handled by Spack
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
    python /opt/icesee-tools/gen_pip_reqs.py \
      --pyproject /opt/ICESEE/pyproject.toml \
      --out /opt/requirements/pip.auto.txt \
      --extras mpi,viz && \
    python -m pip install --upgrade pip setuptools wheel && \
    python -m pip install --no-cache-dir -r /opt/requirements/pip.auto.txt && \
    python -m pip install --no-cache-dir -e /opt/ICESEE

# Optional source visibility
ENV PYTHONPATH=/opt/ICESEE:${PYTHONPATH}

# Runtime helper
RUN cat > /usr/local/bin/activate-spack-icesee.sh <<'EOF'
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

RUN chmod +x /usr/local/bin/activate-spack-icesee.sh

ENTRYPOINT ["/usr/local/bin/activate-spack-icesee.sh"]
CMD ["/bin/bash"]