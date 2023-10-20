#!/bin/bash

# user="$USER"
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
    # Extract the parent directory (up to the second level)
    parent_dir="$(dirname "$dir")"
    # Store the parent directory path in the associative array to ensure uniqueness
    directories["$parent_dir"]=1
    let loop_count++
done < <(find / -maxdepth 2 -type d -group $user -print0 2>/dev/null)
echo "checked paths for root: $loop_count"

# ---- Find Mounted Directories
exclude_paths=("/sys" "/dev" "/proc" "/run" "/var")

# Join the array elements with the | character as the delimiter
exclude_pattern=$(IFS="|"; echo "${exclude_paths[*]}")

loop_count=0 # Track searching overhead
while IFS= read -r dir; do
    # Store the parent directory path in the associative array to ensure uniqueness
    directories["$dir"]=1
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


