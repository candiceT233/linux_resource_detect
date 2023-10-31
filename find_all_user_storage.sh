#!/bin/bash

#user="$USER"
user="users"

# Initialize an associative array to store unique parent directories
declare -A directories

# Use the 'find' command to search for directories owned by the group 'user'
# within a maximum depth of 2 from the root directory '/'
# The '-type d' option specifies that we are looking for directories
# The '-group user' option specifies that we want directories owned by the 'user' group
# The '-maxdepth 2' option limits the search to a maximum depth of 2 levels

# ---- Find Root Directories
loop_count=0 # Track searching overhead
while IFS= read -r -d '' dir; do
    parent_dir="$(dirname "$dir")"

    # Check the access mode of the directory
    acc_mode="$(stat -c "%a" "$parent_dir")"
    # Extract the third character from the access mode
    group_acc_mode="${acc_mode:2:1}"
    # Convert the third character to an integer
    group_acc_mode=$((10#$group_acc_mode))

    if [ "$group_acc_mode" -gt 5 ]; then
        # Extract the parent directory (up to the second level)
        # Store the parent directory path in the associative array to ensure uniqueness
        directories["$parent_dir"]=1
    fi

    let loop_count++
done < <(find / -maxdepth 2 -type d -group "$user" -print0 2>/dev/null)



echo "checked paths for root: $loop_count"

# ---- Find Mounted Directories
exclude_paths=("/sys" "/proc" "/run" "/var") # "/dev"

# Join the array elements with the | character as the delimiter
exclude_pattern=$(IFS="|"; echo "${exclude_paths[*]}")

loop_count=0 # Track searching overhead
while IFS= read -r dir; do
    
    # Check the access mode of the directory
    acc_mode="$(stat -c "%a" "$dir")"
    group_acc_mode="${acc_mode:2:1}"
    group_acc_mode=$((10#$group_acc_mode))
    if [ $group_acc_mode -gt 5 ]; then 
        # Store the directory path in the associative array to ensure uniqueness
        directories["$dir"]=1
    fi
    
    let loop_count++
done < <(findmnt --noheadings --list | grep -Ev "$exclude_pattern" | cut -d ' ' -f1)
# 'findmnt --uniq' option works up to findmnt from util-linux 2.32.1

echo "checked paths for mount: $loop_count"



# List Storage Type and Storage Space of paths in directories
# Store path info in associative array
declare -A directories_info
header="Actual_Path,Filesystem,Type,Size,Used,Avail,Use%,Mounted_on,Mode,Access_Right"
for path in "${!directories[@]}"; do

    general_info="$(df -Th "$path" | awk 'NR==2' | awk -F '[[:space:]]+' '{OFS=","; $1=$1}1')"
    access_mode=$(stat -c "%a" "$path")
    access_right=$(stat -c "%A" "$path")
    directories_info["$path"]="$path,$general_info,$access_mode,$access_right"
done

echo "$header"
# Print the directory info for each path
for path in "${!directories_info[@]}"; do
    # echo "$path"
    echo "${directories_info["$path"]}"
done


