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
# DROP_CACHE_CMD="$2"
DROP_CACHE_CMD="sudo /sbin/sysctl vm.drop_caches=3"

# Print Usage
if [ $# -ne 2 ]; then
    echo "Usage: $0 <io_test_dir> <drop_cache_cmd>"
    echo "Example: $0 /mnt/nvme \"sudo echo 3 > /proc/sys/vm/drop_caches\""
    exit 1
fi


# Check if paths are valid
if [ ! -d "$TEST_DIR" ]; then
    echo "Directory $TEST_DIR does not exist"
    exit 1
fi

LOG_FILE=./iops_test.log

spack load ior

RUN_IOR (){
    for FS in "$TEST_DIR"; do
        FS="$FS/iortest" # add iortest folder to path
        echo "Testing $FS"
        mkdir -p $FS
        for tsize in 64 2k 4k 8k; do
            echo "Testing $tsize"

            for tasks in 1 2 5 10 20 40 80 160 320 #40 80 160 320; do #1 5 10 20; do #2 3; do # {1..3}
            do 
                echo "Number of Tasks: $tasks"
                test_name="ior_${tsize}_n${tasks}"

                test_file="$FS/${test_name}.bin"
                
                rm $test_file 2> /dev/null
                `$DROP_CACHE_CMD`
                
                mpirun -n $tasks --oversubscribe ior -a POSIX -w -r -t $tsize -s 4 -F -k -i 3 -o $test_file -O summaryFormat=JSON -O summaryFile=${test_name}.json

                rm -rf $actual_test_file 2> /dev/null
                `$DROP_CACHE_CMD`
                sleep 5

            done
        done
        echo ""
        echo "$FS tests done -----------------"
    done
}



RUN_IOR | tee $LOG_FILE
