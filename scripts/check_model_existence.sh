#!/bin/bash

MELT_PATH=${MELT_PATH:-"$PWD/../../"}
INPUT_PATH=${INPUT_PATH:-"$MELT_PATH/melt_models_converted/"}

LLAMACPP_MODELS=()
while IFS= read -r line; do
    LLAMACPP_MODELS+=("$line")
done < llamacpp_models.txt

MLC_MODELS=()
while IFS= read -r line; do
    MLC_MODELS+=("$line")
done < mlc_models.txt

MODELS=("${LLAMACPP_MODELS[@]}" "${MLC_MODELS[@]}")

for MODEL in ${MODELS[@]}; do
    if [ ! -d $INPUT_PATH/$MODEL ] && [ ! -e $INPUT_PATH/$MODEL ]; then
        echo "* Model $MODEL does not exist in $INPUT_PATH/$MODEL."
    fi
done