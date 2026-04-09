# ============================================================
# Photogeometry Autotracker
# Ubuntu 22.04 with COLMAP 3.12.3 + GLOMAP 1.1.0 + FFmpeg
# Runs on macOS Apple Silicon via linux/amd64 emulation
# ============================================================

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# ── Install CMake 3.28+ from Kitware (Ubuntu 22.04 ships 3.22, GLOMAP needs 3.28) ──
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates

# ── System packages ──────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Build tools
    git \
    ninja-build \
    build-essential \
    pkg-config \
    unzip \
    cmake \
    # COLMAP dependencies
    libboost-program-options-dev \
    libboost-filesystem-dev \
    libboost-graph-dev \
    libboost-system-dev \
    libboost-test-dev \
    libeigen3-dev \
    libflann-dev \
    libfreeimage-dev \
    libmetis-dev \
    libgoogle-glog-dev \
    libgflags-dev \
    libsqlite3-dev \
    libglew-dev \
    qtbase5-dev \
    libqt5opengl5-dev \
    libcgal-dev \
    libceres-dev \
    libgtest-dev \
    libopenimageio-dev \
    libopencv-dev \
    openimageio-tools \
    # FFmpeg
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# ── Build COLMAP 3.12.3 ──────────────────────────────────────
WORKDIR /build
RUN git clone --depth 1 --branch 4.0.3 \
    https://github.com/colmap/colmap.git colmap-src

WORKDIR /build/colmap-src
# Limit to 2 parallel jobs to avoid OOM during C++ compilation
RUN mkdir build && cd build && \
    cmake -GNinja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DCUDA_ENABLED=OFF \
        -DGUI_ENABLED=OFF \
        -DTESTS_ENABLED=OFF \
        .. && \
    ninja -j2 && \
    ninja install && \
    ldconfig

# ── Clean up build artifacts ─────────────────────────────────
RUN rm -rf /build

# ── Workspace layout (mirrors polyfjord folder convention) ───
RUN mkdir -p \
    "/workspace/02 VIDEOS" \
    "/workspace/04 SCENES"

# ── Copy the autotrack script ────────────────────────────────
COPY autotrack.sh /usr/local/bin/autotrack.sh
RUN chmod +x /usr/local/bin/autotrack.sh

WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/autotrack.sh"]
