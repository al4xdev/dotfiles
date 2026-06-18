#!/bin/bash
source $HOME/comfyui/.venv/bin/activate
export PYTHONUNBUFFERED=1


export PYTORCH_CUDA_ALLOC_CONF="expandable_segments:True"
	# --gpu-only \
	# --cuda-malloc
    # --highvram \

python $HOME/comfyui/main.py \
    --listen 0.0.0.0 \
    --port 8001 \
    --disable-smart-memory \
    --gpu-only \
    --use-sage-attention \
    --disable-xformers \
	--cuda-malloc
