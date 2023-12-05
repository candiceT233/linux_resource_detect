#!/bin/bash

# Default values
DEST_FILES="dest_data_list.txt"
DIR_CONFIG_FILE="$1"
USER_DATA_LIST="$2"
MODE="$3"
LOG_LEVEL="$4"
REMOTE_SERVER_LOGIN="$5"
IDENTITY_FILE="$6"

# # Remote SSH server details
# REMOTE_SERVER_LOGIN="$CHECK_USER@$REMOTE_SERVER"

# Function to display usage instructions
usage() {
  echo "Usage: $0 [DIR_CONFIG_FILE] [USER_DATA_LIST] [MODE] [LOG_LEVEL] [REMOTE_SERVER_LOGIN] [IDENTITY_FILE]"
  echo "Options:"
  echo "  DIR_CONFIG_FILE       Path to the directory configuration file."
  echo "  USER_DATA_LIST        Path to the user data list file."
  echo "  MODE                  Mode (0 - do not restore user data, 1 - restore user data, default: 1 for testing)."
  echo "  LOG_LEVEL             Log level (0 - minimal log, 1 - full log, default: 1)."
  echo "  REMOTE_SERVER_LOGIN   Remote server login name user_name@remote_server_ip."
  echo "  IDENTITY_FILE         Identity file for SSH connection (optional)."
}

# If less than 5 args supplied, display usage and exit.
if [ $# -lt 5 ]; then
  usage
  exit 1
fi

# Check if IDENTITY_FILE is entered
if [ -z "$IDENTITY_FILE" ]; then
    echo "Warning: no identity file specified"
fi

# Main script

echo "Current storage config file: $DIR_CONFIG_FILE"
echo "User data path list file: $USER_DATA_LIST"
echo "LOG_LEVEL: $LOG_LEVEL"
echo "DEST_FILES: $DEST_FILES"
if [ $MODE -eq 1 ]; then
    echo "MODE: $MODE, restore user data"
else
    echo "MODE: $MODE, not restore user data"
fi
echo "-------------------------------------"


# Function to convert bandwidth to B/s
convert_bandwidth_to_Bps() {
    local bandwidth="$1"
    local multiplier=1

    case "$bandwidth" in
        *KB/s)
            multiplier=1024
            ;;
        *MB/s)
            multiplier=1048576  # 1024^2
            ;;
        *GB/s)
            multiplier=1073741824  # 1024^3
            ;;
    esac

    # Extract the numeric part of the bandwidth value
    local numeric_value="$(echo "$bandwidth" | grep -oE '[0-9.]+')"

    # Perform the conversion
    local Bps_value=$(bc <<< "$numeric_value * $multiplier")

    # echo "Converting from $bandwidth to $Bps_value B/s"

    echo "$Bps_value"
}

PRINT_CONFIG () {
    echo "Printing all dest_path_conf config"
    # Print the list of associative arrays
    # loop from i=1 up to i=$path_idx
    for i in $(seq 1 $path_idx); do
        echo "[$i]-------------------------------------"
        for element in "${header[@]}"; do
            # echo "dest_path_conf[$i,$element] = ${dest_path_conf[$i,${element}]}"
            echo "$element = ${dest_path_conf[$i,${element}]}"
        done
        echo "-------------------------------------"
    done
}

# ---- Parsing the user data list file and check the file size
user_file_list=()

while IFS=, read -r file_path
do
    # Evaluate the file path to resolve environment variables
    eval "resolved_path=$file_path"

    # if file exist, echo
    if [ -f "$resolved_path" ]; then
        user_file_list+=("$resolved_path")
    else
        echo "Error: $resolved_path does not exist, not added."
        continue
    fi
done < "$USER_DATA_LIST"

TOTAL_REQUIRED_STORAGE=0
for file_path in "${user_file_list[@]}"; do
    file_size=$(stat -c%s "$file_path")
    [ $LOG_LEVEL -eq 1 ] && echo "file_path: $file_path, file_size: $file_size"    
    TOTAL_REQUIRED_STORAGE=$((TOTAL_REQUIRED_STORAGE + file_size))
done
[ $LOG_LEVEL -eq 1 ] && echo "TOTAL_REQUIRED_STORAGE: $TOTAL_REQUIRED_STORAGE"

# ---- Parsing discovered storage configs

# Read the first line (header)
IFS=, read -r first_line < "$DIR_CONFIG_FILE"
# Split the line into an array using , as the delimiter
IFS=',' read -ra header <<< "$first_line"


