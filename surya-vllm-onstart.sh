#!/bin/bash
# vast.ai on-start script for the surya-ocr-2 inference server.
# Mirrors the args in surya/inference/backends/vllm.py (spawn_fn).
# Template image: vllm/vllm-openai:v0.20.1   Launch mode: SSH
#
# Per-GPU values from surya's _gpu_settings(); set them as template env vars:
#   24GB (4090/3090/A10/L4):  MAX_NUM_SEQS=32   MAX_BATCHED_TOKENS=8192
#   32GB (5090):              MAX_NUM_SEQS=40   MAX_BATCHED_TOKENS=8192
#   40GB (A100-40):           MAX_NUM_SEQS=48   MAX_BATCHED_TOKENS=8192
#   48GB (L40S):              MAX_NUM_SEQS=64   MAX_BATCHED_TOKENS=16384
#   80GB (A100-80/H100):      MAX_NUM_SEQS=104  MAX_BATCHED_TOKENS=16384
#   16GB (T4):                MAX_NUM_SEQS=16   MAX_BATCHED_TOKENS=4096  DTYPE=float16
# T4 and other pre-Ampere cards need DTYPE=float16 (no bf16 support).

MODEL=datalab-to/surya-ocr-2
MAX_NUM_SEQS=${MAX_NUM_SEQS:-32}
MAX_BATCHED_TOKENS=${MAX_BATCHED_TOKENS:-8192}
DTYPE=${DTYPE:-bfloat16}

# Bound to 127.0.0.1: reachable only through an SSH tunnel, never publicly.
nohup vllm serve "$MODEL" \
  --served-model-name "$MODEL" \
  --host 127.0.0.1 --port 8000 \
  --no-enforce-eager \
  --max-num-seqs "$MAX_NUM_SEQS" \
  --dtype "$DTYPE" \
  --max-model-len 18000 \
  --max-num-batched-tokens "$MAX_BATCHED_TOKENS" \
  --gpu-memory-utilization 0.85 \
  --enable-prefix-caching \
  --mm-processor-kwargs '{"min_pixels": 3136, "max_pixels": 6291456}' \
  --speculative-config '{"method": "mtp", "num_speculative_tokens": 2}' \
  > /var/log/vllm.log 2>&1 &
