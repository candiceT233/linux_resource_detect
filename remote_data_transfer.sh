#!/bin/bash

# Default values
LOG_LEVEL=1
CHECK_USER="$USER"
REMOTE_SERVER="local"
DIR_CONFIG_FILE="dir_config.csv"
USER_DATA_LIST=""
MODE=1

# Function to print usage
PRINT_USAGE () {
    echo "Usage: $0 [-u <user name>] [-s <remote server>] [-i <identity file>]"
    echo "           [-o <output file>] [-d <data file>] [-m <mode>]"
    echo "           [-log <log level>] [-h]"
    echo "Options:"
    echo "  -u, --user <USER_NAME>: User name to check (default: current user)"
    echo "  -s, --server <SERVER_NAME>: Remote server name"
    echo "  -i, --identity <IDENTITY_FILE>: Identity file to use for SSH connection"
    echo "  -o, --output <OUTPUT_FILE>: File with all detected user storage paths"
    echo "  -d, --data <DATA_FILE>: Path to the file containing absolute user data file paths"
    echo "  -m, --mode <MODE>: Mode (0 - do not restore user data, 1 - restore user data, default: 1 for testing)"
    echo "  -log, --log-level <LOG_LEVEL>: Log level (0 - minimal log, 1 - full log, default: 1)"
    echo "  -h, --help: Display this help and exit"
}

while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
        -u|--user)
            CHECK_USER="$2"
            # Must enter a user name
            if [ -z "$CHECK_USER" ]; then
                echo "Error: must specify a user name"
                PRINT_USAGE
                exit 1
            fi
            shift # past argument
            shift # past value
            ;;
        -s|--server)
            REMOTE_SERVER="$2"
            # Must enter a server name
            if [ -z "$REMOTE_SERVER" ]; then
                echo "Error: must specify a cluster name"
                PRINT_USAGE
                exit 1
            fi
            shift # past argument
            shift # past value
            ;;
        -i|--identity)
            IDENTITY_FILE="$2"
            # Check if the identity file exists
            if [ ! -f "$IDENTITY_FILE" ]; then
                echo "Error: identity file [$IDENTITY_FILE] does not exist"
                PRINT_USAGE
                exit 1
            fi
            shift # past argument
            shift # past value
            ;;
        -o|--output)
            DIR_CONFIG_FILE="$2"
            shift # past argument
            shift # past value
            ;;
        -d|--data)
            USER_DATA_LIST="$2"
            shift # past argument
            shift # past value
            ;;
        -m|--mode)
            MODE="$2"
            shift # past argument
            shift # past value
            ;;
        -log|--log-level)
            if ! [[ "$2" =~ ^[0-9]+$ ]]; then
                echo "Error: log level must be a number"
                PRINT_USAGE
                exit 1
            fi
            LOG_LEVEL="$2"
            shift # past argument
            shift # past value
            ;;
        -h|--help)
            PRINT_USAGE
            exit 0
            ;;
        *)
            # unknown option
            echo "Error: unknown option: $1"
            PRINT_USAGE
            exit 1
            ;;
    esac
done

# Check variables

# Remote SSH server details
remote_server_login="$CHECK_USER@$REMOTE_SERVER"
DIR_CONFIG_FILE="${REMOTE_SERVER}_${DIR_CONFIG_FILE}"

# Check valid access
CHECK_SSH_ACCESS () {
    # Check if the identity file exists
    if [ ! -z "$IDENTITY_FILE" ] && [ ! -f "$IDENTITY_FILE" ]; then
        echo "Error: identity file [$IDENTITY_FILE] does not exist"
        PRINT_USAGE
        exit 1
    fi

    # Test SSH access
    echo "Testing SSH access to $remote_server_login..."
    if [ ! -z "$IDENTITY_FILE" ]; then
        ssh -q -i "$IDENTITY_FILE" "$remote_server_login" exit
    else
        ssh -q "$remote_server_login" exit
    fi

    if [ $? -eq 0 ]; then
        echo "SUCCESS: [$CHECK_USER] has SSH access to [$REMOTE_SERVER]."
    else
        echo "ERROR: [$CHECK_USER] does not have SSH access to [$REMOTE_SERVER]."
        exit 1
    fi

}

# Check SSH access
if [ "$REMOTE_SERVER" != "local" ]; then
    CHECK_SSH_ACCESS
fi



echo "LOG_LEVEL: $LOG_LEVEL"
echo "CHECK_USER: $CHECK_USER"
echo "REMOTE_SERVER: $REMOTE_SERVER"
# echo "IDENTITY_FILE: $IDENTITY_FILE"
echo "DIR_CONFIG_FILE: $DIR_CONFIG_FILE"
echo "-------------------------------------"

