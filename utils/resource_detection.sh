#!/bin/bash

# Variables
LOG_LEVEL=$1
CHECK_USER="$2"
DIR_CONFIG_FILE="$3"
CHECK_GROUP="users"

# Function to print usage
usage () {
    echo "Usage: $0 <log level> <user name> <config file>"
    echo "Options:"
    echo "  <log level>     Log level: 0 - minimal log, 1 - full log"
    echo "  <user name>     User name to check"
    echo "  <config file>   Path to the directory configuration file"
}

# If incorrect number of args, print usage and exit
if [ $# -ne 3 ]; then
    usage
    exit 1
fi


# Initialize an associative array to store unique parent directories
declare -A all_directories

# ---- Add user Home Directory
# Add home directory
all_user_home="$(dirname `realpath $HOME`)"
[ $LOG_LEVEL -eq 1 ] && echo "all_user_home: $all_user_home"
user_home="$(realpath `getent passwd $CHECK_USER | cut -d: -f6`)"
[ $LOG_LEVEL -eq 1 ] && echo "user_home: $user_home"
all_directories["$user_home"]=1


# ---- Find Root Directories
start_time="$(date -u +%s.%N)"
loop_count=0 # Track searching overhead

# find all root directories
while IFS= read -r dir; do
    is_dir="$(stat -c "%A" "$dir" 2>/dev/null| cut -c 1)"
    write_perm="$(stat -c "%A" "$dir" 2>/dev/null| cut -c 6)"
    if [ "$is_dir" == "d" ] && [ "$write_perm" == "w" ]; then
        if [ "$LOG_LEVEL" -eq 1 ]; then echo "adding root: $dir"; fi
        all_directories["$dir"]=1
    fi

    let loop_count++

done < <(find / -maxdepth 1)

# calculate duration in milliseconds
duration=$(echo "$(date -u +%s.%N) - $start_time" | bc)
# Calculate the duration in seconds
duration_seconds=$(echo "$(date -u +%s.%N) - $start_time" | bc)
duration_ms=$(printf "%.0f" "$(echo "$duration_seconds * 1000" | bc -l)")

[ $LOG_LEVEL -eq 1 ] && echo "Root directories: spend [$duration_ms(ms)] checked [$loop_count] paths"

# ---- Find Mounted Directories
exclude_paths=("/sys" "/proc" "/run" "/var") # "/dev"
declare -A mnt_directories

# Join the array elements with the | character as the delimiter
exclude_pattern=$(IFS="|"; echo "${exclude_paths[*]}")

start_time="$(date -u +%s.%N)"
loop_count=0 # Track searching overhead

# find all mount directories
while IFS= read -r dir; do
    let loop_count++
    if [ $dir != "/" ] && [ $dir != "$all_user_home" ]; then # ignore root and home
        mnt_directories["$dir"]=1
    fi
done < <(findmnt --noheadings --list | grep -Ev "$exclude_pattern" | cut -d ' ' -f1)
# 'findmnt --uniq' option works up to findmnt from util-linux 2.32.1

# Check for user access not group access
for mnt_dir in "${!mnt_directories[@]}"; do
    # Extract the group access permission of the directory
    write_perm="$(stat -c "%A" "$mnt_dir" 2>/dev/null| cut -c 6)"
    if [ "$write_perm" == "w" ]; then
        let loop_count++
        if [ "$LOG_LEVEL" -eq 1 ]; then echo "adding user dir: $mnt_dir"; fi
        all_directories["$mnt_dir"]=1
        
    fi

    while IFS= read -r -d '' dir; do
        let loop_count++
	    # parent_dir="$(dirname "$dir")"
        # Extract the group access permission of the directory
        write_perm="$(stat -c "%A" "$dir" 2>/dev/null| cut -c 3)" # the owner is the user
        if [ "$write_perm" == "w" ]; then
        	if [ "$LOG_LEVEL" -eq 1 ]; then echo "adding user dir: $dir"; fi
		    all_directories["$dir"]=1
            break
        fi

        
    done < <(find $mnt_dir -maxdepth 2 -type d -user "$CHECK_USER" -print0 2>/dev/null)
done

duration=$(echo "$(date -u +%s.%N) - $start_time" | bc)
duration_seconds=$(echo "$(date -u +%s.%N) - $start_time" | bc)
duration_ms=$(printf "%.0f" "$(echo "$duration_seconds * 1000" | bc -l)")
[ $LOG_LEVEL -eq 1 ] && echo "Mount directories: spend [$duration_ms(ms)] checked [$loop_count] paths"

# ---- Test all_directories bandwidth
declare -A read_stats
declare -A write_stats


TEST_DIR_BW (){

<<COMMENT
Each FLAG symbol may be:

  append    append mode (makes sense only for output; conv=notrunc suggested)
  direct    use direct I/O for data
  directory  fail unless a directory
  dsync     use synchronized I/O for data
  sync      likewise, but also for metadata
  fullblock  accumulate full blocks of input (iflag only)
  nonblock  use non-blocking I/O
  noatime   do not update access time
  nocache   discard cached data
  noctty    do not assign controlling terminal from file
  nofollow  do not follow symlinks
  count_bytes  treat 'count=N' as a byte count (iflag only)
  skip_bytes  treat 'skip=N' as a byte count (iflag only)
  seek_bytes  treat 'seek=N' as a byte count (oflag only)
COMMENT

    [ $LOG_LEVEL -eq 1 ] && echo "Testing all_directories latency and bandwidth ..."

    for dir in "${!all_directories[@]}"; do
        # User dsync (synchronized I/O), direct does not work for tmpfs
        bytes_size=4K # 4K, 64K or 1M
        # sar -d $dir
        
        #FIXME: parsing of stats is incorrect
        
        # Test write latency and bandwidth
        write_stats["$dir"]="$(dd if=/dev/zero of=$dir/testfile bs=$bytes_size count=1000 oflag=dsync 2>&1 | tail -n 1 | cut -d ',' -f 2-)"
        # Test read latency and bandwidth
        read_stats["$dir"]="$(dd if=$dir/testfile of=/dev/null bs=$bytes_size count=1000 iflag=dsync 2>&1 | tail -n 1 | cut -d ',' -f 2-)"

        # clean up
        rm -rf $dir/testfile

        # Check if the write latency is empty or "0.0 kB/s"
        if [ -z "${write_stats["$dir"]}" ] || [ "${write_stats["$dir"]}" == " 0.0 kB/s" ]; then
            [ $LOG_LEVEL -eq 1 ] && echo "No latency data for $dir"
            # add latency N/A to dir
            write_stats["$dir"]="N/A,${write_stats["$dir"]}"
            read_stats["$dir"]="N/A,${read_stats["$dir"]}"
        fi

        [ $LOG_LEVEL -eq 1 ] && echo "$dir: {write: ${write_stats["$dir"]}, read: ${read_stats["$dir"]}}"

    done

}


# List Storage Type and Storage Space of paths in directories
LIST_ALL_INFO (){

    

    declare -A directories_info
    header="Actual_Path,Filesystem,Type,Size,Used,Avail_KB,Use%,Mounted_on,Mode,Access_Right,Read_Latency,Read_Bandwidth,Write_Latency,Write_Bandwidth"
    for path in "${!all_directories[@]}"; do

        general_info="$(df -T "$path" | awk 'NR==2' | awk -F '[[:space:]]+' '{OFS=","; $1=$1}1')"
        access_mode=$(stat -c "%a" "$path")
        access_right=$(stat -c "%A" "$path")
        
        # FIXME: parsing of status is incorrect
        read_latency=`echo "${read_stats["$path"]}" | cut -d ',' -f 1`
        write_latency=`echo "${write_stats["$path"]}" | cut -d ',' -f 1`
        read_bandwidth=`echo "${read_stats["$path"]}" | cut -d ',' -f 2`
        write_bandwidth=`echo "${write_stats["$path"]}" | cut -d ',' -f 2`
        directories_info["$path"]="$path,$general_info,$access_mode,$access_right,$read_latency,$read_bandwidth,$write_latency,$write_bandwidth"
    done

    echo "$header"
    # Print the directory info for each path
    for path in "${!directories_info[@]}"; do
        # echo "$path"
        echo "${directories_info["$path"]}"
    done

}

TEST_DIR_BW

[ $LOG_LEVEL -eq 1 ] && echo "Listing all directories info ..." && LIST_ALL_INFO | tee "$DIR_CONFIG_FILE"

