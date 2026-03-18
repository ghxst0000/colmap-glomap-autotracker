# Photogeometry Autotracker

Automated photogrammetry pipeline on macOS Apple Silicon using Docker.  
Replicates [polyfjord's Windows workflow](https://gist.github.com/polyfjord/fc22f22770cd4dd365bb90db67a4f2dc) with native Linux tools.

**Versions:** COLMAP 3.12.3 · GLOMAP 1.1.0 · FFmpeg (latest apt)

---

## What it does

For every video in `./videos/`:

1. **FFmpeg** — extracts frames as high-quality JPEG (`-qscale:v 2`)
2. **COLMAP `feature_extractor`** — detects SIFT features (CPU, multi-threaded)
3. **COLMAP `sequential_matcher`** — matches overlapping frames
4. **GLOMAP `mapper`** — fast global sparse 3D reconstruction
5. **COLMAP `model_converter`** — exports TXT format for Blender

Output lands in `./scenes/<video_name>/sparse/`.

Already-completed scenes (marked with a `.done` file) are skipped automatically. Partial or interrupted runs are cleaned up and retried from scratch.

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

## Configuration

Copy `.env.sample` to `.env` and adjust as needed:

```bash
./setup.sh
```

Or manually:

| Variable | Default | Description |
|---|---|---|
| `EXTRACT_FPS` | `4` | Frames per second to extract (`0` = all frames at native fps) |
| `SIFT_MAX_NUM_FEATURES` | `8192` | Max SIFT features per image |
| `SIFT_MAX_IMAGE_SIZE` | `3200` | Max image dimension fed to SIFT (pixels) |
| `SIFT_NUM_THREADS` | `4` | CPU threads for SIFT extraction and matching |
| `SEQUENTIAL_OVERLAP` | `15` | Overlapping frames for sequential matching |

Override any setting inline without editing `.env`:

```bash
docker compose run -e EXTRACT_FPS=2 -e SEQUENTIAL_OVERLAP=8 --rm autotracker
```

---

## Import into Blender

Using the [Blender COLMAP importer](https://github.com/SBCV/Blender-Addon-Photogrammetry-Importer):

1. **File → Import → Colmap (NVM / BIN / TXT / PLY)**
2. Navigate to `scenes/<video_name>/sparse/`
3. Select `cameras.txt` or the `0/` subfolder

---

## Re-running a video

The script skips any scene that already has a `.done` marker. To re-process a video, delete its scene folder:

```bash
rm -rf "scenes/my_video"
docker compose run --rm autotracker
```

---

## Pipeline notes

| Setting | Default | Reason |
|---|---|---|
| GPU | Disabled | No CUDA in Docker on Apple Silicon |
| `EXTRACT_FPS` | `4` | Good balance of coverage vs. frame count |
| Sequential overlap | `15` frames | Strong connections for video footage |
| Frame quality | `-qscale:v 2` | High-quality JPEG (1=best, 31=worst) |
| Camera model | Single camera | Correct for single-lens video |
| `SIFT_NUM_THREADS` | `4` | Set to your available CPU cores in `.env` |

> **Performance tip:** `SEQUENTIAL_OVERLAP` has the largest impact on matching time — it's O(frames × overlap) pairs. Reducing it from 15 to 8 roughly halves matching time with minimal quality loss on well-shot video.

---

## Reference

- [polyfjord YouTube guide](https://www.youtube.com/watch?v=PhdEk_RxkGQ)
- [COLMAP docs](https://colmap.github.io)
- [GLOMAP repo](https://github.com/colmap/glomap)
