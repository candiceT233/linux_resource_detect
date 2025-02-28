#!/bin/sh
#SBATCH --job-name=beegfs_pior_r_buffered_32n
#SBATCH --partition=slurm
#SBATCH --time=8:00:00
#SBATCH -N 32
#SBATCH --output=./ior_%x_R.out
#SBATCH --error=./ior_%x_R.err
#SBATCH -A datamesh

<<COMMENT
## IOR sequential write layout:
Position in file -->
|rank0                    |rank1                    |
|transferSize|transferSize|transferSize|transferSize|
|blockSize                |blockSize                |
|segmentCount                                       |


IOR Flag notes:
-a POSIX: api using POSIX for I/O [POSIX|MPIIO|HDF5|HDFS|S3|S3_EMC|NCMPI|RADOS]
-w      : writeFile – write file
-r      : readFile – read existing file
-t      : transferSize
-b      : blockSize
-s      : segmentCount
-i      : repetitions – number of repetitions of test
-e      : fsync – perform fsync upon POSIX write close (TODO: this may not be necessary)
-o      : testFile – full name for test
-F      : filePerProc – file-per-process
-Y      : fsyncPerWrite – perform fsync after each POSIX write (TODO: this may not be necessary)
-C      : reorderTasksConstant – changes task ordering to n+1 ordering for readback (only in multitasks)
-k	    : keepFile – don’t remove the test file(s) on program exit
-O      : string of IOR directives (e.g. -O checkRead=1,GPUid=2,summaryFormat=CSV)
-useO_DIRECT:use direct I/ for POSIX, bypassing I/O buffers (default: 0)

## Unused 
-summaryAlways:Always print the long summary for each test even if the job is interrupted. (default: 0)
-f S    : scriptFile – test script name
-g      : intraTestBarriers – use barriers between open, write/read, and close
-q	    : quitOnError – during file error-checking, abort on error (incompatible with IOR-3.3.0)

COMMENT



# TEST_DIR="$1"
#DROP_CACHE_CMD="$3"
DROP_CACHE_CMD="sudo /sbin/sysctl vm.drop_caches=3"

# # Print Usage
# if [ $# -ne 1 ]; then
#     echo "Usage: $0 <io_test_dir> <drop_cache_cmd>"
#     echo "Example: $0 /mnt/nvme/$USER"
#     exit 1
# fi

# TEST_DIR="///scratch/$USER"
TEST_DIR="///rcfs/projects/chess/$USER"
# TEST_DIR="/dev/shm/$USER/$(pwd)"
mkdir $TEST_DIR
RESULT_DIR="$HOME/scripts/linux_resource_detect/io_test/pnnl_deception_slurm/beegfs_pior_r_buffered_32n"


# Check if paths are valid
if [ ! -d "$TEST_DIR" ]; then
    echo "Directory $TEST_DIR does not exist"
    echo "Creating directory $TEST_DIR"
    mkdir -p $TEST_DIR
fi

LOG_FILE=./beegfs_pior_r_test.log

spack load ior

mkdir -p $RESULT_DIR
cd $RESULT_DIR

# Parallelism 1, 4, 8, 16, 32, 64, 128
# 1024/1=1024
# 1024/4=256
# 1024/8=128
# 1024/16=64
# 1024/32=32
# 1024/64=16
# 1024/128=8

## Prepare Slurm Host Names and IPs
NODE_NAMES=`echo $SLURM_JOB_NODELIST|scontrol show hostnames`
hostlist=$(echo "$NODE_NAMES" | tr '\n' ',')
echo "hostlist: $hostlist"

