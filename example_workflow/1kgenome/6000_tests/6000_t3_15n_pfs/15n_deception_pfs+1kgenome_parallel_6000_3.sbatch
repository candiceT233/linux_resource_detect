#!/bin/bash
#SBATCH --job-name="deception_15nodes_pfs_6000_3"
#SBATCH --partition=slurm
#SBATCH --exclusive
#SBATCH --exclude=dc[119,077]
#SBATCH -A chess
#SBATCH -N 15
#SBATCH --ntasks=300
#SBATCH --ntasks-per-node=20
#SBATCH --time=10:00:00
#SBATCH --output=R_%x.out
#SBATCH --error=R_%x.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=meng.tang@pnnl.gov

INPUT_SIZE=6000 # input size for current test run

TASK_PER_CHROM=30 # fixed, there is only 10 chromosomes in the input so only 30 tasks per chrom
PROBLEM_SIZE=300 # the maximum number of tasks within a stage !!!need to modify as needed!!!
# the `SBATCH -N -n` needs to modify as well !!!
NUM_TASKS_PER_NODE=20 # (fixed) This is the max number of cores per node
NUM_NODES=$(((PROBLEM_SIZE+NUM_TASKS_PER_NODE-1)/NUM_TASKS_PER_NODE))
echo "Expected PROBLEM SIZE: $PROBLEM_SIZE NUM_TASKS_PER_NODE: $NUM_TASKS_PER_NODE NUM_NODES: $NUM_NODES"
echo "Slurm allocated $SLURM_JOB_NUM_NODES nodes with $SLURM_NTASKS total tasks with $SLURM_NTASKS_PER_NODE tasks per node"


NODE_NAMES=`echo $SLURM_JOB_NODELIST|scontrol show hostnames`

SHARE="PFS" # PFS NFS

if [ "$SHARE" == "NFS" ]
then
    echo "Running on NFS"
    SCRIPT_DIR=/qfs/projects/oddite/lenny/1000genome-workflow/bin
    # CURRENT_DIR=/qfs/projects/oddite/lenny/hermes_scripts/1kgenome_sbatch #NFS
    CURRENT_DIR=/qfs/projects/oddite/lenny/hermes_scripts/new_tazer_stat_gen #NFS
