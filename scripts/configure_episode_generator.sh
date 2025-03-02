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


if [[ ! -d $DP_EXPORT/episode_gen ]]; then
    cd $DP_EXPORT
    ln -s $DP_COMP_SIM/episode_generator/episode_gen episode_gen
    cd -
fi

if [[ ! -d $DP_EXPORT/objectnav_gen ]]; then
    cd $DP_EXPORT
    ln -s $DP_COMP_SIM/episode_generator/objectnav_gen objectnav_gen
    cd -
fi

if [[ ! -f $DP_EXPORT/dataset_gen.py ]]; then
    cd $DP_EXPORT
    ln -s $DP_COMP_SIM/episode_generator/dataset_gen.py dataset_gen.py
    cd -
fi

if [[ ! -f $DP_COMP_SIM/third-party/habitat-lab/habitat-lab/habitat/config/benchmark/nav/objectnav/objectnav_sd-ovon_with_semantic.yaml ]]; then
    cp $DP_COMP_SIM/episode_generator/episode_gen/data/dataset_config/objectnav_sd-ovon_with_semantic.yaml \
        $DP_COMP_SIM/third-party/habitat-lab/habitat-lab/habitat/config/benchmark/nav/objectnav
    ensure_success
fi
