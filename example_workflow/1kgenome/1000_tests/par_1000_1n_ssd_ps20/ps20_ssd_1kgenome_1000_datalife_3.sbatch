#!/bin/bash
#SBATCH --job-name="deception_1nodes_ssd_1000_datalife_3"
#SBATCH --partition=slurm
#SBATCH -N 1
#SBATCH --ntasks-per-node=60
#SBATCH --time=03:30:00
#SBATCH --output=R_%x.out
#SBATCH --error=R_%x.err
#SBATCH --mail-type=FAIL
#SBATCH --mail-user=meng.tang@pnnl.gov
#SBATCH --exclusive

"--exclude=dc[009,010,119,077]"


DATALIFE_LIB_PATH=/qfs/people/tang584/install/datalife/lib/libmonitor.so
CWD=$(pwd)
rm -rf *.datalife.json *blk_trace.json

NODE_NAMES=`echo $SLURM_JOB_NODELIST|scontrol show hostnames`
LOCAL="SSD" # SSD SHM
# SHARE="PFS" # PFS NFS
TRIAL="t3" # 1 2 3
MODE="p" # p: parallel, s: sequential

if [ "$LOCAL" == "SHM" ]
then
    echo "Running on ramdisk"; export LOCAL_STORE="/dev/shm/$USER" #shm
    rm -rf $LOCAL_STORE/*
else
    echo "Running on SSD"; export LOCAL_STORE="/scratch/$USER"
fi

if [ "$SHARE" == "NFS" ]
then
    echo "Running on NFS"
    SCRIPT_DIR=/qfs/projects/oddite/tang584/1000genome-workflow/bin
    DATA_DIR=/qfs/people/tang584/scripts/1kgenome_sbatch_deception #NFS
    # DATA_DIR=/qfs/projects/oddite/lenny/hermes_scripts/1kgenome_sbatch_deception #NFS
else
    echo "Running on PFS" # but this behaves like NFS
    PFS_DIR=/rcfs/projects/chess #/files0/oddite
    SCRIPT_DIR=$PFS_DIR/$USER/1000genome-workflow/bin
    DATA_DIR=$PFS_DIR/$USER/1kgenome_sbatch_deception_$TRIAL #PFS
    mkdir -p $SCRIPT_DIR $DATA_DIR
    # Candice: commented out to avoid copying in trials
    # if ! [ -s "$SCRIPT_DIR" ]; then cp -r /qfs/projects/oddite/tang584/1000genome-workflow/bin/* $SCRIPT_DIR/; fi
    # if ! [ -s "$DATA_DIR" ]; then cp -r /qfs/people/tang584/scripts/1kgenome_sbatch_deception/* $DATA_DIR/; fi
    if ! [ -s "$SCRIPT_DIR" ]; then echo "No files in $SCRIPT_DIR"; realpath $SCRIPT_DIR/*; fi
    if ! [ -s "$DATA_DIR" ]; then echo "No files in $DATA_DIR"; realpath $DATA_DIR/*; fi
    rm -rf $DATA_DIR/sifted* $DATA_DIR/chr*-freq* $DATA_DIR/chr*-freq* $DATA_DIR/tmp* $DATA_DIR/merged* $DATA_DIR/chr*.tar.gz 
fi


# /files0/oddite/$USER/1kgenome_sbatch #SSD Burst Buffer

CHROMOSOMES=10
NUM_NODES=$SLURM_JOB_NUM_NODES

ITERATION=$(( $CHROMOSOMES / $NUM_NODES -1 ))

# if ITERATION is 0, set to 1
if [ "$ITERATION" -lt "0" ]
then
    echo "ITERATION is 0, set to 1"
    ITERATION=1
fi


PROBLEM_SIZE=20 # the maximum number of tasks within a stage !!!need to modify as needed!!!
# the `SBATCH -N -n` needs to modify as well !!!

# NUM_TASKS_PER_NODE=$((($SLURM_NTASKS/$SLURM_JOB_NUM_NODES))
NUM_TASKS_PER_NODE=$(((PROBLEM_SIZE+NUM_TASKS_PER_NODE)/NUM_NODES)) # (fixed) This is the max number of cores per node
#NUM_NODES=$(((PROBLEM_SIZE+NUM_TASKS_PER_NODE-1)/NUM_TASKS_PER_NODE))
echo "PROBLEM SIZE: $PROBLEM_SIZE SLURM_NTASKS_PER_NODE: $SLURM_NTASKS_PER_NODE NUM_NODES: $NUM_NODES"

# module purge
# module load python/3.7.0 gcc/11.2.0

module purge
# module load python/miniconda3.7 gcc/9.1.0
# PYTHON_PATH=/share/apps/python/miniconda3.7/bin/python

module load gcc/11.2.0 python/miniconda23.3.1 git/2.31.1 cmake/3.21.4 openmpi/4.1.3 
source /share/apps/python/miniconda23.3.1/etc/profile.d/conda.sh
PYTHON_PATH=`which python`

NODE_NAMES=`echo $SLURM_JOB_NODELIST|scontrol show hostnames`
list=()
while read -ra tmp; do
    list+=("${tmp[@]}")
done <<< "$NODE_NAMES"

host_list=$(echo "$NODE_NAMES" | tr '\n' ',')
echo "host_list: $host_list"
# readarray -t host_list <<< "$NODE_NAMES"

# set -x

LOCAL_CLEANUP () {

    echo "Cleaning up local data at $LOCAL_STORE with $host_list ..."
    srun -n$NUM_NODES -w $host_list --exclusive rm -fr $LOCAL_STORE/*
}

STAGE_IN_INDIVIDUALS () {
    echo "Staging individuals data to $LOCAL_STORE with $host_list ..."
    # modified to have targeted stage-in
    for i in $(seq 0 9)
    do
        node_idx=$(($i % $NUM_NODES))
        running_node=${list[$node_idx]}
        let ii=i+1
        echo "staging ALL.chr${ii}.250000.vcf into node $running_node"
        srun -n1 -N1 -w $running_node --exclusive cp $DATA_DIR/columns.txt $LOCAL_STORE/ &
        srun -n1 -N1 -w $running_node --exclusive cp $DATA_DIR/ALL.chr${ii}.250000.vcf $LOCAL_STORE/ &
        srun -n1 -N1 -w $running_node --exclusive cp $DATA_DIR/ALL.chr${ii}.phase3_shapeit2_mvncall_integrated_v5.20130502.sites.annotation.vcf $LOCAL_STORE/ &
        # srun -n1 -w $running_node --exclusive echo $(ls -l $LOCAL_STORE/*.vcf)
    done

    # srun -n$NUM_NODES -w $host_list --exclusive cp $DATA_DIR/ALL.chr*.250000.vcf $LOCAL_STORE/ &

    FNAMES=("SAS EAS GBR AMR AFR EUR ALL")
    for fn in $FNAMES
    do
        srun -n$NUM_NODES -w $host_list --exclusive cp $DATA_DIR/$fn $LOCAL_STORE/ &
    done
}

START_INDIVIDUALS() {

    counter=0
    t_count=1

    for i in $(seq 0 9)
    do
        node_idx=$(($i % $NUM_NODES))
        running_node=${list[$node_idx]}

        for j in $(seq 0 29)
	    do
	    # echo "$i $j"
            if [ "$counter" -lt "$PROBLEM_SIZE" ]
            then
                
                # echo "running node: $running_node t$i"
                let ii=i+1
                # No need to change. This is the smallest input allowed.
                echo "LD_PRELOAD=$DATALIFE_LIB_PATH srun -w $running_node -n1 -N1 --exclusive $SCRIPT_DIR/individuals_shm.py $LOCAL_STORE/ALL.chr${ii}.250000.vcf $ii $((1+j*34)) $((35+j*34)) 1020"
                LD_PRELOAD=$DATALIFE_LIB_PATH \
                    srun -w $running_node -n1 -N1 --exclusive $SCRIPT_DIR/individuals_shm.py $LOCAL_STORE/ALL.chr${ii}.250000.vcf $ii $((1+j*34)) $((35+j*34)) 1020 &

                counter=$(($counter + 1))
                # echo "counter: $counter"

            fi
	done
    done

}

START_INDIVIDUALS_MERGE() {

    for i in $(seq 0 9)
    do
        node_idx=$(($i % $NUM_NODES))
        running_node=${list[$node_idx]}
        let ii=i+1
	    # 10 merge tasks in total
        srun -w $running_node -n1 -N1 --exclusive $PYTHON_PATH $SCRIPT_DIR/individuals_merge_shm.py $ii $LOCAL_STORE/chr${ii}n-1-35.tar.gz $LOCAL_STORE/chr${ii}n-35-69.tar.gz $LOCAL_STORE/chr${ii}n-69-103.tar.gz $LOCAL_STORE/chr${ii}n-103-137.tar.gz $LOCAL_STORE/chr${ii}n-137-171.tar.gz $LOCAL_STORE/chr${ii}n-171-205.tar.gz $LOCAL_STORE/chr${ii}n-205-239.tar.gz $LOCAL_STORE/chr${ii}n-239-273.tar.gz $LOCAL_STORE/chr${ii}n-273-307.tar.gz $LOCAL_STORE/chr${ii}n-307-341.tar.gz $LOCAL_STORE/chr${ii}n-341-375.tar.gz $LOCAL_STORE/chr${ii}n-375-409.tar.gz $LOCAL_STORE/chr${ii}n-409-443.tar.gz $LOCAL_STORE/chr${ii}n-443-477.tar.gz $LOCAL_STORE/chr${ii}n-477-511.tar.gz $LOCAL_STORE/chr${ii}n-511-545.tar.gz $LOCAL_STORE/chr${ii}n-545-579.tar.gz $LOCAL_STORE/chr${ii}n-579-613.tar.gz $LOCAL_STORE/chr${ii}n-613-647.tar.gz $LOCAL_STORE/chr${ii}n-647-681.tar.gz $LOCAL_STORE/chr${ii}n-681-715.tar.gz $LOCAL_STORE/chr${ii}n-715-749.tar.gz $LOCAL_STORE/chr${ii}n-749-783.tar.gz $LOCAL_STORE/chr${ii}n-783-817.tar.gz $LOCAL_STORE/chr${ii}n-817-851.tar.gz $LOCAL_STORE/chr${ii}n-851-885.tar.gz $LOCAL_STORE/chr${ii}n-885-919.tar.gz $LOCAL_STORE/chr${ii}n-919-953.tar.gz $LOCAL_STORE/chr${ii}n-953-987.tar.gz $LOCAL_STORE/chr${ii}n-987-1021.tar.gz &
    done

}


START_SIFTING() {

    for i in $(seq 0 9)
    do
        node_idx=$(($i % $NUM_NODES))
        running_node=${list[$node_idx]}
        # 10 sifting tasks in total
        let ii=i+1
        srun -w $running_node -n1 -N1 --exclusive $PYTHON_PATH $SCRIPT_DIR/sifting.py $LOCAL_STORE/ALL.chr${ii}.phase3_shapeit2_mvncall_integrated_v5.20130502.sites.annotation.vcf $ii &
    done

}

STAGE_OUT_INDIVIDUALS_MERGE() {
    for i in $(seq 0 9)
    do
        node_idx=$(($i % $NUM_NODES))
        running_node=${list[$node_idx]}
        let ii=i+1
        scp $running_node:$LOCAL_STORE/chr${ii}*.tar.gz $DATA_DIR/ &
    done
    # du -h $DATA_DIR/chr*n.tar.gz
}


START_MUTATION_OVERLAP() {

    FNAMES=("SAS EAS GBR AMR AFR EUR ALL")
    for i in $(seq 0 9)
    do
        node_idx=$(($i % $NUM_NODES))
        running_node=${list[$node_idx]}
        for j in $FNAMES
        do
            let ii=i+1
            srun -w $running_node -n1 -N1 --exclusive $PYTHON_PATH $SCRIPT_DIR/mutation_overlap_shm.py -c $ii -pop $j &
        done
    done

}

START_FREQUENCY() {

    FNAMES=("SAS EAS GBR AMR AFR EUR ALL")
    for i in $(seq 0 9)
    do
        node_idx=$(($i % $NUM_NODES))
        running_node=${list[$node_idx]}
        for j in $FNAMES
        do
            let ii=i+1
            srun -w $running_node -n1 -N1 --exclusive $PYTHON_PATH $SCRIPT_DIR/frequency_shm.py -c $ii -pop $j &
        done
    done

}

set -x 

hostname;date;

echo "Making directory at $LOCAL_STORE ..."
srun -n$NUM_NODES -w $host_list --exclusive mkdir -p $LOCAL_STORE


LOCAL_CLEANUP



total_start_time=$SECONDS

cd $DATA_DIR

# Stage 0: Stage-in individuals data
start_time=$SECONDS
STAGE_IN_INDIVIDUALS
wait
duration=$(($SECONDS - $start_time))
echo "data stage-in for individuals : $(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed ($duration secs)."
# Check size of staged-in data
echo "Checking staged-in data ----------------" | tee -a $CWD/R_$SLURM_JOB_NAME.out
srun -n$NUM_NODES -w $host_list --exclusive du -k $LOCAL_STORE | tee -a $CWD/R_$SLURM_JOB_NAME.out

# Stage 1 : Individuals
start_time=$SECONDS
echo "individuals CHROMOSOME from $START_CHROMOSOME to $END_CHROMOSOME"
START_INDIVIDUALS
wait
duration=$(($SECONDS - $start_time))
echo "individuals : $(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed ($duration secs)."

# # Stage 2 : Individuals merge + Sifting
# start_time=$SECONDS
# echo "individuals_merge+sifting from $START_CHROMOSOME to $END_CHROMOSOME"
# START_SIFTING
# START_INDIVIDUALS_MERGE
# wait
# duration=$(($SECONDS - $start_time))
# echo "individuals_merge+sifting : $(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed ($duration secs)."

# # Stage 3 : Mutation overlap + Frequency
# start_time=$SECONDS
# echo "Running mutation+frequency"
# START_MUTATION_OVERLAP
# START_FREQUENCY
# wait
# duration=$(($SECONDS - $start_time))
# echo "mutation+frequency : $(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed ($duration secs)."


total_duration=$(($SECONDS - $total_start_time))
echo "All done : $(($total_duration / 60)) minutes and $(($total_duration % 60)) seconds elapsed ($total_duration secs)."

set -x
# check output
echo "Checking all output ----------------"
srun -n$NUM_NODES -w $host_list --exclusive du -h $DATA_DIR

# Candice: do not remove the current dir which contains all initial input for the test run
# # remove current dir
# rm -fr $DATA_DIR/*

hostname;date;
sacct -j $SLURM_JOB_ID -o jobid,submit,start,end,state


# Create and move results to the test log folder
TEST_LOG_FOLDER=$CWD/"$PROBLEM_SIZE"_"$MODE"_"$NUM_NODES"n_"$LOCAL"_"$TRIAL"
mkdir -p $TEST_LOG_FOLDER
rm -rf $TEST_LOG_FOLDER/*

# STAGE_OUT_DATALIFE
# echo "Checking individuals output ----------------"
# srun -n$NUM_NODES -w $host_list --exclusive ls -l $LOCAL_STORE
srun -n$NUM_NODES -w $host_list --exclusive cp -r $LOCAL_STORE/*.json $TEST_LOG_FOLDER

mv $DATA_DIR/*.datalife.json $TEST_LOG_FOLDER
mv $DATA_DIR/*blk_trace.json $TEST_LOG_FOLDER


mv $CWD/R_*$SLURM_JOB_NAME*.err $TEST_LOG_FOLDER
mv $CWD/R_*$SLURM_JOB_NAME*.out $TEST_LOG_FOLDER

# Clean up 
LOCAL_CLEANUP