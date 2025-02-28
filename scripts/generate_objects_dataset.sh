#!/bin/bash

DP_ROOT=$(realpath $(dirname $0)/..)
DP_DATA=$DP_ROOT/data
DP_EXPORT=$DP_ROOT/data/sd-ovon
DP_COMP_SIM=$DP_ROOT/components/open-nav-sim

DP_OBJECTS=$DP_ROOT/data/habitat/objects_datasets
SHALL_OVERWRITE=false


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
        -o|--objects)
            # path to objects datasets directory
            DP_OBJECTS="$2"
            shift 2
            ;;
        
        --overwrite)
            # overwrite existing files
            SHALL_OVERWRITE=true
            shift 1
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

# prepare runtime environment
cd $DP_ROOT


# remove existing files
if [[ -d $DP_EXPORT/objects ]]; then
    if [[ $SHALL_OVERWRITE == true ]]; then
        rm -r $DP_EXPORT/objects
    else
        echo "ERROR: Dataset directory already exists. (dp_dataset: \"$DP_EXPORT/objects\")."
        echo "Use \"--overwrite\" to overwrite existing files."
        exit 1
    fi
fi

# activate conda environment
eval "$(conda shell.bash hook)"
conda activate sd-ovon
ensure_success
conda env list

# generate objects dataset
mkdir -p $DP_EXPORT/objects
ensure_success
python $DP_COMP_SIM/src/dataset.py \
    --objects $DP_OBJECTS \
    --save $DP_EXPORT/objects \
    --name sdovon_object_dataset \
    --force-flat-shading
ensure_success
