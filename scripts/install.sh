#!/bin/bash

DP_ROOT=$(realpath $(dirname $0)/..)
DP_COMP_3DSMAPS=$DP_ROOT/components/3dsmaps
DP_COMP_SIM=$DP_ROOT/components/open-nav-sim


function ensure_success() {
    if [[ $? -ne 0 ]]; then
        echo "ERROR: Exception detected."
        exit 1;
    fi
}


cd $DP_ROOT

eval "$(conda shell.bash hook)"


# TODO: install
