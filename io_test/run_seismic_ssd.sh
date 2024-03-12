#!/bin/bash

CONCURRENCY=$1 # test 5 10 20

# Check user input
if [ -z "$CONCURRENCY" ]; then
    echo "Usage: $0 <concurrency>"
    exit 1
fi

IterDecon_BIN=///qfs/people/tang584/scripts/linux_resource_detect/example_workflow/seismology-workflow/bin
EXP_DATA_PATH=///scratch/$USER/seismic_data # Local SSD
MSHOCK_DATA_PATH=$EXP_DATA_PATH/MShock
EGF_INPUT_PATH=$EXP_DATA_PATH/EGF

mkdir -p $EXP_DATA_PATH

# record start time in milliseconds
time_1=$(($(date +%s%N)/1000000))
echo "Start sG1IterDcon --------------------------------"

all_input_prefix=( "b916-pb-_ldsp" "g43a-ta-_ldsp" "d27-xt-_ldsp" "nc05-xq-_ldsp" "q43a-ta-_ldsp" "ss64-xi-_ldsp" "enh-ic-00_ldsp" "ss72-xi-_ldsp" "maja-xv-_ldsp" "n02d-ta-_ldsp" "i55a-ta-_ldsp" "149a-ta-_ldsp" "bar-ci-_ldsp" "dac-lb-_ldsp" "d34-xt-_ldsp" "pats-ps-_ldsp" "tato-iu-10_ldsp" "gugu-xf-_ldsp" "b026-pb-_ldsp" "frb-cn-_ldsp")

for t in {1..20}; do
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
    mv _iter_g1.stf ${input_prefix}.lht_iter_g1.stf
    cd $EXP_DATA_PATH
done


time_2=$(($(date +%s%N)/1000000))

echo "Start siftSTFByMisfit.py --------------------------------"

python $IterDecon_BIN/sG1IterDecon/siftSTFByMisfit.py \
    $EXP_DATA_PATH/run*/b916-pb-_ldsp.lht_iter_g1.stf \
    $EXP_DATA_PATH/run*/g43a-ta-_ldsp.lht_iter_g1.stf \
    $EXP_DATA_PATH/run*/d27-xt-_ldsp.lht_iter_g1.stf \
    $EXP_DATA_PATH/run*/nc05-xq-_ldsp.lht_iter_g1.stf \
    $EXP_DATA_PATH/run*/q43a-ta-_ldsp.lht_iter_g1.stf \
    $EXP_DATA_PATH/run*/ss64-xi-_ldsp.lht_iter_g1.stf \
    $EXP_DATA_PATH/run*/enh-ic-00_ldsp.lht_iter_g1.stf \
    $EXP_DATA_PATH/run*/ss72-xi-_ldsp.lht_iter_g1.stf \
    $EXP_DATA_PATH/run*/maja-xv-_ldsp.lht_iter_g1.stf \
    $EXP_DATA_PATH/run*/n02d-ta-_ldsp.lht_iter_g1.stf \
    $EXP_DATA_PATH/run*/i55a-ta-_ldsp.lht_iter_g1.stf \
    $EXP_DATA_PATH/run*/149a-ta-_ldsp.lht_iter_g1.stf \
    $EXP_DATA_PATH/run*/bar-ci-_ldsp.lht_iter_g1.stf \
    $EXP_DATA_PATH/run*/dac-lb-_ldsp.lht_iter_g1.stf \
    $EXP_DATA_PATH/run*/d34-xt-_ldsp.lht_iter_g1.stf \
    $EXP_DATA_PATH/run*/pats-ps-_ldsp.lht_iter_g1.stf \
    $EXP_DATA_PATH/run*/tato-iu-10_ldsp.lht_iter_g1.stf \ 
    $EXP_DATA_PATH/run*/gugu-xf-_ldsp.lht_iter_g1.stf \
    $EXP_DATA_PATH/run*/b026-pb-_ldsp.lht_iter_g1.stf \
    $EXP_DATA_PATH/run*/frb-cn-_ldsp.lht_iter_g1.stf

time_3=$(($(date +%s%N)/1000000))

# Calculate duration, convert milliseconds to seconds
echo "Duration sG1IterDcon: $((time_2-time_1)) ms [$(echo "scale=2; ($time_2-$time_1)/1000" | bc) sec]"
echo "Duration siftSTFByMisfit.py: $((time_3-time_2)) ms [$(echo "scale=2; ($time_3-$time_2)/1000" | bc) sec

echo "End --------------------------------"

# Check if the output files are generated
set -x
ls -l $EXP_DATA_PATH | grep ".stf" | wc -l
ls -l $EXP_DATA_PATH | grep "good-fit" | wc -l
