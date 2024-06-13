#!/bin/bash

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



TEST_DIR="$1"
#DROP_CACHE_CMD="$3"
# DROP_CACHE_CMD="sudo /sbin/sysctl vm.drop_caches=3"
DROP_CACHE_CMD="sudo drop_caches"

# Print Usage
if [ $# -ne 1 ]; then
    echo "Usage: $0 <io_test_dir> <drop_cache_cmd>"
    echo "Example: $0 /mnt/nvme/$USER"
    exit 1
fi


# Check if paths are valid
if [ ! -d "$TEST_DIR" ]; then
    echo "Directory $TEST_DIR does not exist"
    exit 1
fi

LOG_FILE=./iops_test.log

spack load ior


RUN_IOR_MEM_DISK_TEST(){
    # All blockSize is default at 1MB

    # Run IOR 1GB
    FS="$TEST_DIR/iortest_1gb"
    echo "Testing $FS"
    mkdir -p $FS
    sudo drop_caches
    
    for tsize in 64 1k 4k 1m 4m; do
        for trial in 1 2 3; do
            echo "Testing $tsize"
            test_name="ior_${tsize}_1gb_${trial}"
            test_file="$FS/${test_name}.bin"
            ior -a POSIX -useO_DIRECT -w -r -t $tsize -s 1024 -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json
            sudo drop_caches
            sleep 5
        done
    done
    # Clean up test dir
    rm -rf $FS

    # Run IOR 4GB
    FS="$TEST_DIR/iortest_4gb"
    echo "Testing $FS"
    mkdir -p $FS
    sudo drop_caches

    for tsize in 64 1k 4k 1m 4m; do
        for trial in 1 2 3; do
            echo "Testing $tsize"
            test_name="ior_${tsize}_4gb_${trial}"
            test_file="$FS/${test_name}.bin"
            ior -a POSIX -useO_DIRECT -w -r -t $tsize -s 4096 -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json
            sudo drop_caches
            sleep 5
        done
    done
    # Clean up test dir
    rm -rf $FS

    # Run IOR 16GB (4*4)
    FS="$TEST_DIR/iortest_16gb"
    echo "Testing $FS"
    mkdir -p $FS
    sudo drop_caches

    for tsize in 64 1k 4k 1m 4m; do
        for trial in 1 2 3; do
            echo "Testing $tsize"
            test_name="ior_${tsize}_16gb_${trial}"
            test_file="$FS/${test_name}.bin"
            ior -a POSIX -useO_DIRECT -w -r -t $tsize -s 16384 -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json
            sudo drop_caches
            sleep 5
        done
    done
    # Clean up test dir
    rm -rf $FS

    # Run IOR 32GB (4*8)
    FS="$TEST_DIR/iortest_32gb"
    echo "Testing $FS"
    mkdir -p $FS
    sudo drop_caches

    for tsize in 1k 4k 1m 4m; do
        for trial in 1 2 3; do
            echo "Testing $tsize"
            test_name="ior_${tsize}_32gb_${trial}"
            test_file="$FS/${test_name}.bin"
            ior -a POSIX -useO_DIRECT -w -r -t $tsize -s 32768 -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json
            sudo drop_caches
            sleep 5
        done
    done

    # Run IOR 64GB (4*16)
    FS="$TEST_DIR/iortest_64gb"
    echo "Testing $FS"
    mkdir -p $FS
    sudo drop_caches

    for tsize in 1k 4k 1m 4m; do
        for trial in 1 2 3; do
            echo "Testing $tsize"
            test_name="ior_${tsize}_64gb_${trial}"
            test_file="$FS/${test_name}.bin"
            ior -a POSIX -useO_DIRECT -w -r -t $tsize -s 65536 -e -F -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json
            sudo drop_caches
            sleep 5
        done
    done
    # Clean up test dir
    rm -rf $FS

}

sudo drop_caches
RUN_IOR_MEM_DISK_TEST | tee $LOG_FILE

