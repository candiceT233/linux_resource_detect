#!/bin/bash
#SBATCH --job-name="deception_2nodes_pfs_3000_1"
#SBATCH --partition=slurm
#SBATCH --exclude=dc[119,077]
#SBATCH -N 2
#SBATCH --ntasks-per-node=60
#SBATCH --time=03:30:00
#SBATCH --output=R_%x.out
#SBATCH --error=R_%x.err
#SBATCH --mail-type=FAIL
#SBATCH --mail-user=meng.tang@pnnl.gov
#SBATCH --exclusive

'''
# #SBATCH -N 5
# #SBATCH --ntasks=200
# #SBATCH --ntasks-per-node=40

# #SBATCH -N 10
# #SBATCH --ntasks=200
# #SBATCH --ntasks-per-node=20

'''


NODE_NAMES=`echo $SLURM_JOB_NODELIST|scontrol show hostnames`
SHARE="PFS" # PFS NFS

if [ "$SHARE" == "NFS" ]
then
    echo "Running on NFS"
    SCRIPT_DIR=/qfs/projects/oddite/tang584/1000genome-workflow/bin
    CURRENT_DIR=/qfs/people/tang584/scripts/1kgenome_sbatch_deception #NFS
    # CURRENT_DIR=/qfs/projects/oddite/lenny/hermes_scripts/1kgenome_sbatch_deception #NFS
