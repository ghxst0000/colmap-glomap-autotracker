# Photogeometry Autotracker

Automated photogrammetry pipeline on macOS Apple Silicon using Docker.  
Replicates [polyfjord's Windows workflow](https://gist.github.com/polyfjord/fc22f22770cd4dd365bb90db67a4f2dc) with native Linux tools.

**Versions:** COLMAP 3.12.3 · GLOMAP 1.1.0 · FFmpeg (latest apt)

---

## What it does

For every video in `./videos/`:

1. **FFmpeg** — extracts every frame as JPEG
2. **COLMAP `feature_extractor`** — detects SIFT features (CPU mode)
3. **COLMAP `sequential_matcher`** — matches overlapping frames (overlap=15)
4. **GLOMAP `mapper`** — fast sparse 3D reconstruction
5. **COLMAP `model_converter`** — exports TXT format for Blender

Output lands in `./scenes/<video_name>/sparse/`.

---

## Setup (one-time)

### Prerequisites

- [Docker Desktop for Mac](https://docs.docker.com/desktop/install/mac-install/) with Rosetta 2 enabled (Settings → General → "Use Rosetta for x86_64/amd64…")

### Build the Docker image

```bash
docker compose build
```

> ⏳ **First build takes ~20–40 minutes** — COLMAP and GLOMAP are compiled from source.  
> Subsequent runs use the cached image instantly.

---

## Usage

1. **Drop your videos** into `./videos/`  
   (supports any format FFmpeg understands: `.mp4`, `.mov`, `.mkv`, etc.)

2. **Run the pipeline:**

   ```bash
   docker compose run --rm autotracker
   ```

3. **Find results** in `./scenes/<video_name>/`:

   ```
   scenes/
   └── my_video/
       ├── images/          ← extracted frames
       ├── database.db      ← COLMAP feature database
       └── sparse/
           ├── cameras.txt  ← camera parameters
           ├── images.txt   ← camera poses
           ├── points3D.txt ← sparse point cloud
           └── 0/           ← binary model (BIN + TXT)
   ```

---

## Import into Blender

Using the [Blender COLMAP importer](https://github.com/SBCV/Blender-Addon-Photogrammetry-Importer):

1. **File → Import → Colmap (NVM / BIN / TXT / PLY)**
2. Navigate to `scenes/<video_name>/sparse/`
3. Select `cameras.txt` or the `0/` subfolder

---

## Re-running a video

The script skips any scene folder that already exists. To re-process a video, delete its scene folder:

```bash
rm -rf "scenes/my_video"
docker compose run --rm autotracker
```

---

## Pipeline notes

| Setting | Value | Reason |
|---|---|---|
| GPU | Disabled | No CUDA in Docker on Apple Silicon |
| Sequential overlap | 15 frames | Good balance for video footage |
| Frame quality | `-qscale:v 2` | High-quality JPEG (1=best, 31=worst) |
| Camera model | Single camera | Correct for single-lens video |

---

## Reference

- [polyfjord YouTube guide](https://www.youtube.com/watch?v=PhdEk_RxkGQ)
- [COLMAP docs](https://colmap.github.io)
- [GLOMAP repo](https://github.com/colmap/glomap)
