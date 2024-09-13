#!/bin/bash
#SBATCH --job-name="deception_1nodes_pfs_1000_datalife_2"
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
SHARE="PFS" # PFS NFS
TRIAL="t2" # 1 2 3
MODE="s" # p: parallel, s: sequential

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
    # clear intermediate and freq output
    rm -rf $DATA_DIR/chr*-freq* $DATA_DIR/tmp* $DATA_DIR/merged_chr* $DATA_DIR/chr*.tar.gz
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


PROBLEM_SIZE=1 # the maximum number of tasks within a stage !!!need to modify as needed!!!
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



START_INDIVIDUALS() {
    set -x

    counter=0
    t_count=0
    # get the total tasks allocated from slurm
    ALLOC_TASKS=$SLURM_NTASKS

    for i in $(seq 0 9)
    do
        for j in $(seq 0 29)
	do
	    # echo "$i $j"
            if [ "$counter" -lt "$PROBLEM_SIZE" ]
            then
                node_idx=$(($i % $NUM_NODES))
                running_node=${list[$node_idx]}
                # echo "running node: $running_node t$i"
                let ii=i+1
                # No need to change. This is the smallest input allowed.
                # echo "srun -w $running_node -n1 -N1 --exclusive $SCRIPT_DIR/individuals.py $DATA_DIR/ALL.chr${ii}.250000.vcf $ii $((1+j*34)) $((35+j*34)) 1020"
                set -x
                # check mode
                if [ "$MODE" == "p" ]
                then
                    LD_PRELOAD=$DATALIFE_LIB_PATH \
                        srun -w $running_node -n1 -N1 --exclusive $SCRIPT_DIR/individuals.py $DATA_DIR/ALL.chr${ii}.250000.vcf $ii $((1+j*34)) $((35+j*34)) 1020 &
                else
                    LD_PRELOAD=$DATALIFE_LIB_PATH \
                        srun -w $running_node -n1 -N1 --exclusive $PYTHON_PATH $SCRIPT_DIR/individuals.py $DATA_DIR/ALL.chr${ii}.250000.vcf $ii $((1+j*34)) $((35+j*34)) 1020
                fi

                set +x

                counter=$(($counter + 1))

                # let t_count=t_count+1
                
                # # wait if t_count reaches ALLOC_TASKS
                # if [ "$t_count" -eq "$ALLOC_TASKS" ]
                # then
                #     echo "waiting for the $ALLOC_TASKS tasks to finish"
                #     wait
                #     t_count=0
                # fi
            fi
	done
    done
    # sleep 3

}

START_INDIVIDUALS_MERGE() {

    for i in $(seq 0 9)
    do
        node_idx=$(($i % $NUM_NODES))
        running_node=${list[$node_idx]}
        let ii=i+1
        # 10 merge tasks in total
        srun -w $running_node -n1 -N1 --exclusive $PYTHON_PATH $SCRIPT_DIR/individuals_merge.py $ii $DATA_DIR/chr${ii}n-1-35.tar.gz $DATA_DIR/chr${ii}n-35-69.tar.gz $DATA_DIR/chr${ii}n-69-103.tar.gz $DATA_DIR/chr${ii}n-103-137.tar.gz $DATA_DIR/chr${ii}n-137-171.tar.gz $DATA_DIR/chr${ii}n-171-205.tar.gz $DATA_DIR/chr${ii}n-205-239.tar.gz $DATA_DIR/chr${ii}n-239-273.tar.gz $DATA_DIR/chr${ii}n-273-307.tar.gz $DATA_DIR/chr${ii}n-307-341.tar.gz $DATA_DIR/chr${ii}n-341-375.tar.gz $DATA_DIR/chr${ii}n-375-409.tar.gz $DATA_DIR/chr${ii}n-409-443.tar.gz $DATA_DIR/chr${ii}n-443-477.tar.gz $DATA_DIR/chr${ii}n-477-511.tar.gz $DATA_DIR/chr${ii}n-511-545.tar.gz $DATA_DIR/chr${ii}n-545-579.tar.gz $DATA_DIR/chr${ii}n-579-613.tar.gz $DATA_DIR/chr${ii}n-613-647.tar.gz $DATA_DIR/chr${ii}n-647-681.tar.gz $DATA_DIR/chr${ii}n-681-715.tar.gz $DATA_DIR/chr${ii}n-715-749.tar.gz $DATA_DIR/chr${ii}n-749-783.tar.gz $DATA_DIR/chr${ii}n-783-817.tar.gz $DATA_DIR/chr${ii}n-817-851.tar.gz $DATA_DIR/chr${ii}n-851-885.tar.gz $DATA_DIR/chr${ii}n-885-919.tar.gz $DATA_DIR/chr${ii}n-919-953.tar.gz $DATA_DIR/chr${ii}n-953-987.tar.gz $DATA_DIR/chr${ii}n-987-1021.tar.gz &
    done

}

START_SIFTING() {

    for i in $(seq 0 9)
    do
        node_idx=$(($i % $NUM_NODES))
        running_node=${list[$node_idx]}
        # 10 sifting tasks in total
        let ii=i+1
        srun -w $running_node -n1 -N1 --exclusive $PYTHON_PATH $SCRIPT_DIR/sifting.py $DATA_DIR/ALL.chr${ii}.phase3_shapeit2_mvncall_integrated_v5.20130502.sites.annotation.vcf $ii &
    done

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
            srun -w $running_node -n1 -N1 --exclusive $PYTHON_PATH $SCRIPT_DIR/mutation_overlap.py -c $ii -pop $j &
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
            srun -w $running_node -n1 -N1 --exclusive $PYTHON_PATH $SCRIPT_DIR/frequency.py -c $ii -pop $j &
        done
    done

}

set -x 

hostname;date;

echo "Making directory at $DATA_DIR ..."
srun -n$NUM_NODES -w $host_list --exclusive mkdir -p $DATA_DIR



total_start_time=$SECONDS

cd $DATA_DIR


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

LOCAL_CLEANUP

# Candice: do not remove the current dir which contains all initial input for the test run
# # remove current dir
# rm -fr $DATA_DIR/*

hostname;date;
sacct -j $SLURM_JOB_ID -o jobid,submit,start,end,state


# Create and move results to the test log folder
TEST_LOG_FOLDER=$CWD/"$PROBLEM_SIZE"_"$MODE"_"$NUM_NODES"n_"$SHARE"_"$TRIAL"
mkdir -p $TEST_LOG_FOLDER
rm -rf $TEST_LOG_FOLDER/*

mv $DATA_DIR/*.datalife.json $TEST_LOG_FOLDER
mv $DATA_DIR/*blk_trace.json $TEST_LOG_FOLDER

mv $CWD/R_*$SLURM_JOB_NAME*.err $TEST_LOG_FOLDER
mv $CWD/R_*$SLURM_JOB_NAME*.out $TEST_LOG_FOLDER