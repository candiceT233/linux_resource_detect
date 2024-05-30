#!/bin/bash

IterDecon_BIN=///qfs/people/tang584/scripts/linux_resource_detect/example_workflow/seismology-workflow/bin
EXP_DATA_PATH=/rcfs/projects/chess/$USER/seismic_data # BeeGFS
MSHOCK_DATA_PATH=$EXP_DATA_PATH/MShock
EGF_INPUT_PATH=$EXP_DATA_PATH/EGF

CONCURRENCY=$1 # test 5 10 20
INPUT_FILE_NUM=$2

# Check user input
if [ -z "$CONCURRENCY" ]; then
    echo "Usage: $0 <concurrency> <input_file_num>"
    exit 1
fi
readarray -t all_input_file < <(head -n $INPUT_FILE_NUM all_seismic_input.txt)
echo "Input files: ${all_input_file[@]}"
# all_input_file=( "b916-pb-_ldsp" "g43a-ta-_ldsp" "d27-xt-_ldsp" "nc05-xq-_ldsp" "q43a-ta-_ldsp" "ss64-xi-_ldsp" "enh-ic-00_ldsp" "ss72-xi-_ldsp" "maja-xv-_ldsp" "n02d-ta-_ldsp" "i55a-ta-_ldsp" "149a-ta-_ldsp" "bar-ci-_ldsp" "dac-lb-_ldsp" "d34-xt-_ldsp" "pats-ps-_ldsp" "tato-iu-10_ldsp" "gugu-xf-_ldsp" "b026-pb-_ldsp" "frb-cn-_ldsp")


PREPARE_INPUT_PATH(){
    echo "Copying input files to $EXP_DATA_PATH"
    cp -r /qfs/people/tang584/scripts/linux_resource_detect/example_workflow/seismology-workflow/input/* $EXP_DATA_PATH/
    # Check if folders are copied
    ls -l $EXP_DATA_PATH
}

mkdir -p $EXP_DATA_PATH
cd $EXP_DATA_PATH
# PREPARE_INPUT_PATH

# cleanup data
rm -rf $EXP_DATA_PATH/*.stf
rm -rf $EXP_DATA_PATH/*good-fit*

# record start time in milliseconds
time_1=$(($(date +%s%N)/1000000))
echo "Start sG1IterDcon --------------------------------"


num_files="${#all_input_file[@]}"

# Darshan Environment Variables
export DARSHAN_ENABLE_NONMPI=1
export DARSHAN_MOD_ENABLE="DXT_POSIX"
# export LD_PRELOAD=/qfs/people/tang584/install/darshan_runtime/lib/libdarshan.so io-test
# export DARSHAN_LOGHINTS="romio_no_indep_rw=true;cb_nodes=1"
export DXT_ENABLE_IO_TRACE=1



# for t in {1..$}; do
# for input_file in ${all_input_file[@]}; do
for ((i = 0; i < num_files; i++)); do
    input_file=${all_input_file[i]}
    mkdir run_$input_file
    cd run_$input_file

    echo "Running input ${input_file}"

    LD_PRELOAD=/qfs/people/tang584/install/darshan_runtime/lib/libdarshan.so \
        sh $IterDecon_BIN/sG1IterDecon $MSHOCK_DATA_PATH/${input_file} $EGF_INPUT_PATH/${input_file} &
    
    cd $EXP_DATA_PATH

    task_num=$(($i + 1))
    # check if wait is needed
    wait_for_jobs=$(($task_num % $CONCURRENCY))
    if [ $wait_for_jobs -eq 0 ]; then
        echo "Waiting for job ${t} to finish"
        wait
    fi
done

# Moving data
for ((i = 0; i < num_files; i++)); do
    input_file=${all_input_file[i]}
    cd run_$input_file

    # get input file prefix without ".lht"
    input_prefix=$(echo $input_file | cut -d'.' -f1)

    echo "Moving output to ${input_prefix}.lht_iter_g1.stf"
    mv _iter_g1.stf $EXP_DATA_PATH/${input_prefix}.lht_iter_g1.stf
    cd $EXP_DATA_PATH
    rm -rf run_$input_file
done

sudo /sbin/sysctl vm.drop_caches=3

time_2=$(($(date +%s%N)/1000000))

echo "Start siftSTFByMisfit.py --------------------------------"

# Get all .stf files in the directory #EXP_DATA_PATH into a string
file_str=$(realpath $EXP_DATA_PATH/* | grep ".stf" | tr '\n' ' ')
# echo "Files: $file_str"

set -x

LD_PRELOAD=/qfs/people/tang584/install/darshan_runtime/lib/libdarshan.so \
    python3 $IterDecon_BIN/siftSTFByMisfit.py $file_str
set +x

time_3=$(($(date +%s%N)/1000000))

# Calculate duration, convert milliseconds to seconds
echo "Duration sG1IterDcon: $((time_2-time_1)) ms [$(echo "scale=2; ($time_2-$time_1)/1000" | bc) sec]"
echo "Duration siftSTFByMisfit.py: $((time_3-time_2)) ms [$(echo "scale=2; ($time_3-$time_2)/1000" | bc) sec"

echo "End --------------------------------"

date
hostname

# Check if the output files are generated
set -x
# ls -l $EXP_DATA_PATH | grep ".stf" | wc -l
ls -l $EXP_DATA_PATH | grep "good-fit" | wc -l
du -k $EXP_DATA_PATH/*.stf

