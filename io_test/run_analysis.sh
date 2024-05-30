
for con in 1 2 5 10 20 40 80 160 320
do  
    for stor in ssd bgfs #ramdisk
    do
        result_path="${stor}_results"
        file_name="${stor}_f${con}p${con}_1_darshan_logs"
        echo "Running my_ds_analysis.py $result_path/$file_name"

        python my_ds_analysis.py $result_path/$file_name | tee $result_path/$file_name.log
    done
done