# Declare the global dest_path_conf variable
declare -A dest_path_conf

path_idx=0

{ 
read # discard first line
while IFS=, read -r actual_path filesystem type size used avail use_percent mounted_on mode access_right read_latency read_bandwidth write_latency write_bandwidth
do
    
    # Create an associative array for each line
    declare -A row
    row["Actual_Path"]=$actual_path
    row["Filesystem"]=$filesystem
    row["Type"]=$type
    row["Size"]=$size
    row["Used"]=$used
    # convert $avail from KB to Bytes
    avail=$(bc <<< "$avail * 1024")
    row["Avail_B"]=$avail
    row["Use%"]=$use_percent
    row["Mounted_on"]=$mounted_on
    row["Mode"]=$mode
    row["Access_Right"]=$access_right
    row["Read_Latency"]=$read_latency
    # row["Read_Bandwidth"]=$read_bandwidth
    row["Read_Bandwidth"]=$(convert_bandwidth_to_Bps "$read_bandwidth")
    row["Write_Latency"]=$write_latency
    # row["Write_Bandwidth"]=$write_bandwidth
    row["Write_Bandwidth"]=$(convert_bandwidth_to_Bps "$write_bandwidth")

    # check if the path size is more than TOTAL_REQUIRED_STORAGE
    if (( $(echo "$avail > $TOTAL_REQUIRED_STORAGE" | bc -l) )); then
        # Add the new associative array to the dest_path_conf
        let path_idx++
        for key in "${!row[@]}"; do
            dest_path_conf[$path_idx,$key]=${row[$key]}
        done
    else
        [ $LOG_LEVEL -eq 1 ] && echo "WARNING: $actual_path[$avail] not enough storage for [$TOTAL_REQUIRED_STORAGE]"
    fi


done
} < "$DIR_CONFIG_FILE"


# PRINT_CONFIG

# ---- Find the item with the highest bandwidth
# Initialize best_bw_item as an empty associative array
declare -A best_bw_item

FIND_BEST_BW_ITEM() {
    local key="$1"  # Specify the key (e.g., 'Read_Bandwidth' or 'Write_Bandwidth')
    local highest_bandwidth=0

    # declare -A aarr="$2"
    declare -A aarr

    # Iterate through the associative arrays
    for i in $(seq 1 $path_idx); do
        bandwidth_numeric=$(bc <<< "${dest_path_conf[$i,${key}]}")
        cur_path="${dest_path_conf[$i,Actual_Path]}"

        # Compare and update if it's the highest so far
        if (( $(echo "$bandwidth_numeric > $highest_bandwidth" | bc -l) )); then
            highest_bandwidth=$bandwidth_numeric
            # Copy all elements of the current associative array into best_bw_item
            for element in "${header[@]}"; do
                aarr["$element"]=${dest_path_conf[$i,${element}]}
            done
            aarr["path_idx"]=$i # add path index
        fi
    done

    declare -p aarr
}

# Example usage
key="Write_Bandwidth"
tmp=$(FIND_BEST_BW_ITEM "$key")

result=$(echo "$tmp" | sed "s/aarr=/best_bw_item=/")
eval $result

display_dest_path (){
    local key="$1"
    echo "-------------------------------------"
    echo "Best $key path config:"
    for element in "${header[@]}"; do
        echo "  - $element : ${best_bw_item[$element]}"
    done
    echo "-------------------------------------"
}

[ $LOG_LEVEL -eq 1 ] && display_dest_path $key


# check to make sure user data is not already in the best_bw_item
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