RUN_IOR_MEM_DISK_TEST(){
    # All blockSize is default at 1MB

    # Run IOR 1GB
    FS="$TEST_DIR/iortest_1gb"
    echo "Testing $FS"
    mkdir -p $FS
    sudo /sbin/sysctl vm.drop_caches=3
    
    for tsize in 64 4k 1m 4m 16m 1k 64m 256m 1024m ; do
        for trial in 1 2 3; do
            for ntask in 512; do #4 8 16 32 64 128 256; do

                # io_size=$((1*64*64/ntask))
                # convert tsize from mb to bytes
                if [[ $tsize == *k ]]; then
                    tsize_byte=$(echo $tsize | sed 's/k//')
                    # tsize_byte=$((tsize_byte*1024))
                    echo "k: tsize_byte=$tsize_byte"
                    io_size=$((1*1024*1024/tsize_byte))
                elif [[ $tsize == *m ]]; then
                    tsize_byte=$(echo $tsize | sed 's/m//')
                    # tsize_byte=$((tsize_byte))
                    echo "m: tsize_byte=$tsize_byte"
                    io_size=$((1*1024/tsize_byte))
                    echo "io_size=$io_size"
                else
                    io_size=$((1/tsize)) # for 64
                fi

                test_name="pior_r_${tsize}_1gb_n${ntask}_${trial}"
                test_file="$FS/${test_name}.bin"
                echo "Testing $tsize ntask=$ntask"

                # if tsize larger than 1m, use tsize as blockSize
                if [[ $tsize == *m ]]; then
                    # devide 5GB by ntask
                    segmentCount=$((io_size/ntask))
                    echo "mpirun --oversubscribe -n $ntask -host $hostlist ior -a POSIX -w -r -z -t $tsize -b $tsize -s $segmentCount -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json"
                    mpirun --oversubscribe -n $ntask -host $hostlist ior -a POSIX -w -r -z -t $tsize -b $tsize -s $segmentCount -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json
                else
                    segmentCount=$((1*1024/ntask))
                    echo "mpirun --oversubscribe -n $ntask -host $hostlist ior -a POSIX -w -r -z -t $tsize -s $segmentCount -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json"
                    mpirun --oversubscribe -n $ntask -host $hostlist ior -a POSIX -w -r -z -t $tsize -s $segmentCount -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json
                fi
                sudo /sbin/sysctl vm.drop_caches=3
                sleep 5
            done
        done
    done
    # Clean up test dir
    rm -rf $FS

    # Run IOR 5GB
    FS="$TEST_DIR/iortest_5gb"
    echo "Testing $FS"
    mkdir -p $FS
    sudo /sbin/sysctl vm.drop_caches=3
    for tsize in 1k 4k 1m 4m 16m 64m 256m 1024m; do # 
        for trial in 1 2 3; do
            for ntask in 512; do #4 8 16 32 64 128 256; do

                # io_size=$((5*64*64/ntask))
                # convert tsize from mb to bytes
                if [[ $tsize == *k ]]; then
                    tsize_byte=$(echo $tsize | sed 's/k//')
                    # tsize_byte=$((tsize_byte*1024))
                    echo "k: tsize_byte=$tsize_byte"
                    io_size=$((5*1024*1024/tsize_byte))
                elif [[ $tsize == *m ]]; then
                    tsize_byte=$(echo $tsize | sed 's/m//')
                    # tsize_byte=$((tsize_byte))
                    echo "m: tsize_byte=$tsize_byte"
                    io_size=$((5*1024/tsize_byte))
                    echo "io_size=$io_size"
                else
                    io_size=$((5/tsize)) # for 64
                fi

                test_name="pior_r_${tsize}_5gb_n${ntask}_${trial}"
                test_file="$FS/${test_name}.bin"
                echo "Testing $tsize ntask=$ntask"

                # if tsize larger than 1m, use tsize as blockSize
                if [[ $tsize == *m ]]; then
                    # devide 5GB by ntask
                    segmentCount=$((io_size/ntask))
                    echo "mpirun --oversubscribe -n $ntask -host $hostlist ior -a POSIX -w -r -z -t $tsize -b $tsize -s $segmentCount -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json"
                    mpirun --oversubscribe -n $ntask -host $hostlist ior -a POSIX -w -r -z -t $tsize -b $tsize -s $segmentCount -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json
                else
                    segmentCount=$((5*1024/ntask))
                    echo "mpirun --oversubscribe -n $ntask -host $hostlist ior -a POSIX -w -r -z -t $tsize -s $segmentCount -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json"
                    mpirun --oversubscribe -n $ntask -host $hostlist ior -a POSIX -w -r -z -t $tsize -s $segmentCount -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json
                fi
                sudo /sbin/sysctl vm.drop_caches=3
                sleep 5
            done
        done
    done
    # Clean up test dir
    rm -rf $FS



    # Run IOR 50GB
    FS="$TEST_DIR/iortest_50gb"
    echo "Testing $FS"
    mkdir -p $FS
    sudo /sbin/sysctl vm.drop_caches=3
    for tsize in 1k 4k 1m 4m 16m 64m 256m 1024m; do # 
        for trial in 1 2 3; do
            for ntask in 512; do #4 8 16 32 64 128 256; do

                # io_size=$((5*64*64/ntask))
                # convert tsize from mb to bytes
                if [[ $tsize == *k ]]; then
                    tsize_byte=$(echo $tsize | sed 's/k//')
                    # tsize_byte=$((tsize_byte*1024))
                    echo "k: tsize_byte=$tsize_byte"
                    io_size=$((50*1024*1024/tsize_byte))
                elif [[ $tsize == *m ]]; then
                    tsize_byte=$(echo $tsize | sed 's/m//')
                    # tsize_byte=$((tsize_byte))
                    echo "m: tsize_byte=$tsize_byte"
                    io_size=$((50*1024/tsize_byte))
                    echo "io_size=$io_size"
                else
                    io_size=$((50/tsize)) # for 64
                fi

                test_name="pior_r_${tsize}_50gb_n${ntask}_${trial}"
                test_file="$FS/${test_name}.bin"
                echo "Testing $tsize ntask=$ntask"

                # if tsize larger than 1m, use tsize as blockSize
                if [[ $tsize == *m ]]; then
                    # devide 1GB by ntask
                    segmentCount=$((io_size/ntask))
                    echo "mpirun --oversubscribe -n $ntask -host $hostlist ior -a POSIX -w -r -z -t $tsize -b $tsize -s $segmentCount -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json"
                    mpirun --oversubscribe -n $ntask -host $hostlist ior -a POSIX -w -r -z -t $tsize -b $tsize -s $segmentCount -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json
                else
                    segmentCount=$((50*1024/ntask))
                    echo "mpirun --oversubscribe -n $ntask -host $hostlist ior -a POSIX -w -r -z -t $tsize -s $segmentCount -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json"
                    mpirun --oversubscribe -n $ntask -host $hostlist ior -a POSIX -w -r -z -t $tsize -s $segmentCount -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json
                fi
                sudo /sbin/sysctl vm.drop_caches=3
                sleep 5
            done
        done
    done
    # Clean up test dir
    rm -rf $FS


    # # Run IOR 100GB
    # FS="$TEST_DIR/iortest_100gb"
    # echo "Testing $FS"
    # mkdir -p $FS
    # sudo /sbin/sysctl vm.drop_caches=3

    # for tsize in 1k 4k 1m 4m 16m 64m 256m 1024m; do # 
    #     for trial in 1 2 3; do
    #         for ntask in 512; do #4 8 16 32 64 128 256; do
    #             # io_size=$((5*64*64/ntask))
    #             # convert tsize from mb to bytes
    #             total_size=100*1024
    #             if [[ $tsize == *k ]]; then
    #                 tsize_byte=$(echo $tsize | sed 's/k//')
    #                 # tsize_byte=$((tsize_byte*1024))
    #                 echo "k: tsize_byte=$tsize_byte"
    #                 io_size=$((total_size/tsize_byte))
    #             elif [[ $tsize == *m ]]; then
    #                 tsize_byte=$(echo $tsize | sed 's/m//')
    #                 # tsize_byte=$((tsize_byte))
    #                 echo "m: tsize_byte=$tsize_byte"
    #                 io_size=$((total_size/tsize_byte))
    #                 echo "io_size=$io_size"
    #             else
    #                 io_size=$((total_size/tsize)) # for 64
    #             fi

    #             test_name="pior_r_${tsize}_100gb_n${ntask}_${trial}"
    #             test_file="$FS/${test_name}.bin"
    #             echo "Testing $tsize ntask=$ntask"

    #             # if tsize larger than 1m, use tsize as blockSize
    #             if [[ $tsize == *m ]]; then
    #                 # devide 1GB by ntask
    #                 segmentCount=$((io_size/ntask))
    #                 echo "mpirun --oversubscribe -n $ntask -host $hostlist ior -a POSIX -w -r -z -t $tsize -b $tsize -s $segmentCount -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json"
    #                 mpirun --oversubscribe -n $ntask -host $hostlist ior -a POSIX -w -r -z -t $tsize -b $tsize -s $segmentCount -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json
    #             else
    #                 segmentCount=$((total_size/ntask))
    #                 echo "mpirun --oversubscribe -n $ntask -host $hostlist ior -a POSIX -w -r -z -t $tsize -s $segmentCount -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json"
    #                 mpirun --oversubscribe -n $ntask -host $hostlist ior -a POSIX -w -r -z -t $tsize -s $segmentCount -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json
    #             fi
    #             sudo /sbin/sysctl vm.drop_caches=3
    #             sleep 5
    #         done
    #     done
    # done
    # # Clean up test dir
    # rm -rf $FS

    # # Run IOR 300GB
    # FS="$TEST_DIR/iortest_300gb"
    # echo "Testing $FS"
    # mkdir -p $FS
    # sudo /sbin/sysctl vm.drop_caches=3

    # for tsize in 1k 4k 1m 4m 16m 64m 256m 1024m; do # 
    #     for trial in 1 2 3; do
    #         for ntask in 64 128; do # 4 8 16 32
    #             # io_size=$((5*64*64/ntask))
    #             # convert tsize from mb to bytes
    #             total_size=300*1024
    #             if [[ $tsize == *k ]]; then
    #                 tsize_byte=$(echo $tsize | sed 's/k//')
    #                 # tsize_byte=$((tsize_byte*1024))
    #                 echo "k: tsize_byte=$tsize_byte"
    #                 io_size=$((total_size/tsize_byte))
    #             elif [[ $tsize == *m ]]; then
    #                 tsize_byte=$(echo $tsize | sed 's/m//')
    #                 # tsize_byte=$((tsize_byte))
    #                 echo "m: tsize_byte=$tsize_byte"
    #                 io_size=$((total_size/tsize_byte))
    #                 echo "io_size=$io_size"
    #             else
    #                 io_size=$((total_size/tsize)) # for 64
    #             fi

    #             test_name="pior_r_${tsize}_300gb_n${ntask}_${trial}"
    #             test_file="$FS/${test_name}.bin"
    #             echo "Testing $tsize ntask=$ntask"

    #             # if tsize larger than 1m, use tsize as blockSize
    #             if [[ $tsize == *m ]]; then
    #                 # devide 1GB by ntask
    #                 segmentCount=$((io_size/ntask))
    #                 echo "mpirun --oversubscribe -n $ntask -host $hostlist ior -a POSIX -w -r -z -t $tsize -b $tsize -s $segmentCount -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json"
    #                 mpirun --oversubscribe -n $ntask -host $hostlist ior -a POSIX -w -r -z -t $tsize -b $tsize -s $segmentCount -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json
    #             else
    #                 segmentCount=$((total_size/ntask))
    #                 echo "mpirun --oversubscribe -n $ntask -host $hostlist ior -a POSIX -w -r -z -t $tsize -s $segmentCount -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json"
    #                 mpirun --oversubscribe -n $ntask -host $hostlist ior -a POSIX -w -r -z -t $tsize -s $segmentCount -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json
    #             fi
    #             sudo /sbin/sysctl vm.drop_caches=3
    #             sleep 5
    #         done
    #     done
    # done
    # # Clean up test dir
    # rm -rf $FS

    # # Run IOR 500GB
    # FS="$TEST_DIR/iortest_500gb"
    # echo "Testing $FS"
    # mkdir -p $FS
    # sudo /sbin/sysctl vm.drop_caches=3

    # for tsize in 1k 4k 1m; do
    #     for trial in 1 2 3; do
    #         for ntask in 512; do #4 8 16 32 64 128 256; do
    #             io_size=$((512000/ntask))
    #             echo "Testing $tsize ntask=$ntask"
    #             test_name="pior_r_${tsize}_50gb_n${ntask}_${trial}"
    #             test_file="$FS/${test_name}.bin"
    #             mpirun -n $ntask ior -a POSIX -w -r -t $tsize -s $io_size -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json
    #             sudo /sbin/sysctl vm.drop_caches=3
    #             sleep 5
    #         done
    #     done
    # done

}

sudo /sbin/sysctl vm.drop_caches=3
RUN_IOR_MEM_DISK_TEST | tee $LOG_FILE

