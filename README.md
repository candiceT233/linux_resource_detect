# linux_resource_detect
finding resource in linux using shell scripts

## Current implementation
Use `find_all_user_storage.sh` to find all user usable paths. Type `find_all_user_storage.sh -h` for usage.
```
Usage: ./find_all_user_storage.sh [-u <user name>] [-log <log level>] [-f <user data file>]
Options:
  -u, --user        User name to check, default is current user
  -log, --log-level Log level: 0 - minimal log, 1 - full log, default is 1
  -o, --output        File with all detected user storage paths
  -h, --help        Display this help and exit
```

Use `move_data_to_target.sh` to move user data to destination. Type `move_data_to_target.sh -h` for usage.
```
Both -c or --conf and -d or --data options are required.
Usage: ./move_data_to_target.sh [-c|--conf <CURR_STORAGE_CONF>] [-d|--data <USER_DATA_LIST>] [-l|--log-level <LOG_LEVEL>]
Options:
  -c, --conf <CURR_STORAGE_CONF>: Path to the current storage configuration file.
  -d, --data <USER_DATA_LIST>: Path to the file containing absolute user data file paths.
  -l, --log-level <LOG_LEVEL>: Log level: 0 - minimal log, 1 - full log, default is 1
  -h, --help: Display this help and exit
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