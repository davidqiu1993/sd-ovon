#!/bin/bash

DP_ROOT=$(realpath $(dirname $0)/..)
DP_DATA=$DP_ROOT/data
DP_SCRIPTS=$DP_ROOT/scripts
DP_EXPORT=$DP_DATA/export
DP_ARTIFACTS=$DP_DATA/artifacts
DP_ARTIFACTS_OBS=$DP_ARTIFACTS/observations
DP_ARTIFACTS_OBS_STD=$DP_ARTIFACTS/observations_std
DP_ARTIFACTS_INSTEXT=$DP_ARTIFACTS/instance_extraction
DP_ARTIFACTS_SSLAM=$DP_ARTIFACTS/semantic_slam
DP_ARTIFACTS_SREL=$DP_ARTIFACTS/semantic_relating
DP_ARTIFACTS_INSTFUSION=$DP_ARTIFACTS/instance_fusion
DP_ARTIFACTS_OBJPLC=$DP_ARTIFACTS/object_placement
DP_ARTIFACTS_OBJ_INSTS=$DP_ARTIFACTS/object_instances
DP_COMP_3DSMAPS=$DP_ROOT/components/3dsmaps
DP_COMP_SIM=$DP_ROOT/components/open-nav-sim
DP_COMP_INSTFUSION=$DP_ROOT/components/instance-fusion

TASK_ID=$(date +"%Y%m%d_%H%M%S_%6N")
RECEPTABLE_CLASSES="table desk dresser bookshelf shelf bed sofa couch"  # chair armchair stool
NEGATIVE_CLASSES="sky building *room *office basement corridor floor wall corner ceiling furniture dark"
FP_SCENE=""
PLACE_OBJECTS=10
PLACEMENT_VARIATIONS=10
DP_OBJECTS=$DP_DATA/sd-ovon/objects
GRAVITY_DIRECTION="-z"
OLLAMA_HOST="http://localhost:11434"

dataset_name=""


function ensure_success() {
    if [[ $? -ne 0 ]]; then
        echo ""
        echo "ERROR: Exception detected. (TASK_ID: $TASK_ID, FP_SCENE: $FP_SCENE, dataset_name: $dataset_name)"
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

        -po|--place-objects)
            # number of objects to place
            PLACE_OBJECTS="$2"
            shift 2
            ;;

        -pv|--placement-variations)
            # number of placement variations
            PLACEMENT_VARIATIONS="$2"
            shift 2
            ;;

        -o|--objects)
            # path to objects datasets directory
            DP_OBJECTS="$2"
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

        -t|--task-id)
            # task id
            TASK_ID="$2"
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

echo "TASK_ID: $TASK_ID"

# activate conda environment
eval "$(conda shell.bash hook)"
conda activate sd-ovon
ensure_success
conda env list


# habitat: prepare dataset export directories
rm -r $DP_EXPORT/data
mkdir -p $DP_EXPORT/data/scene_datasets/sd-ovon/stages
mkdir -p $DP_EXPORT/data/scene_datasets/sd-ovon/stages_data
# mkdir -p $DP_EXPORT/data/scene_datasets/sd-ovon/objects  # will be generated
mkdir -p $DP_EXPORT/data/scene_datasets/sd-ovon/object_instances
mkdir -p $DP_EXPORT/data/scene_datasets/sd-ovon/scenes  # generate by dataset config generator
mkdir -p $DP_EXPORT/data/datasets/objectnav/sd-ovon  # generate by episode generator

# habitat: export stages data
if [[ ! -d $DP_EXPORT/data/scene_datasets/sd-ovon/stages/$(basename $(dirname $FP_SCENE)) ]]; then
    cp -r $(dirname $FP_SCENE) $DP_EXPORT/data/scene_datasets/sd-ovon/stages_data
    ensure_success
    echo "Exported stages to habitat dataset: \"$DP_EXPORT/data/scene_datasets/sd-ovon/stages_data\""
fi

# habitat: export objects
if [[ ! -d $DP_EXPORT/data/scene_datasets/sd-ovon/objects ]]; then
    cp -r $DP_OBJECTS $DP_EXPORT/data/scene_datasets/sd-ovon/objects
    ensure_success
    rm $DP_EXPORT/data/scene_datasets/sd-ovon/objects/sdovon_object_dataset.scene_dataset_config.json
    ensure_success
    echo "Exported objects to habitat dataset: \"$DP_EXPORT/data/scene_datasets/sd-ovon/objects\""
fi

