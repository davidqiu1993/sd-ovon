#!/bin/bash

DP_ROOT=$(realpath $(dirname $0)/..)
DP_DATA=$DP_ROOT/data
DP_ARTIFACTS=$DP_DATA/artifacts
DP_ARTIFACTS_OBS=$DP_ARTIFACTS/observations
DP_ARTIFACTS_OBS_STD=$DP_ARTIFACTS/observations_std
DP_ARTIFACTS_INSTEXT=$DP_ARTIFACTS/instance_extraction
DP_ARTIFACTS_SSLAM=$DP_ARTIFACTS/semantic_slam
DP_COMP_3DSMAPS=$DP_ROOT/components/3dsmaps
DP_COMP_SIM=$DP_ROOT/components/open-nav-sim

TASK_TIMESTAMP=$(date +"%Y%m%d_%H%M%S_%6N")
INSTEXT_CLASSES="table desk chair sofa"
FP_SCENE=""
GRAVITY_DIRECTION="-z"
OLLAMA_HOST="http://localhost:11434"


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
        -s|--scene)
            # path to scene file
            FP_SCENE="$2"
            shift 2
            ;;

        -gdir|--gravity-direction)
            # gravity direction
            GRAVITY_DIRECTION="$2"
            shift 2
            ;;

        -llm|--ollama|--ollama-host)
            # ollama host
            OLLAMA_HOST="$2"
            shift 2
            ;;

        -t|--timestamp)
            # task timestamp
            TASK_TIMESTAMP="$2"
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

echo "TASK_TIMESTAMP: $TASK_TIMESTAMP"

# activate conda environment
eval "$(conda shell.bash hook)"
conda activate sd-ovon
ensure_success
conda env list


# sample observations
mkdir -p $DP_ARTIFACTS_OBS
ensure_success
obs_task_prefix="obs.$TASK_TIMESTAMP"
# python $DP_COMP_SIM/src/observation_sampling.py \
#     --fp_scene $FP_SCENE \
#     --dp_artifacts $DP_ARTIFACTS_OBS \
#     --task_prefix $obs_task_prefix
# ensure_success

# loop for each floor
dp_obs_floors=`find "$DP_ARTIFACTS_OBS" -type d -name "${obs_task_prefix}*"`
for dp_obs_floor in $dp_obs_floors; do
    dirname_obs_floor=`basename $dp_obs_floor`
    echo "Processing: \"$dirname_obs_floor\".."

    # use 3dsmaps virtual environment
    conda deactivate
    ensure_success
    source $DP_COMP_3DSMAPS/env/bin/activate
    ensure_success

    # standardize observations dataset
    mkdir -p $DP_ARTIFACTS_OBS_STD
    ensure_success
    dataset_name="`basename $dp_obs_floor`"".std"
    # python $DP_COMP_3DSMAPS/src/datasets.py \
    #     --format habitat \
    #     --input $dp_obs_floor \
    #     --output "$DP_ARTIFACTS_OBS_STD""/""$dataset_name"
    # ensure_success

    # extract instances
    mkdir -p $DP_ARTIFACTS_INSTEXT
    ensure_success
    python $DP_COMP_3DSMAPS/src/instance_extraction.py \
        --dataset "$DP_ARTIFACTS_OBS_STD""/""$dataset_name" \
        --artifacts "$DP_ARTIFACTS_INSTEXT" \
        --classes $INSTEXT_CLASSES
    ensure_success

    # semantic slam
    mkdir -p $DP_ARTIFACTS_SSLAM
    ensure_success
    python $DP_COMP_3DSMAPS/src/semantic_slam.py \
        --dataset="$DP_ARTIFACTS_INSTEXT""/""$dataset_name" \
        --artifacts="$DP_ARTIFACTS_SSLAM" \
        --gravity-direction="$GRAVITY_DIRECTION" \
        --ollama="$OLLAMA_HOST"
    ensure_success

done