else
    echo "Running on PFS" # but this behaves like NFS
    PFS_DIR=/rcfs/projects/chess #/files0/oddite
    SCRIPT_DIR=$PFS_DIR/$USER/1000genome-workflow/bin
    CURRENT_DIR=$PFS_DIR/$USER/1kgenome_sbatch_deception #PFS
    mkdir -p $SCRIPT_DIR $CURRENT_DIR
    # Candice: commented out to avoid copying in trials
    if ! [ -s "$SCRIPT_DIR" ]; then echo "No files in $SCRIPT_DIR"; realpath $SCRIPT_DIR/*; fi
    if ! [ -s "$CURRENT_DIR" ]; then echo "No files in $CURRENT_DIR"; realpath $CURRENT_DIR/*; fi
    # clear intermediate and freq output
    rm -rf $CURRENT_DIR/chr*-freq* $CURRENT_DIR/tmp* $CURRENT_DIR/merged_shr* $CURRENT_DIR/chr*.tar.gz #chr*n*.tar.gz
fi


module purge
module load python/miniconda3.7 gcc/9.1.0
PYTHON_PATH="`which python`"
echo "PYTHON_PATH: $PYTHON_PATH"

# set -x

NODE_NAMES=`echo $SLURM_JOB_NODELIST|scontrol show hostnames`
list=()
while read -ra tmp; do
    list+=("${tmp[@]}")
done <<< "$NODE_NAMES"
echo "list: ${list[@]}"
host_list=$(echo "$NODE_NAMES" | tr '\n' ',')
echo "host_list: $host_list"


START_INDIVIDUALS(){
    # START_INDIVIDUALS splits the tasks into 300 subtasks (30 tasks per chromosome) into 15 nodes (20 tasks per node)

    # Counter for tasks
    total_task_counter=0
    node_task_counter=0
    node_index=0
    index_increment=$((INPUT_SIZE / TASK_PER_CHROM))
    index_stop=$((INPUT_SIZE + 1))

    # Loop through the files (ALL.chr1.250000.vcf to ALL.chr10.250000.vcf)
    for ((chr_number = 1; chr_number <= 10; chr_number++)); do
        chrom_file="$CURRENT_DIR/ALL.chr${chr_number}.250000.vcf"
        # Initialize index_start
        index_start=1
        
        # Loop through the tasks for each file
        while ((index_start < $index_stop)); do
            
            let node_task_counter=node_task_counter+1
            let total_task_counter=total_task_counter+1
            # Calculate input values based on the loop indices
            index_end="$((index_start + index_increment))"

            # Ensure that index_end stops at 851
            if ((index_end > $index_stop)); then
                index_end=$index_stop
            fi

            # Determine the node for this task
            selected_node="${list[$node_index]}"

            # Print the input parameters as individual lines
            echo "srun -n1 -N1 -w $selected_node --exclusive $PYTHON_PATH $SCRIPT_DIR/individuals.py $chrom_file $chr_number $index_start $index_end $INPUT_SIZE"
            srun -n1 -N1 -w $selected_node --exclusive $PYTHON_PATH $SCRIPT_DIR/individuals.py $chrom_file $chr_number $index_start $index_end $INPUT_SIZE &

            # Update index_start for the next iteration
            index_start="$((index_end))"

            # breaks when total_task_counter reaches PROBLEM_SIZE
            if ((total_task_counter >= $PROBLEM_SIZE)); then
                break
            fi

            # increment node_index when node_task_counter reaches NUM_TASKS_PER_NODE
            if ((node_task_counter >= $NUM_TASKS_PER_NODE)); then
                let node_index=node_index+1
                let node_task_counter=0
            fi
            
        done
    done
    echo "total_task_counter: $total_task_counter"
    wait
}


START_INDIVIDUALS_MERGE() {
    set -x
    for i in $(seq 0 9)
    do
        let ii=i+1
	    # 10 merge tasks in total
        # srun -w ${list[$i]} -n1 -N1 --exclusive $PYTHON_PATH $SCRIPT_DIR/individuals_merge.py $i $CURRENT_DIR/chr${ii}n*.tar.gz &
        srun -w ${list[$i]} -n1 -N1 --exclusive $PYTHON_PATH $SCRIPT_DIR/individuals_merge.py $ii $CURRENT_DIR/chr${ii}n-1-201.tar.gz $CURRENT_DIR/chr${ii}n-201-401.tar.gz $CURRENT_DIR/chr${ii}n-401-601.tar.gz $CURRENT_DIR/chr${ii}n-601-801.tar.gz $CURRENT_DIR/chr${ii}n-801-1001.tar.gz $CURRENT_DIR/chr${ii}n-1001-1201.tar.gz $CURRENT_DIR/chr${ii}n-1201-1401.tar.gz $CURRENT_DIR/chr${ii}n-1401-1601.tar.gz $CURRENT_DIR/chr${ii}n-1601-1801.tar.gz $CURRENT_DIR/chr${ii}n-1801-2001.tar.gz $CURRENT_DIR/chr${ii}n-2001-2201.tar.gz $CURRENT_DIR/chr${ii}n-2201-2401.tar.gz $CURRENT_DIR/chr${ii}n-2401-2601.tar.gz $CURRENT_DIR/chr${ii}n-2601-2801.tar.gz $CURRENT_DIR/chr${ii}n-2801-3001.tar.gz $CURRENT_DIR/chr${ii}n-3001-3201.tar.gz $CURRENT_DIR/chr${ii}n-3201-3401.tar.gz $CURRENT_DIR/chr${ii}n-3401-3601.tar.gz $CURRENT_DIR/chr${ii}n-3601-3801.tar.gz $CURRENT_DIR/chr${ii}n-3801-4001.tar.gz $CURRENT_DIR/chr${ii}n-4001-4201.tar.gz $CURRENT_DIR/chr${ii}n-4201-4401.tar.gz $CURRENT_DIR/chr${ii}n-4401-4601.tar.gz $CURRENT_DIR/chr${ii}n-4601-4801.tar.gz $CURRENT_DIR/chr${ii}n-4801-5001.tar.gz $CURRENT_DIR/chr${ii}n-5001-5201.tar.gz $CURRENT_DIR/chr${ii}n-5201-5401.tar.gz $CURRENT_DIR/chr${ii}n-5401-5601.tar.gz $CURRENT_DIR/chr${ii}n-5601-5801.tar.gz $CURRENT_DIR/chr${ii}n-5801-6001.tar.gz &
    done
}

START_SIFTING() {
    set -x
    for i in $(seq 0 9)
    do
        let ii=i+1
        # 10 sifting tasks in total
        srun -w ${list[$i]} -n1 -N1 --exclusive $PYTHON_PATH $SCRIPT_DIR/sifting.py $CURRENT_DIR/ALL.chr${ii}.phase3_shapeit2_mvncall_integrated_v5.20130502.sites.annotation.vcf $i &
    done
}

START_MUTATION_OVERLAP() {
    set -x
    FNAMES=("SAS EAS GBR AMR AFR EUR ALL")
    for i in $(seq 0 9)
    do
        let ii=i+1
        for j in $FNAMES
        do
            srun -w ${list[$i]} -n1 -N1 --exclusive $PYTHON_PATH $SCRIPT_DIR/mutation_overlap.py -c $ii -pop $j &
        done
    done
}

START_FREQUENCY() {
    set -x
    FNAMES=("SAS EAS GBR AMR AFR EUR ALL")
    for i in $(seq 0 9)
    do
        let ii=i+1
        for j in $FNAMES
        do
            srun -w ${list[$i]} -n1 -N1 --exclusive $PYTHON_PATH $SCRIPT_DIR/frequency.py -c $ii -pop $j &
        done
    done
}

set -x 
LOCAL_CLEANUP
hostname;date;

echo "Making directory at $CURRENT_DIR ..."
srun -n$NUM_NODES -w $host_list --exclusive mkdir -p $CURRENT_DIR


total_start_time=$SECONDS

cd $CURRENT_DIR

# Stage 1 : Individuals
start_time=$SECONDS
START_INDIVIDUALS
wait
duration=$(($SECONDS - $start_time))
echo "individuals : $(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed ($duration secs)."


# Stage 2 : Individuals merge + Sifting
start_time=$SECONDS
START_INDIVIDUALS_MERGE

START_SIFTING
wait
duration=$(($SECONDS - $start_time))
echo "individuals_merge+sifting : $(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed ($duration secs)."

# Stage 3 : Mutation overlap + Frequency
# sleep 30
start_time=$SECONDS
START_MUTATION_OVERLAP

START_FREQUENCY
wait
duration=$(($SECONDS - $start_time))
echo "mutation+frequency : $(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed ($duration secs)."

total_duration=$(($SECONDS - $total_start_time))
echo "All done : $(($total_duration / 60)) minutes and $(($total_duration % 60)) seconds elapsed ($total_duration secs)."

set -x

# # clear intermediate output
# rm -f $CURRENT_DIR/chr*n-*.tar.gz $CURRENT_DIR/tmp*


# check output
echo "Checking all output ----------------"
srun -n$NUM_NODES -w $host_list --exclusive du -h $CURRENT_DIR

# Candice: do not remove the current dir which contains all initial input for the test run
# # remove current dir
# rm -fr $CURRENT_DIR/* 


hostname;date;
sacct -j $SLURM_JOB_ID -o jobid,submit,start,end,state