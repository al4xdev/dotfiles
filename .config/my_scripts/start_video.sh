#!/bin/bash
source $HOME/ComfyUI/.venv/bin/activate
export PYTHONUNBUFFERED=1


export PYTORCH_CUDA_ALLOC_CONF="expandable_segments:True"
	# --gpu-only \
	# --cuda-malloc
    # --highvram \

python $HOME/ComfyUI/main.py \
    --listen 0.0.0.0 \
    --port 8001 \
    --use-sage-attention \
    --disable-xformers \
	--cuda-malloc
