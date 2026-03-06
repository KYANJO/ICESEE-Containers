# ICESEE-Container

Container recipes and build definitions for the **ICESEE** software ecosystem.

This repository provides **Docker** and **Apptainer/Singularity** container definitions for building and running ICESEE and its dependencies in a portable, reproducible, and platform-aware way. The containers are intended for use across:

- **Local development environments**
- **Cloud platforms**
- **High-Performance Computing (HPC) clusters**

The goal of this repository is to make ICESEE deployment easier, more reproducible, and more consistent across diverse compute environments.

---

## Overview

Scientific software stacks often depend on complex combinations of compilers, MPI implementations, numerical libraries, and domain-specific packages. Differences between laptops, cloud virtual machines, and HPC clusters can make installation and reproducibility difficult.

**ICESEE-Container** addresses this problem by maintaining container definitions that package ICESEE and its required dependencies in a controlled environment. These recipes help users:

- build reproducible environments for development and research,
- reduce dependency and configuration issues,
- simplify onboarding for new users and collaborators,
- support deployment across heterogeneous systems,
- enable portability between local, cloud, and HPC resources.

---

## What this repository contains

This repository includes container recipes for:

- **Docker**
  - Suitable for local development, CI/CD, cloud deployment, and workstation use.
- **Apptainer / Singularity**
  - Suitable for HPC systems where Docker is unavailable or restricted.

Depending on the recipe, containers may include:

- ICESEE source and runtime environment
- Scientific libraries and compiler toolchains
- MPI-enabled builds
- PETSc and related numerical dependencies
- Optional workflow-specific tools used by ICESEE

---

## Use cases

The containers in this repository are intended to support three main environments.

### 1. Local development
For developers and researchers working on laptops or workstations, Docker-based environments provide a clean and reproducible setup for building, testing, and iterating on ICESEE.

### 2. Cloud deployment
For cloud-based workflows, these recipes provide portable environments that can be used on virtual machines, container platforms, or batch systems.

### 3. HPC execution
For HPC systems, Apptainer/Singularity recipes enable containerized execution within cluster policies and scheduler-based environments, while maintaining compatibility with system MPI and performance-oriented libraries where appropriate.

---

## Repository goals

The main goals of **ICESEE-Container** are:

- **Reproducibility**  
  Ensure that ICESEE builds and runs in consistent environments across systems.

- **Portability**  
  Support the same scientific workflow on local machines, cloud resources, and HPC clusters.

- **Maintainability**  
  Keep container definitions organized, versioned, and easy to update as ICESEE evolves.

- **Scalability**  
  Enable transition from development environments to production and large-scale HPC runs.

- **Accessibility**  
  Lower the barrier to entry for new users who need a working ICESEE environment without manually installing a large dependency stack.

---

## Repository structure

A suggested structure for this repository is:

```text
ICESEE-Container/
├── spack-managed/
│   ├── firedrake-container/
│   ├── icepack-container/
│   ├── issm-container/
│   ├── icesee-container/
│   └── firedrake-icepack-issm-icesee-container/
├── raw-recipes/
│   ├── firedrake-container/
│   ├── icepack-container/
│   ├── issm-container/
│   ├── issm-icesee-container/
│   └── firedrake-icepack-container/
└── README.md
