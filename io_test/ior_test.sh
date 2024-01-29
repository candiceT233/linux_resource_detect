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
-e      : fsync – perform fsync upon POSIX write close
-o      : testFile – full name for test
-F      : filePerProc – file-per-process
-k	    : keepFile – don’t remove the test file(s) on program exit
-useO_DIRECT:use direct I/ for POSIX, bypassing I/O buffers (default: 0)

## Unused 
-summaryAlways:Always print the long summary for each test even if the job is interrupted. (default: 0)
-f S    : scriptFile – test script name
-g      : intraTestBarriers – use barriers between open, write/read, and close
-q	    : quitOnError – during file error-checking, abort on error (incompatible with IOR-3.3.0)
COMMENT


NFS_PATH=$HOME/iortest
NVME_PATH=/mnt/nvme/$USER/iortest
LOG_FILE=./ior_ares_test.log

spack load ior

RUN_IOR (){
for FS in "$NFS_PATH" "$NVME_PATH"; do
    echo "Testing $FS"
    mkdir -p $FS
    for tsize in 2m 1m 4k; do
        echo "Testing $tsize"
        test_file="$FS/ior_${tsize}.bin"
        
        rm $test_file 2> /dev/null
        sudo drop_caches

        echo "Writing File:"
        # ior_write_cmd="ior -a POSIX -w -t $tsize -b 1g -s 2 -i 4 -e -F -useO_DIRECT -o $test_file"
        # echo "ior_write_cmd : ${ior_write_cmd}"
        # `$ior_write_cmd`
        ior -a POSIX -w -t $tsize -b 1g -s 2 -i 4 -e -F -k -useO_DIRECT -o $test_file

        sudo drop_caches
        sleep 5

        echo "Reading File:"
        # ior_read_cmd="ior -a POSIX -r -t $tsize -b 1g -s 2 -i 4 -e -F -E -useO_DIRECT -o $test_file"
        # echo "ior_read_cmd : ${ior_read_cmd}"
        # `$ior_read_cmd`
        ior -a POSIX -r -t $tsize -b 1g -s 2 -i 4 -e -F -E -k -useO_DIRECT -o $test_file

        # for mode in w r; do
        #     echo "Testing $tsize $mode"
        #     ior -a POSIX -$mode -t $tsize -b 1g -s 2 -o -F $FS/ior_${tsize}.bin
        # done
        rm -rf $test_file
        sudo drop_caches
        sleep 5
    done
    echo "$FS tests done -----------------"
done
}



RUN_IOR | tee $LOG_FILE