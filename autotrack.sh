#!/usr/bin/env bash
# ================================================================
# autotrack.sh — Automated photogrammetry pipeline
# Based on polyfjord's workflow: https://gist.github.com/polyfjord/fc22f22770cd4dd365bb90db67a4f2dc
#
# Pipeline per video:
#   1) FFmpeg  – extract frames at EXTRACT_FPS (default: 4 fps)
#   2) COLMAP  – feature_extractor (CPU SIFT)
#   3) COLMAP  – sequential_matcher (overlap=15)
#   4) COLMAP  – global_mapper (fast SfM)
#   5) COLMAP  – model_converter → TXT (Blender import)
#
# Override defaults via .env or:
#   docker compose run -e EXTRACT_FPS=2 --rm autotracker
# ================================================================
set -euo pipefail

VIDEOS_DIR="/workspace/02 VIDEOS"
SCENES_DIR="/workspace/04 SCENES"

# Settings — override via .env or: docker compose run -e EXTRACT_FPS=2 --rm autotracker
EXTRACT_FPS="${EXTRACT_FPS:-4}"
SIFT_MAX_NUM_FEATURES="${SIFT_MAX_NUM_FEATURES:-8192}"
SIFT_MAX_IMAGE_SIZE="${SIFT_MAX_IMAGE_SIZE:-3200}"
SIFT_NUM_THREADS="${SIFT_NUM_THREADS:-4}"
SEQUENTIAL_OVERLAP="${SEQUENTIAL_OVERLAP:-15}"

# ── Sanity checks ─────────────────────────────────────────────
if ! command -v ffmpeg &>/dev/null; then
    echo "[ERROR] ffmpeg not found on PATH." >&2; exit 1
fi
if ! command -v colmap &>/dev/null; then
    echo "[ERROR] colmap not found on PATH." >&2; exit 1
fi

mkdir -p "$SCENES_DIR"

# ── Count videos ─────────────────────────────────────────────
shopt -s nullglob
videos=("$VIDEOS_DIR"/*)
TOTAL=${#videos[@]}

if [[ $TOTAL -eq 0 ]]; then
    echo "[INFO] No video files found in \"$VIDEOS_DIR\"."
    echo "       Drop your videos there and re-run."
    exit 0
fi

echo "============================================================"
echo " Starting autotrack pipeline on $TOTAL video(s) …"
echo "============================================================"

IDX=0
for VIDEO in "${videos[@]}"; do
    [[ -f "$VIDEO" ]] || continue
    IDX=$((IDX + 1))
    BASE=$(basename "$VIDEO")
    NAME="${BASE%.*}"

    echo ""
    echo "[$IDX/$TOTAL] === Processing \"$BASE\" ==="

    SCENE="$SCENES_DIR/$NAME"
    IMG_DIR="$SCENE/images"
    SPARSE_DIR="$SCENE/sparse"

    DONE_MARKER="$SCENE/.done"

    # ── Skip if already reconstructed ────────────────────────
    if [[ -f "$DONE_MARKER" ]]; then
        echo "• Skipping \"$NAME\" — already reconstructed."
        continue
    fi

    # ── Clean up any interrupted/partial run ─────────────────
    if [[ -d "$SCENE" ]]; then
        echo "• Removing incomplete scene \"$NAME\" and retrying …"
        rm -rf "$SCENE"
    fi

    mkdir -p "$IMG_DIR" "$SPARSE_DIR"

    # ── 1) Extract frames ─────────────────────────────────────
    if [[ "${EXTRACT_FPS}" == "0" ]]; then
        echo "[1/5] Extracting all frames (native fps) …"
        FFMPEG_VF_ARGS=()
    else
        echo "[1/5] Extracting frames at ${EXTRACT_FPS} fps …"
        FFMPEG_VF_ARGS=(-vf "fps=${EXTRACT_FPS}")
    fi

    if ! ffmpeg -loglevel error -stats \
            -i "$VIDEO" \
            "${FFMPEG_VF_ARGS[@]}" \
            -qscale:v 2 \
            "$IMG_DIR/frame_%06d.jpg"; then
        echo "✗ FFmpeg failed — skipping \"$NAME\"."
        rm -rf "$SCENE"; continue
    fi

    frame_count=$(find "$IMG_DIR" -name "*.jpg" | wc -l)
    if [[ $frame_count -eq 0 ]]; then
        echo "✗ No frames extracted — skipping \"$NAME\"."
        rm -rf "$SCENE"; continue
    fi
    echo "  Extracted $frame_count frames."

    # ── 2) COLMAP feature extraction ─────────────────────────
    echo "[2/5] COLMAP feature_extractor …"
    if ! colmap feature_extractor \
            --database_path "$SCENE/database.db" \
            --image_path "$IMG_DIR" \
            --ImageReader.single_camera 1 \
            --FeatureExtraction.use_gpu 0 \
            --FeatureExtraction.num_threads "${SIFT_NUM_THREADS}" \
            --FeatureExtraction.max_image_size "${SIFT_MAX_IMAGE_SIZE}" \
            --SiftExtraction.max_num_features "${SIFT_MAX_NUM_FEATURES}"; then
        echo "✗ feature_extractor failed — skipping \"$NAME\"."
        rm -rf "$SCENE"; continue
    fi

    # ── 3) COLMAP sequential matching ────────────────────────
    echo "[3/5] COLMAP sequential_matcher …"
    if ! colmap sequential_matcher \
            --database_path "$SCENE/database.db" \
            --FeatureMatching.use_gpu 0 \
            --FeatureMatching.num_threads "${SIFT_NUM_THREADS}" \
            --SequentialMatching.overlap "${SEQUENTIAL_OVERLAP}"; then
        echo "✗ sequential_matcher failed — skipping \"$NAME\"."
        rm -rf "$SCENE"; continue
    fi

    # ── 4) COLMAP global_mapper sparse reconstruction ──────────────────────
    echo "[4/5] COLMAP global_mapper …"
    if ! colmap global_mapper \
            --database_path "$SCENE/database.db" \
            --image_path "$IMG_DIR" \
            --output_path "$SPARSE_DIR"; then
        echo "✗ glomap mapper failed — skipping \"$NAME\"."
        rm -rf "$SCENE"; continue
    fi

    # ── 5) Export TXT for Blender ─────────────────────────────
    echo "[5/5] COLMAP model_converter → TXT …"
    # Export inside sparse/0/ (BIN + TXT side by side)
    if [[ -d "$SPARSE_DIR/0" ]]; then
        colmap model_converter \
            --input_path  "$SPARSE_DIR/0" \
            --output_path "$SPARSE_DIR/0" \
            --output_type TXT 2>/dev/null || true

        # Also export to sparse/ parent (Blender auto-detection)
        colmap model_converter \
            --input_path  "$SPARSE_DIR/0" \
            --output_path "$SPARSE_DIR" \
            --output_type TXT 2>/dev/null || true
    fi

    touch "$DONE_MARKER"
    echo "✓ Finished \"$NAME\" ($IDX/$TOTAL)"
    echo "  → $SPARSE_DIR"
done

echo ""
echo "--------------------------------------------------------------"
echo " All jobs finished — results are in \"$SCENES_DIR\"."
echo " Import into Blender: File > Import > Colmap"
echo " Point to: scenes/<video_name>/sparse/"
echo "--------------------------------------------------------------"