# Local script path
local_script_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
resource_detector_script="$local_script_path/utils/resource_detection.sh" # absolute path to resource_detection.sh


EXECUTE_RESOURCE_DETECTION () {

    # check if resource_detector script exists
    if [ ! -f "$resource_detector_script" ]; then
        echo "ERROR: [$resource_detector_script] does not exist."
        exit 1
    fi

    if [ "$REMOTE_SERVER" != "local" ]; then
        echo "Checking remote server storage..."

        echo "Executing [$resource_detector_script] at [$remote_server_login]..."
        # Execute the remote script via SSH
        if [ ! -z "$IDENTITY_FILE" ]; then
            ssh -i "$IDENTITY_FILE" $remote_server_login 'bash -s' < "$resource_detector_script" "$LOG_LEVEL" "$CHECK_USER" "$DIR_CONFIG_FILE"
        else
            ssh $remote_server_login 'bash -s' < "$resource_detector_script" "$LOG_LEVEL" "$CHECK_USER" "$DIR_CONFIG_FILE"
        fi

        # Collect the output DIR_CONFIG_FILE back to the local machine
        echo "Collect the output [$DIR_CONFIG_FILE] back to the local machine..."
        if [ ! -z "$IDENTITY_FILE" ]; then
            scp -i "$IDENTITY_FILE" "$remote_server_login:$HOME/$DIR_CONFIG_FILE" "$local_script_path"
        else
            scp "$remote_server_login:$HOME/$DIR_CONFIG_FILE" "$local_script_path"
        fi

    else
        echo "Checking local server storage..."
        bash "$resource_detector_script" "$LOG_LEVEL" "$CHECK_USER" "$DIR_CONFIG_FILE"
    fi

}

# if DIR_CONFIG_FILE exists, and not empty, then skip resource detection
if [ -f "$DIR_CONFIG_FILE" ] && [ -s "$DIR_CONFIG_FILE" ]; then
    echo "Skipping resource detection..."
else
    EXECUTE_RESOURCE_DETECTION
fi


# Show the output file
echo "-------------------------------------"
echo "Storage Resource File: $local_script_path/$DIR_CONFIG_FILE"
cat "$local_script_path/$DIR_CONFIG_FILE"
echo "-------------------------------------"



# Function to check input options
CHECK_DATA_TRANSFER_INPUT() {

    # Check variables
    if [ -z "$DIR_CONFIG_FILE" ]; then
        echo "Error: option [-o <storage info file>] must be provided"
        usage
        exist 1
    fi

    # Check if the storage info file exists
    if [ ! -f "$USER_DATA_LIST" ]; then
        echo "Error: storage info file [$DIR_CONFIG_FILE] does not exist"
        usage
        exist 1
    fi

    # Check if the storage info file is empty
    if [ ! -s "$USER_DATA_LIST" ]; then
        echo "Error: storage info file [$DIR_CONFIG_FILE] is empty"
        usage
        exist 1
    fi

    # Check if the user data list file exists
    if [ ! -f "$USER_DATA_LIST" ]; then
        echo "Error: user data list file [$USER_DATA_LIST] does not exist"
        usage
        exist 1
    fi

    # Check if the user data list file is empty
    if [ ! -s "$USER_DATA_LIST" ]; then
        echo "Error: user data list file [$USER_DATA_LIST] is empty"
        usage
        exist 1
    fi

}

local_transfer_script="$local_script_path/utils/local_move_data_to_target.sh" # absolute path to local_data_transfer.sh
remote_transfer_script="$local_script_path/utils/remote_move_data_to_target.sh" # absolute path to remote_data_transfer.sh

EXECUTE_DATA_TRANSFER (){
    echo "Executing data transfer..."
    
    if [ "$REMOTE_SERVER" != "local" ]; then
        echo "Executing [$remote_transfer_script] for [$remote_server_login]..."
        bash "$remote_transfer_script" "$DIR_CONFIG_FILE" "$USER_DATA_LIST" "$MODE" "$LOG_LEVEL" "$remote_server_login" "$IDENTITY_FILE"
    else
        echo "Executing [$local_transfer_script]..."
        bash "$local_transfer_script" "$DIR_CONFIG_FILE" "$USER_DATA_LIST" "$MODE" "$LOG_LEVEL"
    fi

}

# Check if USER_DATA_LIST is given
if [ ! -z "$USER_DATA_LIST" ]; then
    CHECK_DATA_TRANSFER_INPUT
    EXECUTE_DATA_TRANSFER
fi