# sample observations
mkdir -p $DP_ARTIFACTS_OBS
ensure_success
obs_task_prefix="$TASK_ID"
if ls "$DP_ARTIFACTS_OBS"/"${obs_task_prefix}"* 1> /dev/null 2>&1; then
    echo "Observations dataset already exists:"
    ls "$DP_ARTIFACTS_OBS"/"${obs_task_prefix}"*
else
    python $DP_COMP_SIM/src/observation_sampling.py \
        --fp_scene $FP_SCENE \
        --dp_artifacts $DP_ARTIFACTS_OBS \
        --task_prefix $obs_task_prefix
    ensure_success
fi

# loop for each floor
dp_obs_floors=`find "$DP_ARTIFACTS_OBS" -type d -name "${obs_task_prefix}*"`
for dp_obs_floor in $dp_obs_floors; do
    dirname_obs_floor=`basename $dp_obs_floor`
    echo "Processing: \"$dirname_obs_floor\".."

    # activate 3dsmaps virtual environment
    conda deactivate
    ensure_success
    source $DP_COMP_3DSMAPS/env/bin/activate
    ensure_success

    # standardize observations dataset
    mkdir -p $DP_ARTIFACTS_OBS_STD
    ensure_success
    dataset_name="`basename $dp_obs_floor`"
    dp_obs_floor_std="$DP_ARTIFACTS_OBS_STD""/""$dataset_name"
    if [[ ! -d $dp_obs_floor_std ]]; then
        python $DP_COMP_3DSMAPS/src/datasets.py \
            --format habitat \
            --input $dp_obs_floor \
            --output $dp_obs_floor_std
        ensure_success
    else
        echo "Standardized observations dataset already exists: \"$dp_obs_floor_std\"."
    fi

    # extract instances
    # mkdir -p $DP_ARTIFACTS_INSTEXT
    # ensure_success
    # python $DP_COMP_3DSMAPS/src/instance_extraction.py \
    #     --dataset $dp_obs_floor_std \
    #     --artifacts $DP_ARTIFACTS_INSTEXT \
    #     --negative-classes $NEGATIVE_CLASSES
    # ensure_success

    # semantic slam
    mkdir -p $DP_ARTIFACTS_SSLAM
    ensure_success
    python $DP_COMP_3DSMAPS/src/semantic_slam.py \
        --dataset="$DP_ARTIFACTS_INSTEXT""/""$dataset_name" \
        --artifacts="$DP_ARTIFACTS_SSLAM" \
        --gravity-direction="$GRAVITY_DIRECTION" \
        --ollama="$OLLAMA_HOST"
    ensure_success

    # semantic relating
    mkdir -p $DP_ARTIFACTS_SREL
    ensure_success
    python $DP_COMP_3DSMAPS/src/semantic_relating.py \
        --region-grids "$DP_ARTIFACTS_SSLAM""/""$dataset_name" \
        --objects "$DP_OBJECTS" \
        --artifacts "$DP_ARTIFACTS_SREL" \
        --ollama "$OLLAMA_HOST"
    ensure_success

    # activate instance fusion virtual environment
    deactivate
    ensure_success
    source $DP_COMP_INSTFUSION/env/bin/activate
    ensure_success

    # instance fusion
    dp_inst_fusion="$DP_ARTIFACTS_INSTFUSION""/""$dataset_name"
    if [[ ! -d "$dp_inst_fusion" ]]; then
        python $DP_COMP_INSTFUSION/cfslam_pipeline_batch.py \
            --dataset "$DP_ARTIFACTS_INSTEXT""/""$dataset_name" \
            --save "$dp_inst_fusion" \
            --classes $RECEPTABLE_CLASSES
        ensure_success
    else
        echo "Instance fusion artifacts already exists: \"$dp_inst_fusion\"."
    fi

    # extract planes
    for rcpt_cls in $RECEPTABLE_CLASSES; do
        if [[ ! -f "$dp_inst_fusion""/planes/""$rcpt_cls"".pkl" ]]; then
            python $DP_COMP_INSTFUSION/extract_planes_EM.py \
                --dp_data "$dp_inst_fusion" \
                --obs_meta "$DP_ARTIFACTS_OBS""/""$dataset_name""/meta.json" \
                --class_name "$rcpt_cls"
            ensure_success
        fi
    done

    # activate conda environment
    deactivate
    ensure_success
    conda activate sd-ovon
    ensure_success

    # generate object placements
    if [[ ! -d "$DP_ARTIFACTS_OBJPLC""/""$dataset_name" ]]; then
        python $DP_COMP_SIM/src/dynamic_scene_gen.py \
            --objects "$DP_OBJECTS" \
            --region-grids "$DP_ARTIFACTS_SSLAM""/""$dataset_name" \
            --semantic-relevances "$DP_ARTIFACTS_SREL""/""$dataset_name" \
            --planes "$DP_ARTIFACTS_INSTFUSION""/""$dataset_name""/planes" \
            --save "$DP_ARTIFACTS_OBJPLC""/""$dataset_name" \
            --place-objects $PLACE_OBJECTS \
            --placement-variants $PLACEMENT_VARIATIONS
        ensure_success
    else
        echo "Object placement descriptions directory already exist: \"$DP_ARTIFACTS_OBJPLC""/""$dataset_name\"."
    fi

    # place objects and generate object instances files
    mkdir -p $DP_EXPORT
    if [[ ! -d "$DP_ARTIFACTS_OBJ_INSTS""/""$dataset_name" ]]; then
        for fp_placement_desc in "$DP_ARTIFACTS_OBJPLC""/""$dataset_name"/*; do
            python $DP_COMP_SIM/src/object_placement.py \
                --fp_scene $FP_SCENE \
                --dp_objects "$DP_OBJECTS" \
                --fp_object_placement_description "$fp_placement_desc" \
                --output_dir "$DP_ARTIFACTS_OBJ_INSTS""/""$dataset_name"
            ensure_success
        done
    else
        echo "Object instances directory already exist: \"$DP_ARTIFACTS_OBJ_INSTS""/""$dataset_name\"."
    fi

    # habitat: create soft links for stages
    for fp_obj_insts in "$DP_ARTIFACTS_OBJ_INSTS""/""$dataset_name"/*; do
        fname_obj_insts=$(basename $fp_obj_insts)
        placement_scene_name="${fname_obj_insts:0:${#fname_obj_insts}-22}"
        placement_scene_dir_name=$(basename $(dirname $FP_SCENE))"_"${placement_scene_name:${#placement_scene_name}-4:${#placement_scene_name}}

        original_scene_file_name=$(basename $FP_SCENE)
        original_scene_name=${original_scene_file_name%%.*}
        original_scene_dir_name=$(basename $(dirname $FP_SCENE))

        rm -r $DP_EXPORT/data/scene_datasets/sd-ovon/stages/$placement_scene_dir_name
        mkdir $DP_EXPORT/data/scene_datasets/sd-ovon/stages/$placement_scene_dir_name
        ensure_success

        cd $DP_EXPORT/data/scene_datasets/sd-ovon/stages/$placement_scene_dir_name
        ensure_success

        ln -s ../../stages_data/$original_scene_dir_name/$original_scene_name".basis.glb" \
            $placement_scene_name".basis.glb"
        ensure_success
        ln -s ../../stages_data/$original_scene_dir_name/$original_scene_name".basis.navmesh" \
            $placement_scene_name".basis.navmesh"
        ensure_success

        cd -
        ensure_success

        echo "Created soft link for stage: $original_scene_name -> $placement_scene_name"
    done

    # habitat: export object instances files
    cp "$DP_ARTIFACTS_OBJ_INSTS""/""$dataset_name"/* $DP_EXPORT/data/scene_datasets/sd-ovon/object_instances
    ensure_success
    echo "Exported object instances files to habitat dataset: \"$DP_EXPORT/data/scene_datasets/sd-ovon/object_instances\""

    # generate scene instances
    bash $DP_SCRIPTS/generate_scene_instances.sh

    # configure episode generator
    bash $DP_SCRIPTS/configure_episode_generator.sh

    # generate episode dataset
    cd $DP_EXPORT
    for fp_obj_insts in "$DP_ARTIFACTS_OBJ_INSTS""/""$dataset_name"/*; do
        fname_obj_insts=$(basename $fp_obj_insts)
        scene_name="${fname_obj_insts:0:${#fname_obj_insts}-22}"
        python $DP_EXPORT/dataset_gen.py \
            --output_dir $DP_EXPORT/data/datasets/objectnav/sd-ovon/val/content \
            --scene_id $scene_name \
            --fp_goal_cat $DP_EXPORT/episode_gen/data/dataset_config/semantic_id_mapping_cat_153.json \
            --fp_object_categories $DP_EXPORT/episode_gen/data/dataset_config/sd-ovon.object_categories.json \
            --dp_object_configs $DP_EXPORT/data/scene_datasets/sd-ovon/objects/configs \
            --dp_scene_instances $DP_EXPORT/data/scene_datasets/sd-ovon/scenes
        ensure_success
    done
    cd -

done
