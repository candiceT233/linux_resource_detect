#!/bin/bash

IFS=$'\n' job_ids=($(squeue -u $USER --format="%A"))



#  ./show_job_dep.sh >> cur_job.log 2>&1

# squeue -u tang584 --format="%i %P %j %u %t %M %D %R %S %C %e"

# cat R_*.out | grep elapsed | cut -d'(' -f2 |cut -d' ' -f1

# scontrol update jobid=12345 Dependency=afterok:54321:54322


MailType_UPDATE () {

    for job_id in "${job_ids[@]}"; do
        echo "Updatign JobID: $job_id"
        echo "scontrol update jobid=$job_id MailType=END,FAIL"
        scontrol update jobid=$job_id MailType=END,FAIL
    done
}


DISPLAY_JOGS_ALL () {
    # Loop through the JobIDs and show their dependencies
    for job_id in "${job_ids[@]}"; do
        echo "JobID: $job_id"
        scontrol show job "$job_id"
        echo "------------------------"
    done

}

OPT=$1

if [ "$OPT" == "update_mail" ]
then
    MailType_UPDATE
fi


if [ "$OPT" == "all" ]
then
    DISPLAY_JOGS_ALL 
fi

DISPLAY_JOGS () {
    # Loop through the JobIDs and show their dependencies
    for job_id in "${job_ids[@]}"; do
        echo "JobID: $job_id"
        scontrol show job "$job_id" | grep JobName | cut -d ' ' -f2
        scontrol show job "$job_id" | grep Command
        scontrol show job "$job_id" | grep StdErr
        scontrol show job "$job_id" | grep StdOut
        scontrol show job "$job_id" | grep Dependency # | cut -d ' ' -f3
        scontrol show job "$job_id" | grep MailType
        echo "------------------------"
    done

}

DISPLAY_JOGS
