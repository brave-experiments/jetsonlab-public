#!/bin/bash

# Note:   Script to run mlc experiments on jetson devices.
# Author: Stefanos Laskaridis (stefanos@brave.com)


MELT_PATH=${MELT_PATH:-"$PWD/../../"}
export MLC_HOME=${MLC_HOME:-"$MELT_PATH/frameworks/MLC/mlc-llm"}
INPUT_PATH=${INPUT_PATH:-"$MELT_PATH/melt_models_converted/"}
INPUT_PROMPTS_FILENAME=${INPUT_PROMPTS_FILENAME:-"$MELT_PATH/src/prompts/conversations.json"}

# Execution parameters
MLC_MODELS=()
while IFS= read -r line; do
    MLC_MODELS+=("$line")
done < mlc_models.txt
BACKEND=${BACKEND:-"metal"}
REPETITIONS=${REPETITIONS:-3}
CONVERSATION_FROM=${CONVERSATION_FROM:-0}
CONVERSATION_TO=${CONVERSATION_TO:-3}

# Logging parameters
EXPERIMENT_ID=${EXPERIMENT_ID:-"$(date +%Y%m%d_%H%M%S)"}

# Model inference parameters
MAX_GEN_LEN=${MAX_GEN_LEN:-256}
MAX_CONTEXT_LEN=${MAX_CONTEXT_LEN:-2048}
TEMPERATURE=${TEMPERATURE:-0.9}
TOP_K=${TOP_K:-40}
# TOP_P=${TOP_P:-0.95}
REPEAT_PENALTY=${REPEAT_PENALTY:-1.1}
# INPUT_TOKEN_BATCHING=${INPUT_TOKEN_BATCHING:-128}

# Energy measurement parameters
MEASURE_ENERGY=${MEASURE_ENERGY:-1}
JETSON_MONITOR_PATH=${JETSON_MONITOR_PATH:-"$MELT_PATH/jetsonlab/jetson-monitor"}
MONITOR_ITERATIONS=${MONITOR_ITERATIONS:-10000000}
DEVICE=${DEVICE:-"dummy"}

OUTPUT_PATH_ROOT=${OUTPUT_PATH_ROOT:-"${MELT_PATH}/jetsonlab/experiment_outputs/${DEVICE}/MLCChat/"}

cleanup() {
  echo "Caught SIGINT, killing child processes..."
  kill 0 # Kills all processes in the current process group
}

# Set trap to call cleanup function on SIGINT (Ctrl-C)
trap cleanup SIGINT

# Override models if model is passed
if [ ! -z $MODEL ]; then
    MLC_MODELS=("${MODEL}")
fi

echo $MLC_MODELS

for MODEL in ${MLC_MODELS[@]}; do
    OUTPUT_PATH="${OUTPUT_PATH_ROOT}/${APP}/${MODEL}/${EXPERIMENT_ID}/"
    EVENTS_FILENAME="${OUTPUT_PATH}/melt_measurements/measurements"
    MODEL_PATH="${INPUT_PATH}/${MODEL}"
    MODEL_PARAMS_PATH="${MODEL_PATH}/params"
    MODEL_LIB_PATH="${MODEL_PATH}/${MODEL}-${BACKEND}.so"
    MODEL_CONFIG_PATH="${MODEL_PARAMS_PATH}/mlc-chat-config.json"

    if [ -d $OUTPUT_PATH ]; then
        echo "Output path already exists. Removing."
        rm -rf $OUTPUT_PATH
    fi
    mkdir -p $OUTPUT_PATH

    for run in $(seq 0 $(( REPETITIONS - 1 )));do
        echo "Running ${MODEL} on MLC on device ${DEVICE}, iteration ${run}."
        if [ $MEASURE_ENERGY -eq 1 ]; then
            pushd ${JETSON_MONITOR_PATH}/src
            (sudo python main.py \
                    --device ${DEVICE} \
                    --max-iterations ${MONITOR_ITERATIONS}  &> ${OUTPUT_PATH}/energy_iter${run}.log) &
            MONITOR_PID=$!
            popd
            sleep 10
        fi

        pushd $MLC_HOME
        python $MELT_PATH/jetsonlab/src/edit_configs.py \
                --app MLCChat \
                --model-config-path $MODEL_CONFIG_PATH \
                --logfile $OUTPUT_PATH/output.txt \
                --max-gen-len ${MAX_GEN_LEN} \
                --max-context-size ${MAX_CONTEXT_LEN} \
                --temperature ${TEMPERATURE} \
                --top-k ${TOP_K} \
                --repeat-penalty ${REPEAT_PENALTY} \

        pushd run_scripts/
        ./run-mlc.sh \
                $MODEL_PARAMS_PATH \
                $MODEL_LIB_PATH \
                $INPUT_PROMPTS_FILENAME \
                $CONVERSATION_FROM \
                $CONVERSATION_TO \
                $OUTPUT_PATH \
                "${EVENTS_FILENAME}" \
                $run
        popd
        popd

        if [ $MEASURE_ENERGY -eq 1 ]; then
            if [ ! -z "${MONITOR_PID}" ]; then
                sudo kill $MONITOR_PID
            else
                echo "Energy measurement was not started!"
            fi
        fi

    done
done
