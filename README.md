# pdf-to-md

## Setup

Create Vast.ai template with this config:

```
vastai create instance <OFFER_ID> --image vllm/vllm-openai:v0.20.1 --env '-e MAX_NUM_SEQS=32 -e MAX_BATCHED_TOKENS=8192' --onstart-cmd 'curl -fsSL https://raw.githubusercontent.com/kiplingliu/pdf-to-md/refs/heads/master/surya-vllm-onstart.sh -o /root/onstart.sh && bash /root/onstart.sh' --disk 40 --ssh --direct
```
