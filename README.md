# linux_resource_detect
finding resource in linux using shell scripts.
## Requirement
Bash Version 4.2.46(2) or later.

## Current implementation
Use `remote_data_transfer.sh` to:
1. Find all user usable paths
2. (Optional) Move data the the fastest discovered path 

Type `remote_data_transfer.sh -h` for usage.
```bash
Usage: remote_data_transfer.sh [-u <user name>] [-s <remote server>] [-i <identity file>]
           [-o <output file>] [-d <data file>] [-m <mode>]
           [-log <log level>] [-h]
Options:
  -u, --user <user name>: User name to check (default: current user)
  -s, --server <remote server>: Remote server name
  -i, --identity <identity file>: Identity file to use for SSH connection
  -o, --output <output file>: File with all detected user storage paths
  -d, --data <data file>: Path to the file containing absolute user data file paths
  -m, --mode <mode>: Mode (0 - do not restore user data, 1 - restore user data, default: 1 for testing)
  -log, --log-level <log level>: Log level (0 - minimal log, 1 - full log, default: 1)
  -h, --help: Display this help and exit
```

## 1. Storage Resource Detection
Example Usages:
- To detect storage at current node:
  - Default output to a file `local_dir_config.csv`. 
  - If this file exists when you run the program, the program simply print this file.
```bash
bash remote_data_transfer.sh
```
- Tod detect storage at remote server:
  - Default output to a file `{server_name}_dir_config.csv`. 
```bash
bash remote_data_transfer.sh -s deception -i /path_to/.ssh/id_rsa
```
- Tod detect storage at remote node:
  - Default output to a file `{hostname}_dir_config.csv`. 
```bash
bash remote_data_transfer.sh -s deception -i /path_to/.ssh/id_rsa
```


## 1. Move Data to Target Storage
- Must input the file containign list of absolute path of files with this format:
```txt
/my_path_to/mydata1.txt
/my_path_to/mydata2.txt
```
- To move user data to the fastest storage at a server:
```bash
bash remote_data_transfer.sh -s deception -d user_data_files.txt 
```

### Current Limivations
Currently the has the below limitation:
- Check constraints of the destination storage and only choose from storage that is larger than the total user data size
- Hardcoded to use "Write_Bandwidth" as a selector for destination storage
- Data transfer cost only collects duration time and calculated the bandwidth


## Functions in Utils
The `./utils` folder contains the utility script that user does not need to use. Below are information for knowledge. \
- Use `resource_detection.sh` to find all user usable paths.
```
Usage: resource_detection.sh <log level> <user name> <config file>
Options:
  <log level>     Log level: 0 - minimal log, 1 - full log
  <user name>     User name to check
  <config file>   Path to the directory configuration file
```

- Use `remote_move_data_to_target.sh` to move data to remote server storage target.
```
Usage: remote_move_data_to_target.sh [DIR_CONFIG_FILE] [USER_DATA_LIST] [MODE] [LOG_LEVEL] [REMOTE_SERVER_LOGIN] [IDENTITY_FILE]
Options:
  DIR_CONFIG_FILE       Path to the directory configuration file.
  USER_DATA_LIST        Path to the user data list file.
  MODE                  Mode (0 - do not restore user data, 1 - restore user data, default: 1 for testing).
  LOG_LEVEL             Log level (0 - minimal log, 1 - full log, default: 1).
  REMOTE_SERVER_LOGIN   Remote server login name user_name@remote_server_ip.
  IDENTITY_FILE         Identity file for SSH connection (optional).
```

- Use `remote_move_data_to_target.sh` to move data to remote server storage target.
```
Usage: remote_move_data_to_target.sh [DIR_CONFIG_FILE] [USER_DATA_LIST] [MODE] [LOG_LEVEL] [REMOTE_SERVER_LOGIN] [IDENTITY_FILE]
Options:
  DIR_CONFIG_FILE       Path to the directory configuration file.
  USER_DATA_LIST        Path to the user data list file.
  MODE                  Mode (0 - do not restore user data, 1 - restore user data, default: 1 for testing).
  LOG_LEVEL             Log level (0 - minimal log, 1 - full log, default: 1).
  REMOTE_SERVER_LOGIN   Remote server login name user_name@remote_server_ip.
  IDENTITY_FILE         Identity file for SSH connection (optional).
```

- Use `local_move_data_to_target.sh` to move data to local node storage target.
```
Usage: local_move_data_to_target.sh <DEST_PATH> <USER_DATA_LIST> <MODE> <LOG_LEVEL>
Options:
  <DEST_PATH>         Destination path to where data will be copied.
  <USER_DATA_LIST>    Path to the user data list file.
  <MODE>              Mode (0 - do not restore user data, 1 - restore user data, default: 0 for testing).
  <LOG_LEVEL>         Log level (0 - minimal log, 1 - full log, default: 1).
```




#### Notes
Tests moving data
- select the fastest FS (highest bandwidth)
- move data to fastest place
	- the initial data should be different than final location
	- check performance during moving the data, capture movement cost
		- latency, bandwidth, (future compute cost)
		- user give input list of initial data location
		- output data final location, output amount of data moved, movement statistics (cost)

Keep in mind:
- ** energy efficiency
	- parameters for tracking energy consumption