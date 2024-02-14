#!/bin/bash

# Note:   Script to run llama.cpp experiments on jetson devices.
# Author: Stefanos Laskaridis (stefanos@brave.com)


MELT_PATH=${MELT_PATH:-"$PWD/../../"}
export LLAMA_CPP_HOME=${LLAMA_CPP_HOME:-"$MELT_PATH/frameworks/llama.cpp/llama.cpp"}
INPUT_PATH=${INPUT_PATH:-"$MELT_PATH/melt_models_converted/"}
INPUT_PROMPTS_FILENAME=${INPUT_PROMPTS_FILENAME:-"$MELT_PATH/src/prompts/conversations.json"}

# Execution parameters
LLAMACPP_MODELS=()
while IFS= read -r line; do
    LLAMACPP_MODELS+=("$line")
done < llamacpp_models.txt
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
TOP_P=${TOP_P:-0.95}
REPEAT_PENALTY=${REPEAT_PENALTY:-1.1}
INPUT_TOKEN_BATCHING=${INPUT_TOKEN_BATCHING:-1024}

CPU=${CPU:-"0"}
N_THREADS=${N_THREADS:-"8"}

# Energy measurement parameters
MEASURE_ENERGY=${MEASURE_ENERGY:-1}
JETSON_MONITOR_PATH=${JETSON_MONITOR_PATH:-"$MELT_PATH/jetsonlab/jetson-monitor"}
MONITOR_ITERATIONS=${MONITOR_ITERATIONS:-10000000}
DEVICE=${DEVICE:-"dummy"}
OUTPUT_PATH_ROOT=${OUTPUT_PATH_ROOT:-"${MELT_PATH}/jetsonlab/experiment_outputs/${DEVICE}/LlamaCpp/"}

cleanup() {
  echo "Caught SIGINT, killing child processes..."
  kill 0 # Kills all processes in the current process group
}

# Set trap to call cleanup function on SIGINT (Ctrl-C)
trap cleanup SIGINT

# Override models if model is passed
if [ ! -z $MODEL ]; then
    LLAMACPP_MODELS=("${MODEL}")
fi

for MODEL in ${LLAMACPP_MODELS[@]}; do
    OUTPUT_PATH="${OUTPUT_PATH_ROOT}/${APP}/${MODEL}/${EXPERIMENT_ID}/"
    EVENTS_FILENAME="${OUTPUT_PATH}/melt_measurements/measurements"
    model_config_path="$(dirname "${INPUT_PATH}/${MODEL}/")/llama_main_args.txt"
    if [ -d $OUTPUT_PATH ]; then
        echo "Output path already exists. Removing."
        rm -rf $OUTPUT_PATH
    fi
    mkdir -p $OUTPUT_PATH

    for run in $(seq 0 $(( REPETITIONS - 1 )));do
        echo "Running ${MODEL} on LlamaCpp on device ${DEVICE}, iteration ${run}."

        if [ $MEASURE_ENERGY -eq 1 ]; then
            pushd ${JETSON_MONITOR_PATH}/src
            (sudo python main.py \
                    --device ${DEVICE} \
                    --max-iterations ${MONITOR_ITERATIONS} &> ${OUTPUT_PATH}/energy_iter${run}.log) &
            MONITOR_PID=$!
            popd
            sleep 10
        fi

        pushd $LLAMA_CPP_HOME
        python $MELT_PATH/jetsonlab/src/edit_configs.py \
                --app LlamaCpp \
                --model-config-path $model_config_path \
                --logfile $OUTPUT_PATH/output.txt \
                --max-gen-len ${MAX_GEN_LEN} \
                --max-context-size ${MAX_CONTEXT_LEN} \
                --temperature ${TEMPERATURE} \
                --top-k ${TOP_K} \
                --top-p ${TOP_P} \
                --repeat-penalty ${REPEAT_PENALTY} \
                --input-token-batching ${INPUT_TOKEN_BATCHING}

        pushd run_scripts/
        ./run-llamacpp.sh jetson\
                          $INPUT_PATH \
                          $MODEL \
                          $INPUT_PROMPTS_FILENAME \
                          $CONVERSATION_FROM \
                          $CONVERSATION_TO \
                          $OUTPUT_PATH \
                          "${EVENTS_FILENAME}" \
                          $run \
                          $CPU \
                          ${N_THREADS}
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
