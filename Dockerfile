# GPU-enabled Dockerfile for qcgnoms
# Base image matches CUDA/CuDNN versions from qcgnoms.yml (cudatoolkit=11.3.1, cudnn=8.2.1)
FROM nvidia/cuda:11.3.1-cudnn8-devel-ubuntu20.04

ENV DEBIAN_FRONTEND=noninteractive

# Install system packages commonly needed by scientific/chemistry packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates wget git bzip2 build-essential curl ca-certificates \
    libssl-dev libffi-dev libgomp1 libopenblas-dev liblapack-dev \
    openmpi-bin libopenmpi-dev libxrender1 libsm6 libxext6 libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Install Miniconda (conda) to /opt/conda
ENV CONDA_DIR=/opt/conda
RUN set -ex \
    && curl -fL -o /tmp/miniconda.sh https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh \
    && bash /tmp/miniconda.sh -b -p "$CONDA_DIR" \
    && rm /tmp/miniconda.sh \
    && "$CONDA_DIR/bin/conda" config --set always_yes yes --set changeps1 no || true \
    && "$CONDA_DIR/bin/conda" update -n base -c defaults conda || true

ENV PATH=$CONDA_DIR/bin:$PATH
# Accept Anaconda channel Terms of Service to allow non-interactive installs in Docker
RUN conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main || true \
    && conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r || true

# Create a working directory and copy the environment file
WORKDIR /workspace
COPY qcgnoms.yml /workspace/

# Create the conda environment using conda. This may take a while.
RUN conda env create -f qcgnoms.yml -n qcgnoms -y || \
    (echo "conda env create failed; retrying" && conda env create -f qcgnoms.yml -n qcgnoms -y)

# Clean up conda caches to reduce image size
RUN conda clean -afy

# Use the conda-run shell so the environment is active by default for subsequent commands
SHELL ["conda", "run", "-n", "qcgnoms", "/bin/bash", "-lc"]

# Optional: expose a workspace volume and default to bash
VOLUME ["/workspace"]
WORKDIR /workspace
# Default to a bash shell inside the qcgnoms conda environment
CMD ["bash", "-lc", "source /opt/conda/etc/profile.d/conda.sh && conda activate qcgnoms && exec bash"]

# Notes:
# - Build with: docker build -t qcgnoms:latest -f Dockerfile .
# - Run with GPU support (Docker Desktop or nvidia-container-toolkit):
#   docker run --gpus all -it --rm -v "D:/Marney:/workspace" -w /workspace qcgnoms:latest
# - Inside the container you can verify CUDA/PyTorch with:
#   python -c "import torch; print(torch.__version__, torch.cuda.is_available(), torch.cuda.device_count())"
