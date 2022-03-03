# Pytorch Dockerfile for graphics cards capability 3.0

This Dockerfile serves the latest pytorch for the sm\_30 NVIDIA architecture (compute capability 3.0).

CUDA 10.2 cuDNN 7.


## Build

```
docker build -t pytorch-sm30 .
```

## Test

```
docker run -it --rm --gpus all pytorch-sm30:latest python
```

```python
>>> import torch
>>> torch.__version__
'1.10.0a0'
>>> torch.cuda.get_device_capability()
(3, 0)
>>> torch.randn(5).cuda()
tensor([ 0.8824, -0.0490,  2.0234, -1.7939,  0.6414], device='cuda:0')
```

