#!/bin/sh
#SBATCH --job-name=localssd_ior_test
#SBATCH --partition=slurm
#SBATCH --time=8:00:00
#SBATCH -N 1
#SBATCH --output=./ior_%x_R.out
#SBATCH --error=./ior_%x_R.err
#SBATCH -A oddite

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

TEST_DIR="///scratch/$USER"
RESULT_DIR="$HOME/scripts/linux_resource_detect/io_test/pnnl_deception_slurm/local_ssd_ior_buffered"


# Check if paths are valid
if [ ! -d "$TEST_DIR" ]; then
    echo "Directory $TEST_DIR does not exist"
    echo "Creating directory $TEST_DIR"
    mkdir -p $TEST_DIR
fi

LOG_FILE=./iops_test.log

spack load ior

mkdir -p $RESULT_DIR
cd $RESULT_DIR

RUN_IOR_MEM_DISK_TEST(){
    # All blockSize is default at 1MB

    # # Run IOR 4MB test
    # FS="$TEST_DIR/iortest_4mb"
    # echo "Testing $FS"
    # mkdir -p $FS
    # sudo /sbin/sysctl vm.drop_caches=3
    
    # for tsize in 64 1k 4k 1m; do
    #     for trial in 1 2 3; do
    #         echo "Testing $tsize"
    #         test_name="ior_${tsize}_4mb_${trial}"
    #         test_file="$FS/${test_name}.bin"
    #         ior -a POSIX -w -r -t $tsize -s 4 -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json
    #         sudo /sbin/sysctl vm.drop_caches=3
    #         sleep 5
    #     done
    # done
    # # Clean up test dir
    # rm -rf $FS

    # # Run IOR 16MB test
    # FS="$TEST_DIR/iortest_16mb"
    # echo "Testing $FS"
    # mkdir -p $FS
    # sudo /sbin/sysctl vm.drop_caches=3
    
    # for tsize in 64 1k 4k 1m; do
    #     for trial in 1 2 3; do
    #         echo "Testing $tsize"
    #         test_name="ior_${tsize}_16mb_${trial}"
    #         test_file="$FS/${test_name}.bin"
    #         ior -a POSIX -w -r -t $tsize -s 16 -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json
    #         sudo /sbin/sysctl vm.drop_caches=3
    #         sleep 5
    #     done
    # done
    # # Clean up test dir
    # rm -rf $FS

    # # Run IOR 64MB test
    # FS="$TEST_DIR/iortest_64mb"
    # echo "Testing $FS"
    # mkdir -p $FS
    # sudo /sbin/sysctl vm.drop_caches=3
    
    # for tsize in 64 1k 4k 1m; do
    #     for trial in 1 2 3; do
    #         echo "Testing $tsize"
    #         test_name="ior_${tsize}_64mb_${trial}"
    #         test_file="$FS/${test_name}.bin"
    #         ior -a POSIX -w -r -t $tsize -s 64 -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json
    #         sudo /sbin/sysctl vm.drop_caches=3
    #         sleep 5
    #     done
    # done
    # # Clean up test dir
    # rm -rf $FS

    # # Run IOR 256MB test
    # FS="$TEST_DIR/iortest_256mb"
    # echo "Testing $FS"
    # mkdir -p $FS
    # sudo /sbin/sysctl vm.drop_caches=3
    
    # for tsize in 64 1k 4k 1m; do
    #     for trial in 1 2 3; do
    #         echo "Testing $tsize"
    #         test_name="ior_${tsize}_256mb_${trial}"
    #         test_file="$FS/${test_name}.bin"
    #         ior -a POSIX -w -r -t $tsize -s 256 -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json
    #         sudo /sbin/sysctl vm.drop_caches=3
    #         sleep 5
    #     done
    # done
    # # Clean up test dir
    # rm -rf $FS

    # # Run IOR 512MB test
    # FS="$TEST_DIR/iortest_512mb"
    # echo "Testing $FS"
    # mkdir -p $FS
    # sudo /sbin/sysctl vm.drop_caches=3

    # for tsize in 64 1k 4k 1m; do
    #     for trial in 1 2 3; do
    #         echo "Testing $tsize"
    #         test_name="ior_${tsize}_512mb_${trial}"
    #         test_file="$FS/${test_name}.bin"
    #         ior -a POSIX -w -r -t $tsize -s 512 -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json
    #         sudo /sbin/sysctl vm.drop_caches=3
    #         sleep 5
    #     done
    # done
    # # Clean up test dir
    # rm -rf $FS

    # Run IOR 1GB
    FS="$TEST_DIR/iortest_1gb"
    echo "Testing $FS"
    mkdir -p $FS
    sudo /sbin/sysctl vm.drop_caches=3
    
    for tsize in 4m 16m 64m 256m 1024m; do # 64 1k 4k 1m 
        for trial in 1 2 3; do
            test_name="ior_${tsize}_1gb_${trial}"
            test_file="$FS/${test_name}.bin"

            # convert tsize from mb to bytes
            if [[ $tsize == *k ]]; then
                tsize_byte=$(echo $tsize | sed 's/k//')
                tsize_byte=$((tsize_byte*1024))
            elif [[ $tsize == *m ]]; then
                tsize_byte=$(echo $tsize | sed 's/m//')
                tsize_byte=$((tsize_byte*1024*1024))
            fi

            segmentCount=$((1024*1024*1024/tsize_byte))

            echo "Testing $tsize with segment count $segmentCount"
            echo "ior -a POSIX -w -r -t $tsize -s $segmentCount -b $tsize -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json"
            # ior -a POSIX -w -r -t $tsize -s 1024 -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json
            ior -a POSIX -w -r -t $tsize -s $segmentCount -b $tsize -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json
            sudo /sbin/sysctl vm.drop_caches=3
            sleep 5
        done
    done
    # Clean up test dir
    rm -rf $FS

    # Run IOR 5GB
    FS="$TEST_DIR/iortest_5gb"
    echo "Testing $FS"
    mkdir -p $FS
    sudo /sbin/sysctl vm.drop_caches=3

    for tsize in 4m 16m 64m 256m 1024m; do # 64 1k 4k 1m 
        for trial in 1 2 3; do
            test_name="ior_${tsize}_5gb_${trial}"
            test_file="$FS/${test_name}.bin"

            # convert tsize from mb to bytes
            if [[ $tsize == *k ]]; then
                tsize_byte=$(echo $tsize | sed 's/k//')
                tsize_byte=$((tsize_byte*1024))
            elif [[ $tsize == *m ]]; then
                tsize_byte=$(echo $tsize | sed 's/m//')
                tsize_byte=$((tsize_byte*1024*1024))
            fi

            segmentCount=$((5*1024*1024*1024/tsize_byte))

            echo "Testing $tsize with segment count $segmentCount"
            echo "ior -a POSIX -w -r -t $tsize -s $segmentCount -b $tsize -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json"
            # ior -a POSIX -w -r -t $tsize -s 1024 -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json
            ior -a POSIX -w -r -t $tsize -s $segmentCount -b $tsize -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json
            sudo /sbin/sysctl vm.drop_caches=3
            sleep 5
        done
    done
    # Clean up test dir
    rm -rf $FS

    # Run IOR 50GB
    FS="$TEST_DIR/iortest_50gb"
    echo "Testing $FS"
    mkdir -p $FS
    sudo /sbin/sysctl vm.drop_caches=3

    for tsize in 4m 16m 64m 256m 1024m; do # 64 1k 4k 1m 
        for trial in 1 2 3; do
            test_name="ior_${tsize}_50gb_${trial}"
            test_file="$FS/${test_name}.bin"

            # convert tsize from mb to bytes
            if [[ $tsize == *k ]]; then
                tsize_byte=$(echo $tsize | sed 's/k//')
                tsize_byte=$((tsize_byte*1024))
            elif [[ $tsize == *m ]]; then
                tsize_byte=$(echo $tsize | sed 's/m//')
                tsize_byte=$((tsize_byte*1024*1024))
            fi

            segmentCount=$((50*1024*1024*1024/tsize_byte))

            echo "Testing $tsize with segment count $segmentCount"
            echo "ior -a POSIX -w -r -t $tsize -s $segmentCount -b $tsize -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json"
            # ior -a POSIX -w -r -t $tsize -s 1024 -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json
            ior -a POSIX -w -r -t $tsize -s $segmentCount -b $tsize -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json
            sudo /sbin/sysctl vm.drop_caches=3
            sleep 5
        done
    done
    # Clean up test dir
    rm -rf $FS

    # Run IOR 100GB
    FS="$TEST_DIR/iortest_100gb"
    echo "Testing $FS"
    mkdir -p $FS
    sudo /sbin/sysctl vm.drop_caches=3

    for tsize in 4m 16m 64m 256m 1024m; do # 64 1k 4k 1m 
        for trial in 1 2 3; do
            test_name="ior_${tsize}_100gb_${trial}"
            test_file="$FS/${test_name}.bin"

            # convert tsize from mb to bytes
            if [[ $tsize == *k ]]; then
                tsize_byte=$(echo $tsize | sed 's/k//')
                tsize_byte=$((tsize_byte*1024))
            elif [[ $tsize == *m ]]; then
                tsize_byte=$(echo $tsize | sed 's/m//')
                tsize_byte=$((tsize_byte*1024*1024))
            fi

            segmentCount=$((100*1024*1024*1024/tsize_byte))

            echo "Testing $tsize with segment count $segmentCount"
            echo "ior -a POSIX -w -r -t $tsize -s $segmentCount -b $tsize -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json"
            # ior -a POSIX -w -r -t $tsize -s 1024 -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json
            ior -a POSIX -w -r -t $tsize -s $segmentCount -b $tsize -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json
            sudo /sbin/sysctl vm.drop_caches=3
            sleep 5
        done
    done
    # Clean up test dir
    rm -rf $FS

    # Run IOR 300GB
    FS="$TEST_DIR/iortest_300gb"
    echo "Testing $FS"
    mkdir -p $FS
    sudo /sbin/sysctl vm.drop_caches=3

    for tsize in 4m 16m 64m 256m 1024m; do # 64 1k 4k 1m 
        for trial in 1 2 3; do
            test_name="ior_${tsize}_300gb_${trial}"
            test_file="$FS/${test_name}.bin"

            # convert tsize from mb to bytes
            if [[ $tsize == *k ]]; then
                tsize_byte=$(echo $tsize | sed 's/k//')
                tsize_byte=$((tsize_byte*1024))
            elif [[ $tsize == *m ]]; then
                tsize_byte=$(echo $tsize | sed 's/m//')
                tsize_byte=$((tsize_byte*1024*1024))
            fi

            segmentCount=$((300*1024*1024*1024/tsize_byte))

            echo "Testing $tsize with segment count $segmentCount"
            echo "ior -a POSIX -w -r -t $tsize -s $segmentCount -b $tsize -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json"
            # ior -a POSIX -w -r -t $tsize -s 1024 -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json
            ior -a POSIX -w -r -t $tsize -s $segmentCount -b $tsize -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json
            sudo /sbin/sysctl vm.drop_caches=3
            sleep 5
        done
    done
    # Clean up test dir
    rm -rf $FS

    # # Run IOR 500GB
    # FS="$TEST_DIR/iortest_500gb"
    # echo "Testing $FS"
    # mkdir -p $FS
    # sudo /sbin/sysctl vm.drop_caches=3

    # for tsize in 1k 4k 1m; do
    #     for trial in 1 2 3; do
    #         echo "Testing $tsize"
    #         test_name="ior_${tsize}_500gb_${trial}"
    #         test_file="$FS/${test_name}.bin"
    #         ior -a POSIX -w -r -t $tsize -s 512000 -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json
    #         sudo /sbin/sysctl vm.drop_caches=3
    #         sleep 5
    #     done
    # done

}

sudo /sbin/sysctl vm.drop_caches=3
RUN_IOR_MEM_DISK_TEST | tee $LOG_FILE

