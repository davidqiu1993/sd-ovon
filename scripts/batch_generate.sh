#!/bin/bash

DP_ROOT=$(realpath $(dirname $0)/..)
DP_DATA=$DP_ROOT/data

DP_SCENES=""
DP_OBJECTS=""
DATASET_TYPE=""
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
        -s|--scenes)
            # path to scenes dataset directory
            DP_SCENES="$2"
            shift 2
            ;;

        -o|--objects)
            # path to objects datasets directory
            DP_OBJECTS="$2"
            shift 2
            ;;

        -t|--dataset-type)
            # dataset type
            DATASET_TYPE="$2"
            shift 2
            ;;

        -llm|--ollama|--ollama-host)
            # ollama host
            OLLAMA_HOST="$2"
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
if [[ "" == "$DP_SCENES" ]]; then
    echo "ERROR: Missing required argument \"-s\" or \"--scenes\".."
    exit 1
fi

if [[ "" == "$DP_OBJECTS" ]]; then
    echo "ERROR: Missing required argument \"-o\" or \"--objects\".."
    exit 1
fi

if [[ "" == "$DATASET_TYPE" ]]; then
    echo "ERROR: Missing required argument \"-t\" or \"--dataset-type\".."
    exit 1
fi


# prepare runtime environment
cd $DP_ROOT


# collect glb files
fp_glb_files=()
task_id_postfixes=()
gravity_direction="-z"
for item in $DP_SCENES/*; do
    case $DATASET_TYPE in
        "habitat-test-scenes")
            fp_glb_file="$item"
            if [[ "$fp_glb_file" == *".glb" ]] && [[ -f $fp_glb_file ]]; then
                fp_glb_files+=("$fp_glb_file")
                fname_glb_file=$(basename $fp_glb_file)
                task_id_postfixes+=(${fname_glb_file%".glb"})
            fi
            gravity_direction="-z"
            ;;

        "hm3d")
            dataset_name=$(basename "$item" | cut -d'-' -f2-)
            dp_dataset=$item
            fp_glb_file="$dp_dataset""/""$dataset_name"".basis.glb"
            if [[ -d $dp_dataset ]] && [[ -f $fp_glb_file ]]; then
                fp_glb_files+=("$fp_glb_file")
                fname_glb_file=$(basename $fp_glb_file)
                task_id_postfixes+=(${fname_glb_file%".basis.glb"})
            fi
            gravity_direction="-z"
            ;;

        "mp3d")
            dataset_name=$(basename "$item")
            dp_dataset=$item
            fp_glb_file="$dp_dataset""/""$dataset_name"".glb"
            if [[ -d $dp_dataset ]] && [[ -f $fp_glb_file ]]; then
                fp_glb_files+=("$fp_glb_file")
                fname_glb_file=$(basename $fp_glb_file)
                task_id_postfixes+=(${fname_glb_file%".glb"})
            fi
            ;;

        *)
            echo "Invalide dataset type: \"$DATASET_TYPE\".."
            exit 1
            ;;
    esac
done

# loop for glb files to generate
for ((i=0; i<${#fp_glb_files[@]}; i++)); do
    fp_glb_file=${fp_glb_files[i]}
    task_id="$DATASET_TYPE"".""${task_id_postfixes[i]}"

    echo "Generating with scene.."
    echo "  - task id: $task_id"
    echo "  - scene: $fp_glb_file"
    echo "  - dataset type: $DATASET_TYPE"
    echo ""

    bash $(dirname $0)/generate.sh \
        --scene "$fp_glb_file" \
        --objects "$DP_OBJECTS" \
        --gravity-direction "$gravity_direction" \
        --ollama-host "$OLLAMA_HOST" \
        --task-id "$task_id"
    ensure_success

    echo ""
done
