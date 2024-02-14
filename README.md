# JetsonLab


[BLADE](https://github.com/brave-experiments/blade-public) for Nvidia Jetson devices.

## Devices

* Jetson Orin AGX
* Jetson Orin Nano

## Structure

```bash
├── scripts/
│   ├── check_model_existence.sh  # Script that checks that all models exist locally
│   ├── jetson-docker.sh          # Launch dustynv's docker images for MLC execution
│   ├── llamacpp_models.txt       # llama.cpp models to run
│   ├── mlc_models.txt            # MLC models to run
│   ├── run_llamacpp.sh           # Script for automated llama.cpp execution.
│   └── run_mlc.sh                # Script for automated MLC execution.
└── src/
    ├── edit_configs.py           # Args conversion based on model config. It is invoked by scripts/run_{llamacpp,mlc}.sh
    ├── report_performance.py     # Output parsing. It is invoked by parse_jetson_runs.sh
```

## How to run experiments

1. Checkout the MELT repo and its on jetson device.

```bash
git clone git@github.com/brave-experiments/melt --recursive
```

2. For MLC, launch [dustynv](https://github.com/dusty-nv/jetson-containers/tree/master)'s docker container from `./scripts/jetson-docker.sh`. For llama.cpp, skip this step (or pass the respective library paths).
3. Build on device, based on instructions from `frameworks/*/*/build_scripts/`
4. Edit the models you want to execute in `scripts/{llamacpp,mlc}_models.txt`.
5. Execute by running the following commands:


```bash
REPETITIONS=3 CONVERSATION_FROM=0 CONVERSATION_TO=5 MEASURE_ENERGY=1 DEVICE="orin_xx" ./run_mlc.sh
REPETITIONS=3 CONVERSATION_FROM=0 CONVERSATION_TO=5 MEASURE_ENERGY=1 DEVICE="orin_xx" ./run_llamacp.sh
```
6. After the experiments are done, you can run the notebook `notebooks/parse_jetson_runs.ipynb` to plot the results.