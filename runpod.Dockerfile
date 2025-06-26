# --- BUILDER STAGE ---
# This stage installs all build dependencies and Python packages.
# We use a 'devel' image from NVIDIA as it includes compilers and development tools.
FROM nvidia/cuda:11.8.0-cudnn8-devel-ubuntu22.04 AS builder

ENV LANG C.UTF-8
ENV DEBIAN_FRONTEND=noninteractive
ENV OMP_NUM_THREADS 1

# Install core system dependencies needed for building.
# Combine apt-get commands and clean up in a single RUN layer for efficiency.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    python3 python3-pip python3-setuptools python3-wheel \
    build-essential libproj-dev libgdal-dev gdal-bin \
    git wget curl unzip \
    libgtk2.0-dev libgl1-mesa-glx libglib2.0-0 \
    libsm6 libxext6 libxrender1 && \
    rm -rf /var/lib/apt/lists/*

# Set the working directory for the application in the builder stage.
WORKDIR /code

# --- OPTIMIZATION FOR PYTHON DEPENDENCIES IN BUILDER STAGE ---
# 1. Copy only the requirements file first.
#    This layer's cache is only invalidated if requirements.txt changes.
COPY requirements.txt /code/requirements.txt

# 2. Install Python dependencies.
#    This layer will be cached if requirements.txt (and the previous COPY layer) hasn't changed.
#    This is the key optimization for faster builds when only code changes.
RUN pip3 install --no-cache-dir --upgrade pip && \
    pip3 install --no-cache-dir -r requirements.txt

# 3. Copy the rest of the application code.
#    This layer is the most frequently changed, so it should come last in the builder stage.
#    Changes here will only invalidate this layer and subsequent operations in this stage.
COPY . /code/

# OpenDroneMap might do some additional compilation or setup here in the builder stage.
# For example, if it compiles C++ extensions, those steps would go here.
# Assuming run.py is the entry point, no explicit "build" step is needed beyond pip install.


# --- RUNTIME STAGE ---
# This stage is built on a lighter 'runtime' NVIDIA CUDA image.
FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04

ENV LANG C.UTF-8
ENV OMP_NUM_THREADS 1

# Re-install only the *runtime* system dependencies required for ODM to run.
# Avoid installing build tools in the final image to keep it lean.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    python3 libproj-dev libgdal-dev gdal-bin \
    libgtk2.0-0 libgl1-mesa-glx libglib2.0-0 \
    libsm6 libxext6 libxrender1 && \
    rm -rf /var/lib/apt/lists/*

# Set the working directory for the application in the final image.
WORKDIR /code

# Copy the Python environment and application code from the builder stage.
# `--from=builder` specifies the source stage.
# This step brings over the installed Python packages and the application code.
COPY --from=builder /usr/local/lib/python3.10/dist-packages /usr/local/lib/python3.10/dist-packages
COPY --from=builder /usr/local/bin /usr/local/bin
COPY --from=builder /code /code

# Copy and set up the custom entrypoint script (from our previous discussion).
# This needs to be done in the final stage as it's part of the runtime behavior.
COPY my_runpod_entrypoint.sh /usr/local/bin/my_runpod_entrypoint.sh
RUN chmod +x /usr/local/bin/my_runpod_entrypoint.sh

# Set the custom entrypoint for the container.
ENTRYPOINT ["/usr/local/bin/my_runpod_entrypoint.sh"]

# Set the default command arguments for the entrypoint (as discussed).
# Leaving it empty here allows my_runpod_entrypoint.sh to handle the default `python3 /code/run.py` call.
CMD []
