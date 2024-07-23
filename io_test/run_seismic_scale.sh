# DARSHAN_LOG_PATH=/qfs/people/tang584/experiments/darshan-logs/2024/5/21
# rm -rf $DARSHAN_LOG_PATH/*

DATALIFE_STAT_LOG_FOLDER=/qfs/people/tang584/scripts/linux_resource_detect/io_test/datalife_seism
mkdir -p $DATALIFE_STAT_LOG_FOLDER
rm -rf $DATALIFE_STAT_LOG_FOLDER/*

for num in 1 2 5 10 20 40 80 160 320
do
    for disktype in bgfs_datalife ssd bgfs # ramdisk
    do
        mkdir -p ${disktype}_results
        for trial in {1..3}; do
            input_file_num=$num
            concurrency=1 #$num
            log_files="${disktype}_f${num}p${num}_${trial}.log"
            darshan_test_log=${disktype}_results/${disktype}_f${num}p${num}_${trial}_darshan_logs

            echo "Running run_seismic_${disktype}.sh $concurrency $input_file_num"
            bash run_seismic_${disktype}.sh $concurrency $input_file_num 2>&1 | tee $log_files

            sleep 5
            mkdir -p $darshan_test_log
            mv $DARSHAN_LOG_PATH/* $darshan_test_log
            rm -rf $DARSHAN_LOG_PATH/*
        done
        mv ${disktype}_f${num}p${num}_*.log ${disktype}_results/
    done
done