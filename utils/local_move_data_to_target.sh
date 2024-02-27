#!/bin/bash

# Default values
DEST_FILES="dest_data_list.txt"
rm -rf $DEST_FILES
DEST_PATH="$1"
USER_DATA_LIST="$2"
MODE="$3"
LOG_LEVEL="$4"


# Function to display usage instructions
usage() {
  echo "Usage: $0 <DEST_PATH> <USER_DATA_LIST> <MODE> <LOG_LEVEL>"
  echo "Options:"
  echo "  <DEST_PATH>         Destination path to where data will be copied."
  echo "  <USER_DATA_LIST>    Path to the user data list file."
  echo "  <MODE>              Mode (0 - do not restore user data, 1 - restore user data, default: 0 for testing)."
  echo "  <LOG_LEVEL>         Log level (0 - minimal log, 1 - full log, default: 1)."
}

# If incorrect number of args, print usage and exit
if [ $# -ne 4 ]; then
    usage
    exit 1
fi

# Main script

echo "Destination path: $DEST_PATH"
echo "User data path list file: $USER_DATA_LIST"
echo "LOG_LEVEL: $LOG_LEVEL"
echo "DEST_FILES: $DEST_FILES"
if [ $MODE -eq 1 ]; then
    echo "MODE: $MODE, restore user data"
else
    echo "MODE: $MODE, not restore user data"
fi
echo "-------------------------------------"

# ---- Parsing the user data list file and check the file size
user_file_list=()

while IFS=, read -r file_path
do
    # Evaluate the file path to resolve environment variables
    eval "resolved_path=$file_path"
    # Check if the path exists
    if [ ! -e "$resolved_path" ]; then
        echo "Error: $resolved_path does not exist, not added."
        continue
    fi


    # Check if the path is a file
    if [ -f "$resolved_path" ]; then
        echo "INFO: $resolved_path is a file"
        user_file_list+=("$resolved_path")
    elif [ -d "$resolved_path" ]; then
        echo "INFO: $resolved_path is a directory"
    	user_file_list+=("$resolved_path")
    else
        echo "Error: $resolved_path is neither a file nor a directory, not added."
        continue
    fi
done < "$USER_DATA_LIST"


declare -A move_data_perf
check_data_moving_performance(){
    local dest_file="$1"
    local duration="$2"
    # get dest_file size in bytes
    local dest_file_size=$(stat -c%s "$dest_file")
    # calculate bandwidth
    local bandwidth=$(bc <<< "$dest_file_size / $duration")
    echo "$bandwidth"
}

check_dir_moving_performance(){
    local dest_file="$1"
    local duration="$2"
    # get dest_file size in bytes
    # local dest_file_size=$(du -b "$dest_file/*")

    local output=$(du -b $dest_file/*)

    # Initialize an empty array
    file_sizes=()

    # Iterate over each line of the output and extract the first column
    while IFS=$'\t' read -r size _; do
        # Add the size to the array
        file_sizes+=("$size")
    done <<< "$output"

    # # Print the array
    # printf '%s\n' "${file_sizes[@]}"
    sum_sizes=0
    for size in "${file_sizes[@]}"; do
        # convert string to integer
        size=$(($size))
        sum_sizes=$(($sum_sizes + $size))
    done

    # calculate bandwidth
    local bandwidth=$(bc <<< "$sum_sizes / $duration")
    echo "$bandwidth"
}

# ---- Display movement performance statistics
display_movement_performance_stat(){
    echo "-------------------------------------"
    # check if there is any data moved
    if [ $moved_data -eq 0 ]; then
        echo "No data moved"
        return
    else
        echo "Data movement performance statistics:"
        for i in $(seq 1 $moved_data); do
            echo "  - ${move_data_perf[$i,Dest]}: ${move_data_perf[$i,Duration]} seconds, ${move_data_perf[$i,Bandwidth]} B/s"
        done
    fi
    echo "-------------------------------------"
}

move_data_to_dest(){
    dest_path="$1"
    moved_data=0
    for full_data_path in "${user_file_list[@]}"; do
        # if full_data_path is a directory
        if [ -d "$full_data_path" ]; then
            [ $LOG_LEVEL -eq 1 ] && echo "Moving directory $full_data_path to $dest_path"
            start_time=$(date +%s.%N)     
            # iteratively cp files in the directory
            cp -r "$full_data_path" "$dest_path"
            end_time=$(date +%s.%N)
            duration=$(echo "$end_time - $start_time" | bc)
            let moved_data++
            # store performance statistics
            bw=$(check_dir_moving_performance "$dest_path" "$duration")
            move_data_perf[$moved_data,"Dest"]=$dest_path
            move_data_perf[$moved_data,"Duration"]=$duration
            move_data_perf[$moved_data,"Bandwidth"]=$bw
        else

            # get file base name
            data_file=$(basename "$full_data_path")
            full_dest_file="$dest_path/$data_file"

            # check if full_dest_file already exist
            if [[ "$full_data_path" == "$full_dest_file"* ]]; then
                echo "Error: $full_data_path already exist in $dest_path"
            else
                [ $LOG_LEVEL -eq 1 ] && echo "Moving file $full_data_path to $dest_path"
                start_time=$(date +%s.%N)        
                cp "$full_data_path" "$dest_path"
                end_time=$(date +%s.%N)
                duration=$(echo "$end_time - $start_time" | bc)
                let moved_data++

                dest_data="$dest_path/$data_file"
                # store performance statistics
                bw=$(check_data_moving_performance "$full_data_path" "$duration")
                move_data_perf[$moved_data,"Dest"]=$dest_data
                move_data_perf[$moved_data,"Duration"]=$duration
                move_data_perf[$moved_data,"Bandwidth"]=$bw

                [ $LOG_LEVEL -eq 1 ] && echo "Moved $full_data_path to $dest_path in $duration seconds"
                [ $LOG_LEVEL -eq 1 ] && echo "`ls -l $dest_data`"
            fi
        fi
    done

    [ $LOG_LEVEL -eq 1 ] && display_movement_performance_stat
}

moved_data=0
move_data_to_dest "$DEST_PATH"


# ---- Check if destination path has the user files

check_dest_data(){
    local dest_path="$1"
    for full_data_path in "${user_file_list[@]}"; do
        # check if full_data_path is a directory
        if [ -d "$full_data_path" ]; then
            # Check if the destination exists
            if [ ! -d "$dest_path" ]; then
                echo "Error: $dest_path does not exist"
                continue
            fi

            # Check if the directory is empty
            if [ -z "$(ls -A $dest_path)" ]; then
                echo "Error: $dest_path is empty"
                continue
            else
                echo "Successfully moved to $dest_path"
                # Display size of subdirectories/subfiles
                [ $LOG_LEVEL -eq 1 ] && du -h $dest_path/*
            fi
        else
            # get file base name
            data_file=$(basename "$full_data_path")
            full_dest_file="$dest_path/$data_file"

            # check if full_dest_file exits
            if [ -f "$full_dest_file" ]; then
                [ $LOG_LEVEL -eq 1 ] && echo "Successfully moved to $full_dest_file"
                [ $LOG_LEVEL -eq 1 ] && echo "`ls -l $full_dest_file`"
                echo "$full_dest_file" >> "$DEST_FILES"
            else
                echo "Error: $full_dest_file does not exist"
            fi
        fi
    done
}


check_dest_data "$DEST_PATH"




# restore data to original path
restore_data(){
    for full_data_path in "${user_file_list[@]}"; do
        # get file base name
        data_file=$(basename "$full_data_path")
        full_dest_file="$dest_path/$data_file"
        # remove data_file name from full_data_path
        full_data_path="${full_data_path%/*}/"
        [ $LOG_LEVEL -eq 1 ] && echo "moving $data_file back to $full_data_path"

        # check if full_dest_file already exist
        if [ -f "$full_dest_file" ]; then
            [ $LOG_LEVEL -eq 1 ] && echo "Restoring $full_dest_file to $full_data_path"
            start_time=$(date +%s.%N)        
            cp -r "$full_dest_file" "$full_data_path"
            end_time=$(date +%s.%N)
            echo "Restored $full_dest_file to $full_data_path in $(echo "$end_time - $start_time" | bc) seconds"
            [ $LOG_LEVEL -eq 1 ] &&  ls $full_dest_file > /dev/null 2>&1 && echo "$data_file restored failed" || echo "$data_file restored successfully"
        else
            echo "Error: $full_dest_file does not exist"
        fi
    done
}

if [ $MODE -eq 1 ]; then
    restore_data
fi
