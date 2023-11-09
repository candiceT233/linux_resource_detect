#!/bin/bash

# Default values
LOG_LEVEL=1
DEST_FILES="dest_data_list.txt"

# Function to display usage instructions
usage() {
  echo "Usage: $0 [-c|--conf <CURR_STORAGE_CONF>] [-d|--data <USER_DATA_LIST>] [-l|--log-level <LOG_LEVEL>]"
  echo "Options:"
  echo "  -c, --conf <CURR_STORAGE_CONF>: Path to the current storage configuration file."
  echo "  -d, --data <USER_DATA_LIST>: Path to the file containing absolute user data file paths."
  echo "  -l, --log-level <LOG_LEVEL>: Log level: 0 - minimal log, 1 - full log, default is 1"
  echo "  -h, --help: Display this help and exit"
  exit 1
}

# Function to check input options
check_input() {
  while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
      -c|--conf)
        CURR_STORAGE_CONF="$2"
        shift 2
        ;;
      -d|--data)
        USER_DATA_LIST="$2"
        shift 2
        ;;
      -l|--log-level)
        LOG_LEVEL="$2"
        shift 2
        ;;
      -h|--help)
        usage
        ;;
      *)
        echo "Unknown option: $key" >&2
        usage
        ;;
    esac
  done

  # Check if both options are provided
  if [ -z "$CURR_STORAGE_CONF" ] || [ -z "$USER_DATA_LIST" ]; then
    echo "Both -c or --conf and -d or --data options are required."
    usage
  fi

  # Check if files exist
  if [ ! -f "$CURR_STORAGE_CONF" ]; then
    echo "Error: Current storage configuration file '$CURR_STORAGE_CONF' does not exist."
    usage
  fi

  if [ ! -f "$USER_DATA_LIST" ]; then
    echo "Error: User data path list file '$USER_DATA_LIST' does not exist."
    usage
  fi
}

# Main script

# Check input options
check_input "$@"

echo "Current storage config file: $CURR_STORAGE_CONF"
echo "User data path list file: $USER_DATA_LIST"
echo "LOG_LEVEL: $LOG_LEVEL"
echo "DEST_FILES: $DEST_FILES"
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
    # if file exist, echo
    if [ -f "$file_path" ]; then
        user_file_list+=("$file_path")
    else
        echo "Error: $file_path does not exist, not added."
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
IFS=, read -r first_line < "$CURR_STORAGE_CONF"
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
} < "$CURR_STORAGE_CONF"


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

        # check if full_dest_file already exist
        if [[ "$full_data_path" == "$full_dest_file"* ]]; then
            echo "Error: $full_data_path already exist in $dest_path"
        else
            [ $LOG_LEVEL -eq 1 ] && echo "Moving $full_data_path to $dest_path"
            start_time=$(date +%s.%N)        
            mv "$full_data_path" "$dest_path"
            end_time=$(date +%s.%N)
            duration=$(echo "$end_time - $start_time" | bc)
            let moved_data++

            dest_data="$dest_path/$data_file"
            # store performance statistics
            bw=$(check_data_moving_performance "$dest_data" "$duration")
            move_data_perf[$moved_data,"Dest"]=$dest_data
            move_data_perf[$moved_data,"Duration"]=$duration
            move_data_perf[$moved_data,"Bandwidth"]=$bw

            [ $LOG_LEVEL -eq 1 ] && echo "Moved $full_data_path to $dest_path in $duration seconds"
            [ $LOG_LEVEL -eq 1 ] && echo "`ls -l $dest_data`"
        fi
    done
}

dest_path="${best_bw_item[Actual_Path]}"
move_data_to_dest "$dest_path"


# ---- Check if destination path has the user files
check_dest_data(){
    for full_data_path in "${user_file_list[@]}"; do
        # get file base name
        data_file=$(basename "$full_data_path")
        full_dest_file="$dest_path/$data_file"

        # check full_dest_file exits
        if [ -f "$full_dest_file" ]; then
            [ $LOG_LEVEL -eq 1 ] && echo "Successfully moved $full_dest_file"
            [ $LOG_LEVEL -eq 1 ] && echo "`ls -l $full_dest_file`"
            echo "$full_dest_file" > $DEST_FILES
        else
            echo "Error: $full_dest_file does not exist"
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

        # check if full_dest_file already exist
        if [ -f "$full_dest_file" ]; then
            [ $LOG_LEVEL -eq 1 ] && echo "Restoring $full_dest_file to $full_data_path"
            start_time=$(date +%s.%N)        
            mv "$full_dest_file" "$full_data_path"
            end_time=$(date +%s.%N)
            echo "Restored $full_dest_file to $full_data_path in $(echo "$end_time - $start_time" | bc) seconds"
            [ $LOG_LEVEL -eq 1 ] && echo "`ls -l $full_dest_file`"
        else
            echo "Error: $full_dest_file does not exist"
        fi
    done
}

restore_data