move_data_to_dest(){
    dest_path="$1"
    moved_data=0
    for full_data_path in "${user_file_list[@]}"; do
        # get file base name
        data_file=$(basename "$full_data_path")
        full_dest_file="$dest_path/$data_file"

        # check if full_dest_file already exist in REMOTE_SERVER_LOGIN
        file_exist=0 # 0:false 1:true
        if [ ! -z "$IDENTITY_FILE" ]; then
            if ssh -i "$IDENTITY_FILE" "$REMOTE_SERVER_LOGIN" "test -e '$full_dest_file'"; then file_exist=1; fi
        else
            if ssh "$REMOTE_SERVER_LOGIN" "test -e '$full_dest_file'"; then file_exist=1; fi
        fi

        if [ $file_exist -eq 1 ]; then
            [ $LOG_LEVEL -eq 1 ] && echo "Error: $full_data_path already exist in $REMOTE_SERVER_LOGIN:$dest_path"
        else
            [ $LOG_LEVEL -eq 1 ] && echo "Moving $full_data_path to $dest_path"
            start_time=$(date +%s.%N)
            # Move data to remote server's $dest_path
            if [ ! -z "$IDENTITY_FILE" ]; then
                scp -i "$IDENTITY_FILE" "$full_data_path" "$REMOTE_SERVER_LOGIN:$dest_path"
            else
                scp "$full_data_path" "$REMOTE_SERVER_LOGIN:$dest_path"
            fi
            end_time=$(date +%s.%N)
            duration=$(echo "$end_time - $start_time" | bc)
            let moved_data++

            # dest_data="$dest_path/$data_file"
            # store performance statistics
            bw=$(check_data_moving_performance "$full_dest_file" "$duration")
            move_data_perf[$moved_data,"Dest"]=$full_dest_file
            move_data_perf[$moved_data,"Duration"]=$duration
            move_data_perf[$moved_data,"Bandwidth"]=$bw

            [ $LOG_LEVEL -eq 1 ] && echo "Moved $full_data_path to $REMOTE_SERVER_LOGIN:$dest_path in $duration seconds"
            # [ $LOG_LEVEL -eq 1 ] && echo "`ls -l $full_dest_file`"
        fi
    done
}

dest_path="${best_bw_item[Actual_Path]}"
move_data_to_dest "$REMOTE_SERVER_LOGIN:$dest_path"


# ---- Check if destination path has the user files
check_dest_data(){
    for full_data_path in "${user_file_list[@]}"; do
        # get file base name
        data_file=$(basename "$full_data_path")
        full_dest_file="$dest_path/$data_file"

        # Check if the $REMOTE_SERVER_LOGIN:$full_dest_file exists
        if [ ! -z "$IDENTITY_FILE" ]; then
            ssh -i "$IDENTITY_FILE" "$REMOTE_SERVER_LOGIN" "test -e '$full_dest_path' && \
                echo 'Successfully moved to $REMOTE_SERVER_LOGIN:$full_dest_file' || \
                echo 'Error: $REMOTE_SERVER_LOGIN:$full_dest_file does not exist'"
        else
            ssh "$REMOTE_SERVER_LOGIN" "test -e '$full_dest_path' && \
                echo 'Successfully moved to $REMOTE_SERVER_LOGIN:$full_dest_file' || \
                echo 'Error: $REMOTE_SERVER_LOGIN:$full_dest_file does not exist'"
        fi
    done
}

check_dest_data

# ---- Display movement performance statistics
display_movement_performance_stat(){
    echo "-------------------------------------"
    echo "Data movement performance statistics:"
    for i in $(seq 1 $moved_data); do
        echo "  - ${move_data_perf[$i,Dest]}: ${move_data_perf[$i,Duration]} seconds, ${move_data_perf[$i,Bandwidth]} B/s"
    done
    echo "-------------------------------------"
}

[ $LOG_LEVEL -eq 1 ] && display_movement_performance_stat


# restore data to original path
restore_data(){
    for full_data_path in "${user_file_list[@]}"; do
        # get file base name
        data_file=$(basename "$full_data_path")
        full_dest_file="$dest_path/$data_file"
        # remove data_file name from full_data_path
        full_data_path="${full_data_path%/*}/"
        [ $LOG_LEVEL -eq 1 ] && echo "moving $data_file back to $full_data_path"

        # check if full_dest_file already exist in REMOTE_SERVER_LOGIN
        file_exist=0 # 0:false 1:true
        if [ ! -z "$IDENTITY_FILE" ]; then
            if ssh -i "$IDENTITY_FILE" "$REMOTE_SERVER_LOGIN" "test -e '$full_dest_path'"; then file_exist=1; fi
        fi

        # check if full_dest_file already exist
        if [ $file_exist -eq 1 ]; then

            [ $LOG_LEVEL -eq 1 ] && echo "Restoring $REMOTE_SERVER_LOGIN:$full_dest_file to $full_data_path"
            start_time=$(date +%s.%N)

            # Move data from remote server's $dest_path back to original path
            if [ ! -z "$IDENTITY_FILE" ]; then
                scp -i "$IDENTITY_FILE" "$REMOTE_SERVER_LOGIN:$full_dest_file" "$full_data_path" 
            else
                scp "$REMOTE_SERVER_LOGIN:$full_dest_file" "$full_data_path"
            fi

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
