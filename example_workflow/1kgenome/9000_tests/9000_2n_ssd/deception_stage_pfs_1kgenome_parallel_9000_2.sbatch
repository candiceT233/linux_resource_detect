#!/bin/bash
#SBATCH --job-name="deception_2nodes_ssd_9000_2"
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
LOCAL="SSD" # SHM SSD

if [ "$LOCAL" == "SHM" ]
then
    echo "Running on ramdisk"; export LOCAL_STORE=/dev/shm/$USER #shm
else
    echo "Running on SSD"; export LOCAL_STORE=/scratch/$USER
fi

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
    if ! [ -s "$SCRIPT_DIR" ]; then cp -r /qfs/projects/oddite/tang584/1000genome-workflow/bin/* $SCRIPT_DIR/; fi
    if ! [ -s "$CURRENT_DIR" ]; then cp -r /qfs/people/tang584/scripts/1kgenome_sbatch_deception/* $CURRENT_DIR/; fi
fi

# /files0/oddite/$USER/1kgenome_sbatch #SSD Burst Buffer

CHROMOSOMES=10
NUM_NODES=$SLURM_JOB_NUM_NODES

ITERATION=$(( $CHROMOSOMES / $NUM_NODES -1 ))


PROBLEM_SIZE=300 # the maximum number of tasks within a stage !!!need to modify as needed!!!
# the `SBATCH -N -n` needs to modify as well !!!

NUM_TASKS_PER_NODE=$(((PROBLEM_SIZE+NUM_TASKS_PER_NODE)/NUM_NODES)) # (fixed) This is the max number of cores per node
#NUM_NODES=$(((PROBLEM_SIZE+NUM_TASKS_PER_NODE-1)/NUM_TASKS_PER_NODE))
echo "PROBLEM SIZE: $PROBLEM_SIZE NUM_TASKS_PER_NODE: $NUM_TASKS_PER_NODE NUM_NODES: $NUM_NODES"

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

LOCAL_CLEANUP () {

    echo "Cleaning up local data at $LOCAL_STORE with $host_list ..."
    srun -n$NUM_NODES -w $host_list --exclusive rm -fr $LOCAL_STORE/*
}

STAGE_INDIVIDUALS () {
    echo "Staging individuals data to $LOCAL_STORE with $host_list ..."
    # modified to have targeted stage-in
    for i in $(seq 0 9)
    do
        node_idx=$(($i % $NUM_NODES))
        running_node=${list[$node_idx]}
        let ii=i+1
        echo "staging ALL.chr${ii}.250000.vcf into node $running_node"
        srun -n1 -N1 -w $running_node --exclusive cp $CURRENT_DIR/columns.txt $LOCAL_STORE/ &
        srun -n1 -N1 -w $running_node --exclusive cp $CURRENT_DIR/ALL.chr${ii}.250000.vcf $LOCAL_STORE/ &
        srun -n1 -N1 -w $running_node --exclusive cp $CURRENT_DIR/ALL.chr${ii}.phase3_shapeit2_mvncall_integrated_v5.20130502.sites.annotation.vcf $LOCAL_STORE/ &
        # srun -n1 -w $running_node --exclusive echo $(ls -l $LOCAL_STORE/*.vcf)
    done

    # srun -n$NUM_NODES -w $host_list --exclusive cp $CURRENT_DIR/ALL.chr*.250000.vcf $LOCAL_STORE/ &

    FNAMES=("SAS EAS GBR AMR AFR EUR ALL")
    for fn in $FNAMES
    do
        srun -n$NUM_NODES -w $host_list --exclusive cp $CURRENT_DIR/$fn $LOCAL_STORE/ &
    done
}

START_INDIVIDUALS() {
    # set -x

    counter=0
    CHROM_START=$1
    CHROM_END=$(($2 -1))

    t_count=1

    for i in $(seq $CHROM_START $CHROM_END)
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
                echo srun -w $running_node -n1 -N1 --exclusive $SCRIPT_DIR/individuals_shm.py $LOCAL_STORE/ALL.chr${ii}.250000.vcf $ii $((1+j*300)) $((301+j*300)) 9000 &
                srun -w $running_node -n1 -N1 --exclusive $SCRIPT_DIR/individuals_shm.py $LOCAL_STORE/ALL.chr${ii}.250000.vcf $ii $((1+j*300)) $((301+j*300)) 9000 &

                counter=$(($counter + 1))
                # echo "counter: $counter"

            fi
	done
    done
    # sleep 3
    set +x

}

START_INDIVIDUALS_MERGE() {

    CHROM_START=$1
    CHROM_END=$(($2 -1))

    for i in $(seq $CHROM_START $CHROM_END)
    do
    node_idx=$(($i % $NUM_NODES))
    running_node=${list[$node_idx]}
	let ii=i+1
	# 10 merge tasks in total
        srun -w $running_node -n1 -N1 --exclusive $PYTHON_PATH $SCRIPT_DIR/individuals_merge_shm.py $ii $LOCAL_STORE/chr${ii}n-1-301.tar.gz $LOCAL_STORE/chr${ii}n-301-601.tar.gz $LOCAL_STORE/chr${ii}n-601-901.tar.gz $LOCAL_STORE/chr${ii}n-901-1201.tar.gz $LOCAL_STORE/chr${ii}n-1201-1501.tar.gz $LOCAL_STORE/chr${ii}n-1501-1801.tar.gz $LOCAL_STORE/chr${ii}n-1801-2101.tar.gz $LOCAL_STORE/chr${ii}n-2101-2401.tar.gz $LOCAL_STORE/chr${ii}n-2401-2701.tar.gz $LOCAL_STORE/chr${ii}n-2701-3001.tar.gz $LOCAL_STORE/chr${ii}n-3001-3301.tar.gz $LOCAL_STORE/chr${ii}n-3301-3601.tar.gz $LOCAL_STORE/chr${ii}n-3601-3901.tar.gz $LOCAL_STORE/chr${ii}n-3901-4201.tar.gz $LOCAL_STORE/chr${ii}n-4201-4501.tar.gz $LOCAL_STORE/chr${ii}n-4501-4801.tar.gz $LOCAL_STORE/chr${ii}n-4801-5101.tar.gz $LOCAL_STORE/chr${ii}n-5101-5401.tar.gz $LOCAL_STORE/chr${ii}n-5401-5701.tar.gz $LOCAL_STORE/chr${ii}n-5701-6001.tar.gz $LOCAL_STORE/chr${ii}n-6001-6301.tar.gz $LOCAL_STORE/chr${ii}n-6301-6601.tar.gz $LOCAL_STORE/chr${ii}n-6601-6901.tar.gz $LOCAL_STORE/chr${ii}n-6901-7201.tar.gz $LOCAL_STORE/chr${ii}n-7201-7501.tar.gz $LOCAL_STORE/chr${ii}n-7501-7801.tar.gz $LOCAL_STORE/chr${ii}n-7801-8101.tar.gz $LOCAL_STORE/chr${ii}n-8101-8401.tar.gz $LOCAL_STORE/chr${ii}n-8401-8701.tar.gz $LOCAL_STORE/chr${ii}n-8701-9001.tar.gz &
    done

}

START_SIFTING() {

    CHROM_START=$1
    CHROM_END=$(($2 -1))
    for i in $(seq $CHROM_START $CHROM_END)
    do
    node_idx=$(($i % $NUM_NODES))
    running_node=${list[$node_idx]}
        # 10 sifting tasks in total
	let ii=i+1
        srun -w $running_node -n1 -N1 --exclusive $PYTHON_PATH $SCRIPT_DIR/sifting.py $LOCAL_STORE/ALL.chr${ii}.phase3_shapeit2_mvncall_integrated_v5.20130502.sites.annotation.vcf $ii &
    done

}

START_MUTATION_OVERLAP() {

    FNAMES=("SAS EAS GBR AMR AFR EUR ALL")

    CHROM_START=$1
    CHROM_END=$(($2 -1))
    for i in $(seq $CHROM_START $CHROM_END)
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
    CHROM_START=$1
    CHROM_END=$(($2 -1))
    for i in $(seq $CHROM_START $CHROM_END)
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

cd $CURRENT_DIR

start_time=$SECONDS
STAGE_INDIVIDUALS
wait
duration=$(($SECONDS - $start_time))
echo "data stage-in for individuals : $(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed ($duration secs)."


# Stage 1 : Individuals
start_time=$SECONDS
for i in $(seq 0 $ITERATION)
do
    START_CHROMOSOME=$(( $i * $NUM_NODES ))
    END_CHROMOSOME=$(( $i * $NUM_NODES + $NUM_NODES ))
    echo "individuals CHROMOSOME from $START_CHROMOSOME to $END_CHROMOSOME"
    START_INDIVIDUALS $START_CHROMOSOME $END_CHROMOSOME
    wait
done
wait
duration=$(($SECONDS - $start_time))
echo "individuals : $(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed ($duration secs)."

# # check output
# echo "Checking output after START_INDIVIDUALS ----------------------------------"
# srun -n$NUM_NODES -w $host_list --exclusive ls -l $LOCAL_STORE/* &> START_INDIVIDUALS.log &

# Stage 2 : Individuals merge + Sifting
start_time=$SECONDS
for i in $(seq 0 $ITERATION)
do
    START_CHROMOSOME=$(( $i * $NUM_NODES ))
    END_CHROMOSOME=$(( $i * $NUM_NODES + $NUM_NODES ))
    echo "individuals_merge+sifting from $START_CHROMOSOME to $END_CHROMOSOME"
    START_SIFTING $START_CHROMOSOME $END_CHROMOSOME
    START_INDIVIDUALS_MERGE $START_CHROMOSOME $END_CHROMOSOME
    wait
done
wait
duration=$(($SECONDS - $start_time))
echo "individuals_merge+sifting : $(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed ($duration secs)."

# # check output
# echo "Checking output after START_SIFTING & START_INDIVIDUALS_MERGE ----------------"
# srun -n$NUM_NODES -w $host_list --exclusive ls -l $LOCAL_STORE/* &> SIFTING-INDIVIDUALS_MERGE.log &

# Stage 3 : Mutation overlap + Frequency
start_time=$SECONDS
for i in $(seq 0 $ITERATION)
do
    START_CHROMOSOME=$(( $i * $NUM_NODES ))
    END_CHROMOSOME=$(( $i * $NUM_NODES + $NUM_NODES ))
    echo "individuals_merge+sifting from $START_CHROMOSOME to $END_CHROMOSOME"

    START_MUTATION_OVERLAP $START_CHROMOSOME $END_CHROMOSOME
    START_FREQUENCY $START_CHROMOSOME $END_CHROMOSOME
    wait
done
duration=$(($SECONDS - $start_time))
echo "mutation+frequency : $(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed ($duration secs)."

total_duration=$(($SECONDS - $total_start_time))
echo "All done : $(($total_duration / 60)) minutes and $(($total_duration % 60)) seconds elapsed ($total_duration secs)."

set -x
# check output
echo "Checking all output ----------------"
srun -n$NUM_NODES -w $host_list --exclusive du -h $LOCAL_STORE

LOCAL_CLEANUP

# Candice: do not remove the current dir which contains all initial input for the test run
# # remove current dir
# rm -fr $CURRENT_DIR/* 

hostname;date;
sacct -j $SLURM_JOB_ID -o jobid,submit,start,end,state
