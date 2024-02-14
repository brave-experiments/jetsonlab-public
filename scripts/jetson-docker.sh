#!/bin/bash

# Note:   Script to run dustynv's containers. Link: https://github.com/dusty-nv/jetson-containers/tree/master
# Author: Stefanos Laskaridis (stefanos@brave.com)

# Old codebase
# sudo docker run --runtime nvidia -it --network=host --name jetson_docker_mlc_old -v /media/jetson/ssd/melt/:/tmp/melt dustynv/mlc:3feed05-r36.2.0 /bin/bash

# New codebase
sudo docker run --runtime nvidia -it --network=host --name jetson_docker_mlc_new -v /media/jetson/ssd/melt/:/tmp/melt dustynv/mlc:607dc5a-r36.2.0 /bin/bash