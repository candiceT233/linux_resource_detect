#!/bin/sh
#SBATCH --job-name=localssd_pior_test
#SBATCH --partition=slurm
#SBATCH --time=8:00:00
#SBATCH -N 1
#SBATCH --output=./ior_%x_R.out
#SBATCH --error=./ior_%x_R.err
#SBATCH -A oddite

IterDecon_BIN=///qfs/people/tang584/scripts/linux_resource_detect/example_workflow/seismology-workflow/bin
EXP_DATA_PATH=/rcfs/projects/chess/$USER/seismic_data # BeeGFS
MSHOCK_DATA_PATH=$EXP_DATA_PATH/MShock
EGF_INPUT_PATH=$EXP_DATA_PATH/EGF

# CONCURRENCY=$1 # test 5 10 20
# INPUT_FILE_NUM=$2
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
rm -rf $MSHOCK_DATA_PATH/*_blk_trace
rm -rf $EGF_INPUT_PATH/*_blk_trace
rm -rf $EXP_DATA_PATH/*_blk_trace

# record start time in milliseconds
time_1=$(($(date +%s%N)/1000000))
echo "Start sG1IterDcon --------------------------------"


num_files="${#all_input_file[@]}"

# # Darshan Environment Variables
# export DARSHAN_ENABLE_NONMPI=1
# export DARSHAN_MOD_ENABLE="DXT_POSIX"
# # export LD_PRELOAD=/qfs/people/tang584/install/darshan_runtime/lib/libdarshan.so io-test
# # export DARSHAN_LOGHINTS="romio_no_indep_rw=true;cb_nodes=1"
# export DXT_ENABLE_IO_TRACE=1

# DATALIFE_LIB_PATH=/qfs/people/tang584/install/datalife/lib/libclient.so
DATALIFE_LIB_PATH=/qfs/people/tang584/install/datalife/lib/libmonitor.so
# # datalife monitor env variables
# export MONITOR_SOCKETS_PER_CONN=0
# export MONITOR_ENABLE_SHARED_MEMORY=0
# export MONITOR_SCALABLE_CACHE=0
# export MONITOR_NETWORK_CACHE=0
# export MONITOR_PREFETCH_NUM_BLKS=0
# export MONITOR_PREFETCH_DELTA=0
# export MONITOR_URL_TIMEOUT=0
# export MONITOR_DELETE_DOWNLOADS=0
# export MONITOR_DOWNLOAD_FOR_SIZE=0

# Cleanup previous logs
TAZER_STAT_LOG=tazer_stat.log
rm -rf ./*$TAZER_STAT_LOG.log
DATALIFE_STAT_LOG_FOLDER=/qfs/people/tang584/scripts/linux_resource_detect/io_test/datalife_seism_bgfs
mkdir -p $DATALIFE_STAT_LOG_FOLDER
rm -rf $DATALIFE_STAT_LOG_FOLDER/*

# for t in {1..$}; do
# for input_file in ${all_input_file[@]}; do
for ((i = 0; i < num_files; i++)); do
    input_file=${all_input_file[i]}
    mkdir run_$input_file
    cd run_$input_file

    echo "Running input ${input_file}"

    # LD_PRELOAD=/qfs/people/tang584/install/darshan_runtime/lib/libdarshan.so \

    # datalife-run \

    # cd $IterDecon_BIN
    LD_PRELOAD=$DATALIFE_LIB_PATH \
        sh $IterDecon_BIN/sG1IterDecon $MSHOCK_DATA_PATH/${input_file} $EGF_INPUT_PATH/${input_file} 2>&1 | tee -a $DATALIFE_STAT_LOG_FOLDER/iterdecon_n${CONCURRENCY}_f${INPUT_FILE_NUM}_${TAZER_STAT_LOG} #&
    
    # cd $EXP_DATA_PATH

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
    mv *_iter_g1.stf $EXP_DATA_PATH/${input_prefix}.lht_iter_g1.stf
    cd $EXP_DATA_PATH
    rm -rf run_$input_file
done

sudo /sbin/sysctl vm.drop_caches=3

time_2=$(($(date +%s%N)/1000000))

echo "Start siftSTFByMisfit.py --------------------------------"

# Get all .stf files in the directory #EXP_DATA_PATH into a string
file_str=$(ls $EXP_DATA_PATH/*.stf | tr '\n' ' ')
# echo "Files: $file_str"

set -x

# LD_PRELOAD=/qfs/people/tang584/install/darshan_runtime/lib/libdarshan.so \



# datalife-run \
LD_PRELOAD=$DATALIFE_LIB_PATH \
    python3 $IterDecon_BIN/siftSTFByMisfit.py $file_str 2>&1 | tee sift_n${CONCURRENCY}_f${INPUT_FILE_NUM}_${TAZER_STAT_LOG}

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
ls -l $EXP_DATA_PATH | grep "good-fit" | wc -l | tee a sift_${TAZER_STAT_LOG}
du -k $EXP_DATA_PATH/*.stf | tee a sift_${TAZER_STAT_LOG}

mv ./*.log $DATALIFE_STAT_LOG_FOLDER/
mv $MSHOCK_DATA_PATH/*_blk_trace $DATALIFE_STAT_LOG_FOLDER/
mv $EGF_INPUT_PATH/*_blk_trace $DATALIFE_STAT_LOG_FOLDER/
mv $EXP_DATA_PATH/*_blk_trace $DATALIFE_STAT_LOG_FOLDER/

# 1 2
## Without Datalife
# Duration sG1IterDcon: 9644 ms [9.64 sec]
# Duration siftSTFByMisfit.py: 550 ms [.55 sec
## With datalife and without GATHERSTAT
# Duration sG1IterDcon: 123763 ms [123.76 sec]
# Duration siftSTFByMisfit.py: 1069 ms [1.06 sec
# Duration sG1IterDcon: 141266 ms [141.26 sec]
# Duration siftSTFByMisfit.py: 2574 ms [2.57 sec
# Duration sG1IterDcon: 4006 ms [4.00 sec]
# Duration siftSTFByMisfit.py: 1043 ms [1.04 sec