else
    echo "Running on PFS" # but this behaves like NFS
    PFS_DIR=/rcfs/projects/chess #/files0/oddite
    SCRIPT_DIR=$PFS_DIR/$USER/1000genome-workflow/bin
    CURRENT_DIR=$PFS_DIR/$USER/1kgenome_sbatch_deception #PFS
    mkdir -p $SCRIPT_DIR $CURRENT_DIR
    # Candice: commented out to avoid copying in trials
    # if ! [ -s "$SCRIPT_DIR" ]; then cp -r /qfs/projects/oddite/tang584/1000genome-workflow/bin/* $SCRIPT_DIR/; fi
    # if ! [ -s "$CURRENT_DIR" ]; then cp -r /qfs/people/tang584/scripts/1kgenome_sbatch_deception/* $CURRENT_DIR/; fi
    if ! [ -s "$SCRIPT_DIR" ]; then echo "No files in $SCRIPT_DIR"; realpath $SCRIPT_DIR/*; fi
    if ! [ -s "$CURRENT_DIR" ]; then echo "No files in $CURRENT_DIR"; realpath $CURRENT_DIR/*; fi
    # clear intermediate and freq output
    rm -rf $CURRENT_DIR/chr*-freq* $CURRENT_DIR/tmp* $CURRENT_DIR/merged_chr* $CURRENT_DIR/chr*.tar.gz
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


PROBLEM_SIZE=300 # the maximum number of tasks within a stage !!!need to modify as needed!!!
# the `SBATCH -N -n` needs to modify as well !!!

# NUM_TASKS_PER_NODE=$((($SLURM_NTASKS/$SLURM_JOB_NUM_NODES))
NUM_TASKS_PER_NODE=$(((PROBLEM_SIZE+NUM_TASKS_PER_NODE)/NUM_NODES)) # (fixed) This is the max number of cores per node
#NUM_NODES=$(((PROBLEM_SIZE+NUM_TASKS_PER_NODE-1)/NUM_TASKS_PER_NODE))
echo "PROBLEM SIZE: $PROBLEM_SIZE SLURM_NTASKS_PER_NODE: $SLURM_NTASKS_PER_NODE NUM_NODES: $NUM_NODES"

# module purge
# module load python/3.7.0 gcc/11.2.0

module purge
module load python/miniconda3.7 gcc/9.1.0
PYTHON_PATH=/share/apps/python/miniconda3.7/bin/python

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
                    echo "srun -w $running_node -n1 -N1 --exclusive $SCRIPT_DIR/individuals.py $CURRENT_DIR/ALL.chr${ii}.250000.vcf $ii $((1+j*100)) $((101+j*100)) 3000 &"
                    srun -w $running_node -n1 -N1 --exclusive $SCRIPT_DIR/individuals.py $CURRENT_DIR/ALL.chr${ii}.250000.vcf $ii $((1+j*100)) $((101+j*100)) 3000 &
                    let counter=counter+1
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
        srun -w $running_node -n1 -N1 --exclusive $PYTHON_PATH $SCRIPT_DIR/individuals_merge.py $ii $CURRENT_DIR/chr${ii}n-1-101.tar.gz $CURRENT_DIR/chr${ii}n-101-201.tar.gz $CURRENT_DIR/chr${ii}n-201-301.tar.gz $CURRENT_DIR/chr${ii}n-301-401.tar.gz $CURRENT_DIR/chr${ii}n-401-501.tar.gz $CURRENT_DIR/chr${ii}n-501-601.tar.gz $CURRENT_DIR/chr${ii}n-601-701.tar.gz $CURRENT_DIR/chr${ii}n-701-801.tar.gz $CURRENT_DIR/chr${ii}n-801-901.tar.gz $CURRENT_DIR/chr${ii}n-901-1001.tar.gz $CURRENT_DIR/chr${ii}n-1001-1101.tar.gz $CURRENT_DIR/chr${ii}n-1101-1201.tar.gz $CURRENT_DIR/chr${ii}n-1201-1301.tar.gz $CURRENT_DIR/chr${ii}n-1301-1401.tar.gz $CURRENT_DIR/chr${ii}n-1401-1501.tar.gz $CURRENT_DIR/chr${ii}n-1501-1601.tar.gz $CURRENT_DIR/chr${ii}n-1601-1701.tar.gz $CURRENT_DIR/chr${ii}n-1701-1801.tar.gz $CURRENT_DIR/chr${ii}n-1801-1901.tar.gz $CURRENT_DIR/chr${ii}n-1901-2001.tar.gz $CURRENT_DIR/chr${ii}n-2001-2101.tar.gz $CURRENT_DIR/chr${ii}n-2101-2201.tar.gz $CURRENT_DIR/chr${ii}n-2201-2301.tar.gz $CURRENT_DIR/chr${ii}n-2301-2401.tar.gz $CURRENT_DIR/chr${ii}n-2401-2501.tar.gz $CURRENT_DIR/chr${ii}n-2501-2601.tar.gz $CURRENT_DIR/chr${ii}n-2601-2701.tar.gz $CURRENT_DIR/chr${ii}n-2701-2801.tar.gz $CURRENT_DIR/chr${ii}n-2801-2901.tar.gz $CURRENT_DIR/chr${ii}n-2901-3001.tar.gz &
    done

}

START_SIFTING() {

    for i in $(seq 0 9)
    do
        node_idx=$(($i % $NUM_NODES))
        running_node=${list[$node_idx]}
        # 10 sifting tasks in total
        let ii=i+1
        srun -w $running_node -n1 -N1 --exclusive $PYTHON_PATH $SCRIPT_DIR/sifting.py $CURRENT_DIR/ALL.chr${ii}.phase3_shapeit2_mvncall_integrated_v5.20130502.sites.annotation.vcf $ii &
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

echo "Making directory at $CURRENT_DIR ..."
srun -n$NUM_NODES -w $host_list --exclusive mkdir -p $CURRENT_DIR



total_start_time=$SECONDS

cd $CURRENT_DIR

# Stage 1 : Individuals
start_time=$SECONDS
echo "individuals CHROMOSOME from $START_CHROMOSOME to $END_CHROMOSOME"
START_INDIVIDUALS
wait
duration=$(($SECONDS - $start_time))
echo "individuals : $(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed ($duration secs)."

# Stage 2 : Individuals merge + Sifting
start_time=$SECONDS

echo "individuals_merge+sifting from $START_CHROMOSOME to $END_CHROMOSOME"
START_SIFTING
START_INDIVIDUALS_MERGE
wait
duration=$(($SECONDS - $start_time))
echo "individuals_merge+sifting : $(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed ($duration secs)."

# Stage 3 : Mutation overlap + Frequency
start_time=$SECONDS
START_MUTATION_OVERLAP
START_FREQUENCY
wait
duration=$(($SECONDS - $start_time))
echo "mutation+frequency : $(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed ($duration secs)."

total_duration=$(($SECONDS - $total_start_time))
echo "All done : $(($total_duration / 60)) minutes and $(($total_duration % 60)) seconds elapsed ($total_duration secs)."

set -x
# check output
echo "Checking all output ----------------"
srun -n$NUM_NODES -w $host_list --exclusive -l $CURRENT_DIR

LOCAL_CLEANUP

# Candice: do not remove the current dir which contains all initial input for the test run
# # remove current dir
# rm -fr $CURRENT_DIR/*

hostname;date;
sacct -j $SLURM_JOB_ID -o jobid,submit,start,end,state
