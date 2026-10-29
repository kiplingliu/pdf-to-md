# pdf-to-md

## Setup

Create Vast.ai template with this config:

```
vastai create instance <OFFER_ID> --image vllm/vllm-openai:v0.20.1 --env '-e MAX_NUM_SEQS=32 -e MAX_BATCHED_TOKENS=8192' --onstart-cmd 'curl -fsSL https://raw.githubusercontent.com/kiplingliu/pdf-to-md/refs/heads/master/surya-vllm-onstart.sh -o /root/onstart.sh && bash /root/onstart.sh' --disk 40 --ssh --direct
```

## Manual restart

Pass an optional sixth argument to restart a single PDF at a chunk directory number:

```bash
./run_marker.sh <vast_ip> <vast_ssh_port> <gpu_type> \
  pdf/computer-networking-a-top-down-approach.pdf \
  computer-networking-a-top-down-approach 00300
```

This reruns chunk `00300` (zero-based PDF pages 300–349) and every subsequent chunk. Earlier chunks are kept and included when the combined Markdown is rebuilt. Use the same output directory as the original run. The starting chunk defaults to `0` and must be a multiple of 50; leading zeros are accepted. Folder input supports starting at `0` only.
