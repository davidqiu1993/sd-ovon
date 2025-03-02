#!/bin/bash

DP_ROOT=$(realpath $(dirname $0)/..)
DP_DATA=$DP_ROOT/data
DP_EXPORT=$DP_DATA/export
DP_COMP_SIM=$DP_ROOT/components/open-nav-sim


function ensure_success() {
    if [[ $? -ne 0 ]]; then
        echo "ERROR: Exception detected."
        exit 1;
    fi
}


# prepare runtime environment
cd $DP_ROOT

# activate conda environment
eval "$(conda shell.bash hook)"
conda activate sd-ovon
ensure_success
conda env list


# copy util files
cp $DP_COMP_SIM/src/dataset_generators/dataset_config_generator.py $DP_EXPORT/data
ensure_success
cp $DP_COMP_SIM/src/dataset_generators/template.json $DP_EXPORT/data
ensure_success

# generate scene instances
cd $DP_EXPORT/data
ensure_success
python dataset_config_generator.py
ensure_success

# remove lagacy files
rm $DP_EXPORT/data/dataset_config_generator.py
ensure_success
rm $DP_EXPORT/data/template.json
ensure_success

echo "Scene instances generated with success.."
