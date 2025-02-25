#!/bin/bash

DP_ROOT=$(realpath $(dirname $0)/..)
DP_DATA=$DP_ROOT/data
DP_SIM_ARTIFACTS=$DP_DATA/sim/artifacts
DP_COMP_3DSMAPS=$DP_ROOT/components/3dsmaps
DP_COMP_SIM=$DP_ROOT/components/open-nav-sim

FP_SCENE=""


function ensure_success() {
    if [[ $? -ne 0 ]]; then
        echo "ERROR: Exception detected."
        exit 1;
    fi
}


# parse parameters
PARAMS=""
while (( "$#" )); do
  case "$1" in
    -s|--scene) # path to scene file
      FP_SCENE="$2"
      shift 2
      ;;

    --) # end argument parsing
      shift
      break
      ;;

    -*|--*=) # unsupported flags
      echo "Error: Unsupported flag $1" >&2
      exit 1
      ;;

    *) # preserve positional arguments
      PARAMS="$PARAMS $1"
      shift
      ;;
  esac
done

# set positional arguments in their proper place
eval set -- "$PARAMS"

# check parameters
if [[ "" == "$FP_SCENE" ]]; then
  echo "ERROR: Missing required argument \"-s\" or \"--scene\".."
  exit 1
fi


# prepare runtime environment
cd $DP_ROOT

# activate conda environment
eval "$(conda shell.bash hook)"
conda activate sd-ovon
ensure_success
conda env list


# sample observations
mkdir -p $DP_SIM_ARTIFACTS
ensure_success

python $DP_COMP_SIM/src/observation_sampling.py \
    --fp_scene $FP_SCENE \
    --dp_save $DP_SIM_ARTIFACTS
ensure_success
