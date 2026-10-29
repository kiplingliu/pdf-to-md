#!/usr/bin/env bash
# Run marker locally against a surya-ocr-2 vLLM server on vast.ai.
# Usage: ./run_marker.sh <vast_ip> <vast_ssh_port> <gpu_type> <pdf_or_folder> [output_dir] [start_chunk]
#   gpu_type must be a key from surya's GPU_VRAM_GB (4090, 5090, a100, l40s, h100, ...)
#   and should match the GPU you rented: marker sizes its request concurrency from it.
#   start_chunk is the chunk directory number (0, 50, 100, ...); leading zeros are accepted.
set -euo pipefail

if (( $# < 4 || $# > 6 )); then
  echo "Usage: $0 <vast_ip> <vast_ssh_port> <gpu_type> <pdf_or_folder> [output_dir] [start_chunk]" >&2
  exit 2
fi

IP=$1; SSH_PORT=$2; GPU=$3; INPUT=$4; OUT=${5:-out}
START_CHUNK=${6:-0}
if [[ ! $START_CHUNK =~ ^[0-9]+$ ]]; then
  echo "start_chunk must be a nonnegative multiple of 50 (for example, 00300)." >&2
  exit 2
fi
START_CHUNK=$((10#$START_CHUNK))
if (( START_CHUNK < 0 || START_CHUNK % 50 != 0 )); then
  echo "start_chunk must be a nonnegative multiple of 50 (for example, 00300)." >&2
  exit 2
fi
if [[ -d $INPUT ]] && (( START_CHUNK != 0 )); then
  echo "start_chunk is only supported for a single PDF." >&2
  exit 2
fi

MODEL=datalab-to/surya-ocr-2
LOCAL_PORT=8000

ssh -o ExitOnForwardFailure=yes -o StrictHostKeyChecking=accept-new -o ServerAliveInterval=30 \
    -N -L "${LOCAL_PORT}:127.0.0.1:8000" -p "$SSH_PORT" "root@${IP}" &
TUNNEL=$!
trap 'kill $TUNNEL 2>/dev/null || true' EXIT

echo "Waiting for vLLM (first start downloads the model and compiles CUDA graphs)..."
for i in $(seq 1 120); do
  if curl -sf "http://127.0.0.1:${LOCAL_PORT}/v1/models" | grep -q "\"${MODEL}\""; then
    echo "Server ready."
    break
  fi
  [ "$i" -eq 120 ] && { echo "Timed out. Check /var/log/vllm.log on the instance." >&2; exit 1; }
  sleep 5
done

export SURYA_INFERENCE_BACKEND=vllm
export SURYA_INFERENCE_URL="http://127.0.0.1:${LOCAL_PORT}/v1"
export SURYA_INFERENCE_HOST=127.0.0.1
export SURYA_INFERENCE_PORT=$LOCAL_PORT
export VLLM_GPU_TYPE=$GPU

COMMON=(--mode balanced --force_ocr)
if [ -d "$INPUT" ]; then
  uv run marker "$INPUT" --output_dir "$OUT" "${COMMON[@]}"
else
  NAME=$(basename "$INPUT" .pdf)
  PAGES=$(uv run python -c "import sys, pypdfium2 as p; print(len(p.PdfDocument(sys.argv[1])))" "$INPUT")
  if (( START_CHUNK >= PAGES )); then
    echo "start_chunk $START_CHUNK is outside this PDF ($PAGES pages)." >&2
    exit 2
  fi
  for ((s=START_CHUNK; s<PAGES; s+=50)); do
    e=$(( s+49 < PAGES-1 ? s+49 : PAGES-1 ))
    uv run marker_single "$INPUT" --page_range "$s-$e" \
      --output_dir "$(printf '%s/chunks/%05d' "$OUT" "$s")" "${COMMON[@]}"
  done
  cat "$OUT"/chunks/*/*/*.md > "$OUT/$NAME.md"
fi
