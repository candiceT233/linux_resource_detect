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



SHARED_PATH="$1"
LOCAL_PATH="$2"
#DROP_CACHE_CMD="$3"
DROP_CACHE_CMD="sudo /sbin/sysctl vm.drop_caches=3"

# Print Usage
if [ $# -ne 3 ]; then
    echo "Usage: $0 <shared_path> <local_path> <drop_cache_cmd>"
    echo "Example: $0 /mnt/nfs /mnt/nvme \"sudo echo 3 > /proc/sys/vm/drop_caches\""
    exit 1
fi


# Check if paths are valid
if [ ! -d "$SHARED_PATH" ]; then
    echo "Shared path $SHARED_PATH does not exist"
    exit 1
fi
if [ ! -d "$LOCAL_PATH" ]; then
    echo "Local path $LOCAL_PATH does not exist"
    exit 1
fi

LOG_FILE=./iops_test.log

spack load ior

RUN_IOR (){
    for FS in "$SHARED_PATH" "$LOCAL_PATH"; do
        FS="$FS/iortest" # add iortest folder to path
        echo "Testing $FS"
        mkdir -p $FS
        for tsize in 1k; #64 2k 4k; do
            echo "Testing $tsize"

            for trial in 1; do # {1..3}
                echo "Trial $trial"

                test_file="$FS/ior_${tsize}_${trial}.bin"
                
                rm $test_file 2> /dev/null
                `$DROP_CACHE_CMD`

                echo "Writing File:"
                ior -a POSIX -w -t $tsize -s 10 -e -F -k -e -useO_DIRECT -o $test_file

                `$DROP_CACHE_CMD`
                sleep 5

                echo "Reading File:"
                ior -a POSIX -r -t $tsize -s 10 -e -F -E -k -e -useO_DIRECT -o $test_file

                `$DROP_CACHE_CMD`
                sleep 5

                echo "Measure data staging time -----------------"
                # actual_test_file=$(find $FS -name "ior_${tsize}_${trial}.bin")
                actual_test_file="$FS/0/ior_${tsize}_${trial}.bin.00000000"
                # Check if file exists
                if [ ! -f "$actual_test_file" ]; then
                    echo "File $actual_test_file does not exist"
                    exit 1
                fi
                echo "Actual test file: $actual_test_file"

                # measure datastaging time in milliseconds
                if [[ $FS == $SHARED_PATH ]]; then
                    echo "Measuring Data Stage in (from NFS to NVME)"

                    start_time=$SECONDS
                    mv $actual_test_file $LOCAL_PATH
                    end_time=$SECONDS
                    duration=$((end_time - start_time))
                    echo "Data Stage in took $duration seconds"
                else
                    echo "Measuring Data Stage out (from NVME to NFS)"

                    start_time=$SECONDS
                    mv $actual_test_file $SHARED_PATH
                    end_time=$SECONDS
                    duration=$((end_time - start_time))
                    echo "Data Stage out took $duration seconds"
                fi


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
