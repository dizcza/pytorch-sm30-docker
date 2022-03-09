[![Docker Hub](http://dockeri.co/image/dizcza/pytorch-sm30)](https://hub.docker.com/r/dizcza/pytorch-sm30/)

# Pytorch Dockerfile for graphics cards capability 3.0

[![](https://img.shields.io/docker/image-size/dizcza/pytorch-sm30/latest?label=latest)](https://hub.docker.com/r/dizcza/pytorch-sm30/tags)

This Dockerfile serves the latest pytorch and torchvision for the sm\_30 NVIDIA architecture (compute capability 3.0).

CUDA 10.2 cuDNN 7.

## Usage

Pre-built images are served on the dockerhub. The builds are passing even though GitHub shows them as failed (in red) because of the timeout (it takes >3 hours to build the image).

```
docker run -it --gpus all dizcza/pytorch-sm30 python
```

```python
>>> import torch
>>> torch.__version__
'1.10.2'
>>> torch.cuda.get_device_capability()
(3, 0)
>>> torch.randn(5).cuda()
tensor([ 0.8824, -0.0490,  2.0234, -1.7939,  0.6414], device='cuda:0')
```

## Local build

```
docker build -t pytorch-sm30 .
```

Then

```
docker run -it --gpus all pytorch-sm30 python
```

