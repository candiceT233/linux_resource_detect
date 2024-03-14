#!/bin/bash

IterDecon_BIN=///qfs/people/tang584/scripts/linux_resource_detect/example_workflow/seismology-workflow/bin
EXP_DATA_PATH=///scratch/$USER/seismic_data # Local SSD
MSHOCK_DATA_PATH=$EXP_DATA_PATH/MShock
EGF_INPUT_PATH=$EXP_DATA_PATH/EGF

CONCURRENCY=$1 # test 5 10 20
INPUT_FILE_NUM=$2

# Check user input
if [ -z "$CONCURRENCY" ]; then
    echo "Usage: $0 <concurrency> <input_file_num>"
    exit 1
fi

mkdir -p $EXP_DATA_PATH
cd $EXP_DATA_PATH

# cleanup data
rm -rf $EXP_DATA_PATH/*.stf
rm -rf $EXP_DATA_PATH/*good-fit*

# record start time in milliseconds
time_1=$(($(date +%s%N)/1000000))
echo "Start sG1IterDcon --------------------------------"

readarray -t all_input_prefix < <(head -n $INPUT_FILE_NUM all_seismic_input.txt)
# echo ${all_input_prefix[@]}

# all_input_prefix=( "b916-pb-_ldsp" "g43a-ta-_ldsp" "d27-xt-_ldsp" "nc05-xq-_ldsp" "q43a-ta-_ldsp" "ss64-xi-_ldsp" "enh-ic-00_ldsp" "ss72-xi-_ldsp" "maja-xv-_ldsp" "n02d-ta-_ldsp" "i55a-ta-_ldsp" "149a-ta-_ldsp" "bar-ci-_ldsp" "dac-lb-_ldsp" "d34-xt-_ldsp" "pats-ps-_ldsp" "tato-iu-10_ldsp" "gugu-xf-_ldsp" "b026-pb-_ldsp" "frb-cn-_ldsp")

num_files="${#all_input_prefix[@]}"

for t in {1..${num_files}}; do
    input_prefix=${all_input_prefix[$t-1]}

    echo "Running input ${input_prefix}"
    mkdir run$t
    cd run$t
    sh $IterDecon_BIN/sG1IterDecon $MSHOCK_DATA_PATH/${input_prefix}.lht $EGF_INPUT_PATH/${input_prefix}.lht &
    
    cd $EXP_DATA_PATH

    # check if wait is needed
    wait_for_jobs=$(($t % $CONCURRENCY))
    if [ $wait_for_jobs -eq 0 ]; then
        echo "Waiting for job ${t} to finish"
        wait
    fi
done

# Moving data
for t in {1..20}; do
    input_prefix=${all_input_prefix[$t-1]}\
    echo "Moving output to ${input_prefix}.lht_iter_g1.stf"
    cd run$t
    mv _iter_g1.stf $EXP_DATA_PATH/${input_prefix}.lht_iter_g1.stf
    cd $EXP_DATA_PATH
done


time_2=$(($(date +%s%N)/1000000))

echo "Start siftSTFByMisfit.py --------------------------------"

# Get all .stf files in the directory #EXP_DATA_PATH into a string
file_str=$(ls $EXP_DATA_PATH | grep ".stf" | tr '\n' ' ')
echo "Files: $file_str"

python $IterDecon_BIN/siftSTFByMisfit.py $file_str


time_3=$(($(date +%s%N)/1000000))

# Calculate duration, convert milliseconds to seconds
echo "Duration sG1IterDcon: $((time_2-time_1)) ms [$(echo "scale=2; ($time_2-$time_1)/1000" | bc) sec]"
echo "Duration siftSTFByMisfit.py: $((time_3-time_2)) ms [$(echo "scale=2; ($time_3-$time_2)/1000" | bc) sec"

echo "End --------------------------------"

# Check if the output files are generated
set -x
ls -l $EXP_DATA_PATH | grep ".stf" | wc -l
ls -l $EXP_DATA_PATH | grep "good-fit" | wc -l
