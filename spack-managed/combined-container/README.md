# Combined Scientific Stack Containers

A reproducible container environment for **glaciology and geophysical modeling** workflows including:

* **Firedrake**
* **Icepack**
* **ICESEE**
* **ISSM**

These containers provide **precompiled MPI/PETSc stacks** and **preconfigured runtime environments** so users can run scientific models **without activating Spack at runtime**.

The containers support both:

* **Docker**
* **Apptainer / Singularity**

---

# Stack Architecture

The container intentionally separates toolchains to maintain compatibility between projects.

```
┌─────────────────────────────────────────────┐
│                USER WORKFLOWS               │
│                                             │
│  Firedrake   Icepack   ICESEE    ISSM       │
└─────────────────────────────────────────────┘
                     │
                     ▼
        Runtime activation wrappers
     (activate-firedrake, with-issm, etc.)
                     │
                     ▼
┌─────────────────────────────────────────────┐
│                MPI / PETSc                  │
│                                             │
│  OpenMPI 5.x  + PETSc 3.24  → Firedrake    │
│  OpenMPI 5.x  + PETSc 3.24  → Icepack      │
│  OpenMPI 5.x  + HDF5 MPI    → ICESEE       │
│                                             │
│  MPICH 4.x   + PETSc 3.22   → ISSM         │
└─────────────────────────────────────────────┘
                     │
                     ▼
              Spack Toolchain
```

---

# Repository Layout

```
issm-container
├── Dockerfile.matlab-runtime
├── Dockerfile.nomatlab-runtime
├── README.md
├── icesee-spack
│   └── repo.yaml
├── issm-env.def
├── issm-env-external-matlab.def
├── scripts
│   └── build_issm_spack.sh
└── spack.yaml
```

---

# Container Variants

Two container variants are provided.

| Variant                       | MATLAB   | Intended Usage            |
| ----------------------------- | -------- | ------------------------- |
| `Dockerfile.matlab-runtime`   | Included | Cloud / local workstation |
| `Dockerfile.nomatlab-runtime` | External | HPC clusters              |

---

# Docker Containers

## 1. MATLAB Runtime Container

This container **includes MATLAB** inside the runtime image.

### Base Image

```
mathworks/matlab:r2024b
```

### Build

```bash
docker build -f Dockerfile.matlab-runtime \
-t bkyanjo/combined-lean:v1.0 .
```

---

### Example Usage

#### Firedrake

```bash
docker run -it bkyanjo/combined-lean:v1.0 \
/usr/local/bin/activate-firedrake python -c "import firedrake"
```

#### Icepack

```bash
docker run -it bkyanjo/combined-lean:v1.0 \
/usr/local/bin/activate-icepack python -c "import icepack"
```

#### ICESEE

```bash
docker run -it bkyanjo/combined-lean:v1.0 \
/usr/local/bin/activate-icesee python -c "import ICESEE"
```

#### ISSM

```bash
docker run -it \
-e MLM_LICENSE_FILE=1711@matlablic.ecs.gatech.edu \
bkyanjo/combined-lean:v1.0 \
/usr/local/bin/activate-issm matlab -batch "issmversion"
```

---

# 2. External MATLAB Container

This container **does not include MATLAB**.

MATLAB must be provided by the **host system or HPC cluster**.

### Base Image

```
ubuntu:24.04
```

---

### Build

```bash
docker build -f Dockerfile.nomatlab-runtime \
-t bkyanjo/combined-lean-external-matlab:v1.0 .
```

---

### Run with Host MATLAB

Example host MATLAB installation:

```
/apps/MATLAB/R2024b
```

Run container:

```bash
docker run -it \
-e MATLABROOT=/opt/matlab/R2024b \
-e MLM_LICENSE_FILE=1711@matlablic.ecs.gatech.edu \
-v /apps/MATLAB/R2024b:/opt/matlab/R2024b \
bkyanjo/combined-lean-external-matlab:v1.0 \
/usr/local/bin/activate-issm-external-matlab matlab -batch "issmversion"
```

---

# Apptainer / Singularity

Two Apptainer definition files mirror the Docker images.

| Definition File                | MATLAB   | Usage          |
| ------------------------------ | -------- | -------------- |
| `issm-env.def`                 | Included | MATLAB runtime |
| `issm-env-external-matlab.def` | External | Cluster MATLAB |

---

## Build Container

### MATLAB Runtime

```bash
apptainer build combined-env.sif issm-env.def
```

### External MATLAB

```bash
apptainer build combined-env-external-matlab.sif \
issm-env-external-matlab.def
```

---

# Running with Apptainer

## Firedrake

```bash
apptainer exec combined-env.sif \
with-firedrake python -c "import firedrake"
```

---

## Icepack

```bash
apptainer exec combined-env.sif \
with-icepack python -c "import icepack"
```

---

## ICESEE

```bash
apptainer exec combined-env.sif \
with-icesee python -c "import ICESEE"
```

---

## ISSM

```bash
apptainer exec combined-env.sif \
with-issm matlab -batch "issmversion"
```

---

# Running ISSM with External MATLAB

Example cluster MATLAB:

```
/apps/MATLAB/R2024b
```

Run:

```bash
apptainer exec \
--bind /apps/MATLAB/R2024b:/opt/matlab/R2024b \
--env MATLABROOT=/opt/matlab/R2024b \
combined-env-external-matlab.sif \
with-issm matlab -batch "issmversion"
```

---

# Persistent Cache

The container automatically configures persistent caches.

Preferred location:

```
/scratch/$USER/combined_cache
```

Fallback:

```
/tmp/$USER/combined_cache
```

Created directories:

```
pyop2
tsfc
xdg
```

These improve performance for:

* Firedrake kernel compilation
* TSFC kernels
* Python runtime caching

---

# Runtime Activation Wrappers

Each toolchain has an activation wrapper.

```
with-firedrake
with-icepack
with-icesee
with-issm
```

These automatically configure:

* MPI
* PETSc
* library paths
* persistent caches

---

# Recommended Deployment

| Environment             | Recommended Container |
| ----------------------- | --------------------- |
| Laptop / workstation    | MATLAB runtime        |
| Cloud computing         | MATLAB runtime        |
| HPC cluster with MATLAB | External MATLAB       |
| Institutional cluster   | External MATLAB       |

---

# MATLAB Licensing

MATLAB licensing is configured through:

```
MLM_LICENSE_FILE
```

Example:

```bash
export MLM_LICENSE_FILE=1711@matlablic.ecs.gatech.edu
```

---

# Maintainer

Brian Kyanjo (briankyanjo@u.boisestate.edu)
Georgia Institute of Technology


