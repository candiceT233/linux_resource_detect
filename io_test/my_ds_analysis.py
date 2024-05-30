## Desription: This script will take a folder of darshan logs and generate a summary of the logs
## Required Libraries: darshan
## Usage: python my_ds_analysis.py <path_to_folder>
## Example: python my_ds_analysis.py /home/username/darshan_logs

## My parameter to analyze darshan logs:
## 1. POSIX and STDIO bandwidth
## 2. POSIX and STDIO read/write count
## 3. POSIX and STDIO read/write time
## 4. POSIX and STDIO read/write size
## 5. POSIX and STDIO read/write I/O time portion



import darshan
import sys
import os
import json 
import statistics 


## Get siftSTFByMisfit.py input file size
def get_t2_io_size(log_folder, folder_name):

    # get the log file name from folder_name
    log_file_name = folder_name.replace("_darshan_logs", ".log")
    log_file_path = log_folder.replace(folder_name, "")
    print("log_file_name: " + log_file_name)
    # Check if log file exitst
    if not os.path.exists(log_file_path + "/" + log_file_name):
        print(f"Log file does not exist in {log_file_path}")
        sys.exit(1)

    # Get the line start with "du -k" in log file
    du_line = ""
    file_io_kb = {}
    with open(log_file_path + "/" + log_file_name, "r") as f:
        for line in f:
            if "du -k" in line:
                du_line = line
                # print("du_line: " + du_line)
                # Read all lines after du_line and get file_size
                for line in f:
                    file_name = line.split()[1]
                    # Get file size in KB
                    file_io_kb[file_name] = int(line.split()[0])
    # print("file_io_kb: ")
    # print(file_io_kb)
    return file_io_kb

## -------------------------------------
def get_darshan_report(ds_log_path):
    # Get report
    report = darshan.DarshanReport(ds_log_path, read_all=False)
    print("report: ")
    for k,v in report.data.items():
        # # Check if v dict is empty
        # if v and (k == "modules" or k == "metadata"):
        #     print(k)
        #     print(v)
        if v:
            print(k)
            print(v)

## Use bash command darshan-dxt-parser to analyze the darshan log
def get_t2_read_stat(darshan_files, log_folder):
    file_io_stat = {}
    for ds_log in darshan_files:
        # Only get python task2 now
        if "python" in ds_log:
            get_darshan_report(log_folder + "/" + ds_log)
            bash_cmd="darshan-dxt-parser " + log_folder + "/" + ds_log
            # print("Running: " + bash_cmd)
            # Run command and collect stdout
            dxt_out = os.popen(bash_cmd).read()
            # Find line contain ".stf" print lines after it
            lines = dxt_out.split("\n")
            for l in lines:
                if ".stf" in l and "file_name:" in l:
                    # Get file_name in l
                    file_name = l.split("file_name:")[1].strip()
                    op_cnt_line = lines[lines.index(l)+2]
                    # Get read/write count from string "# DXT, write_count: 1, read_count: 0"
                    write_count = int(op_cnt_line.split(",")[1].split(":")[1].strip())
                    read_count = int(op_cnt_line.split(",")[2].split(":")[1].strip())
                    # print(f"File: {file_name}, Read Count: {read_count}, Write Count: {write_count}")

                    base_line_skip = 4
                    header_line = lines[lines.index(l)+base_line_skip]
                    header_line = header_line.split()[1:] # remove first element in header_line "#"
                    base_line_skip+=1
                    next_line = lines[lines.index(l)+base_line_skip]
                    # continue if next_line is not empty
                    while next_line != "":
                                            
                        data_line = lines[lines.index(l)+5]
                        # Convert header_line and data_line to dict
                        
                        data_line = data_line.split()
                        io_stat = {}
                        for index in range(len(header_line)):
                            io_stat[header_line[index]] = data_line[index]
                        
                        next_line = lines[lines.index(l)+base_line_skip]
                        base_line_skip+=1                   
                    
                    file_io_stat[file_name] = io_stat
                    file_io_stat[file_name]["read_count"] = read_count
                    file_io_stat[file_name]["write_count"] = write_count
            # print("file_io_stat: ")
            # print(file_io_stat)
    return file_io_stat


def get_bw(file_io_stat):
    all_bw_kb = []
    all_io_size_kb = 0.0
    all_io_time_sec = 0.0
    for file_name, io_stat in file_io_stat.items():
        if file_name in file_io_stat:
            # print("file_io_stat: ")
            # print(file_io_stat[file_name])
            start_time_sec = float(file_io_stat[file_name]["Start(s)"])
            end_time_sec = float(file_io_stat[file_name]["End(s)"])
            io_time_sec = end_time_sec - start_time_sec
            io_size = int(io_stat['Length']) / 1024
            all_io_size_kb += io_size
            all_io_time_sec += io_time_sec
            # print(f"File: {file_name}, Size: {io_size} KB, Time: {io_time_sec:.4f} sec, Bandwidth: {bandwidth:.4f} KB/s")
    # Convert to MB/s
    if all_io_time_sec == 0:
        all_bw_mb = 0
    else:
        all_bw_mb = all_io_size_kb / all_io_time_sec / 1024
    return all_bw_mb

def get_read_write_count(file_io_stat):
    read_count = 0
    write_count = 0
    for file_name, io_stat in file_io_stat.items():
        if file_name in file_io_stat:
            read_count += io_stat['read_count']
            write_count += io_stat['write_count']
    return read_count, write_count

def get_io_size(file_io_stat):
    all_io_size_kb = 0.0
    for file_name, io_stat in file_io_stat.items():
        if file_name in file_io_stat:
            io_size = int(io_stat['Length']) / 1024
            all_io_size_kb += io_size
    return all_io_size_kb


def t2_trial_bw(log_folder):
    # Get all .darshan files in folder
    darshan_files = [f for f in os.listdir(log_folder) if f.endswith('.darshan')]

    # Check if there are any .darshan files
    if len(darshan_files) == 0:
        print("No .darshan files found in folder")
        sys.exit(1)
    else:
        # Print the list of files
        print("Found %d .darshan files in folder" % len(darshan_files))
        # print(darshan_files)

    ## Use bash to merge darshan files and generate a summary PDF
    # Get current folder name
    folder_name = os.path.basename(os.path.normpath(log_folder))
    output_file = log_folder + "/" + folder_name + ".darshan"
    # run only if the output file does not exist
    if os.path.exists(output_file):
        print("WARNING: Output file already exists")
    else:
        bash_cmd="darshan-merge " + log_folder + "/*.darshan" + " --output " + output_file
        # Run the bash command
        # print("Running: " + bash_cmd)
        os.system(bash_cmd)

    # file_io_kb = get_t2_io_size(log_folder, folder_name)
    file_io_stat = get_t2_read_stat(darshan_files, log_folder)
    all_bw_mb = get_bw(file_io_stat)
    read_cnt, write_cnt = get_read_write_count(file_io_stat)
    io_size_kb = get_io_size(file_io_stat)

    return {
        "bandwidth": all_bw_mb,
        "read_count": read_cnt,
        "write_count": write_cnt,
        "io_size_kb": io_size_kb
    }

def get_t2_average_bw(log_folder_base):

    # Get current folder path
    curr_path = os.path.dirname(os.path.realpath(__file__))
    print("curr_path: " + curr_path)
    log_folders = [log_folder_base, log_folder_base.replace("_1_", "_2_"), log_folder_base.replace("_1_", "_3_")]

    # Check if folder exists
    all_trial_bw_mb = []
    all_trial_read_count = []
    all_trial_write_count = []
    all_trial_io_size_kb = []
    for log_folder in log_folders:
        log_full_path = curr_path + "/" + log_folder
        if not os.path.exists(log_full_path):
            print(f"Folder {log_full_path} does not exist")
            sys.exit(1)

        log_io_stat = t2_trial_bw(log_full_path)
        all_trial_bw_mb.append(log_io_stat['bandwidth'])
        all_trial_read_count.append(log_io_stat['read_count'])
        all_trial_write_count.append(log_io_stat['write_count'])
        all_trial_io_size_kb.append(log_io_stat['io_size_kb'])
        # print(f"Trial [{log_folder}] Bandwidth: {trial_bw_mb:.4f} MB/s Read Count: {trial_op_read} Write Count: {trial_op_write}")
        print("-------------------------------------------------")
    
    print(f"T2 Trial Ave Bandwidth: {sum(all_trial_bw_mb)/len(all_trial_bw_mb):.4f} MB/s")
    print(f"T2 Trial Ave Read Count: {sum(all_trial_read_count)/len(all_trial_read_count)}")
    print(f"T2 Trial Ave Write Count: {sum(all_trial_write_count)/len(all_trial_write_count)}")
    print(f"T2 Trial Ave IO Size: {sum(all_trial_io_size_kb)/len(all_trial_io_size_kb):.4f} KB")
    if sum(all_trial_read_count) != 0:
        print(f"T2 Trial Ave Read Size: {sum(all_trial_io_size_kb)/sum(all_trial_read_count):.4f} KB")
    if sum(all_trial_write_count) != 0:
        print(f"T2 Trial Ave Write Size: {sum(all_trial_io_size_kb)/sum(all_trial_write_count):.4f} KB")


def gen_t1_pdf_summary(log_folder_base):
    # Get current folder path
    curr_path = os.path.dirname(os.path.realpath(__file__))
    print("curr_path: " + curr_path)
    log_folders = [log_folder_base, log_folder_base.replace("_1_", "_2_"), log_folder_base.replace("_1_", "_3_")]
    new_folder_name = log_folder_base.replace("_1_", "_ave_")
    new_foler_path = curr_path + "/" + new_folder_name
    # Make a new folder to store all *iterdecon*.darshan files
    if not os.path.exists(new_foler_path):
        os.makedirs(new_foler_path)
        print(f"Created folder {new_foler_path}")
    else:
        # cleanup the folder if it already exists
        os.system(f"rm -rf {new_foler_path}/*")

    # Collect all *iterdecon*.darshan file into a folder
    for log_folder in log_folders:
        log_folder_path = curr_path + "/" + log_folder
        # Get all *iterdecon*.darshan files in folder
        darshan_files = [f for f in os.listdir(log_folder_path) if f.endswith('.darshan')]
        for ds_file in darshan_files:
            if 'iterdecon' in ds_file:
                # Copy the file to new folder
                os.system(f"cp {log_folder_path}/{ds_file} {new_foler_path}")
    # Print the list of files in new_foler_path
    print(f"Copied {len(os.listdir(new_foler_path))} *iterdecon*.darshan files to folder {new_foler_path}")

    # Get concurrency of current test (number after p)
    concurrency = int(log_folder_base.split("p")[1].split("_")[0])
    summed_concurrency = concurrency * 3

    ## Merge all *iterdecon*.darshan files
    # PDF Note: [BW, POSIX I/O Accesses] are averaged. 
    # PDF Note: [Average I/O per process (POSIX and STDIO)] is summed.
    # PDF Note: [Data Transfer Per Filesystem (POSIX and STDIO)] is summed.
    # PDF Note: [runtime] is summed.
    merge_file_name = f"{new_folder_name}_d{summed_concurrency}"
    darshan_merge_cmd = f"darshan-merge {new_foler_path}/*.darshan --output {new_foler_path}/{merge_file_name}.darshan"
    # print("Running: " + darshan_merge_cmd)
    os.system(darshan_merge_cmd)

    ## Generate PDF summary
    pdf_summary_cmd = f"darshan-job-summary.pl {new_foler_path}/{merge_file_name}.darshan --output {curr_path}/{merge_file_name}.pdf"
    # print("Running: " + pdf_summary_cmd)
    os.system(pdf_summary_cmd)

    # Print PDF sum note
    print(f"Summed statistics should divide by {summed_concurrency} to get average statistics")


def gen_t1_json_summary(log_folder_base):
    # Get current folder path
    curr_path = os.path.dirname(os.path.realpath(__file__))
    print("curr_path: " + curr_path)
    log_folders = [log_folder_base, log_folder_base.replace("_1_", "_2_"), log_folder_base.replace("_1_", "_3_")]
    new_folder_name = log_folder_base.replace("_1_", "_ave_")
    new_foler_path = curr_path + "/" + new_folder_name
    # Make a new folder to store all *iterdecon*.darshan files
    if not os.path.exists(new_foler_path):
        os.makedirs(new_foler_path)
        print(f"Created folder {new_foler_path}")
    else:
        # cleanup the folder if it already exists
        os.system(f"rm -rf {new_foler_path}/*")

    # Collect all *iterdecon*.darshan file into a folder
    for log_folder in log_folders:
        log_folder_path = curr_path + "/" + log_folder
        # Get all *iterdecon*.darshan files in folder
        darshan_files = [f for f in os.listdir(log_folder_path) if f.endswith('.darshan')]
        for ds_file in darshan_files:
            if 'iterdecon' in ds_file:
                # Copy the file to new folder
                os.system(f"cp {log_folder_path}/{ds_file} {new_foler_path}")
    # Print the list of files in new_foler_path
    print(f"Copied {len(os.listdir(new_foler_path))} *iterdecon*.darshan files to folder {new_foler_path}")

    trials_io_stat = {}
    # Get stats from all files in new_foler_path
    for ds_file in os.listdir(new_foler_path):
        # get_darshan_report(f"{new_foler_path}/{ds_file}")
        # convert to json
        convert_cmd = f"python -m darshan to_json {new_foler_path}/{ds_file}" # {new_foler_path}/{ds_file}.json
        # Run command and collect stdout without showing in terminal
        json_stat_string = os.popen(convert_cmd).read()
        # convert json_stat_string to dict
        json_stat = json.loads(json_stat_string)

        # for k,v in json_stat.items():
        #     print(k)
        #     print(v)
        # print("-------------------------------------------------")

        json_metadata = json_stat['metadata']['job']
        # start_time_nsec = json_metadata['start_time_nsec']
        # end_time_nsec = json_metadata['end_time_nsec']
        # duration_sec = abs((end_time_nsec - start_time_nsec) / 1e9) # convert to seconds
        duration_sec = json_metadata['run_time']


        json_records = json_stat['records']
        record_module = "STDIO"

        io_stat_keys = json_stat['counters'][record_module]['counters']
        
        total_counters = []
        for io_stat in json_records[record_module]:
            curr_io_stat = list(io_stat['counters'])
            if len(total_counters) == 0:
                total_counters = curr_io_stat
            else:
                # add each index element to total_counter
                for i in range(len(total_counters)):
                    total_counters[i] += curr_io_stat[i]

        # Save counters to header
        io_stat_data = {}
        for i in range(len(total_counters)):
            io_stat_data[io_stat_keys[i]] = total_counters[i]
        # print(f"Total {record_module} data: {io_stat_data}")
        # trials_io_stat[ds_file] = io_stat_data
        read_cnt = io_stat_data[f'{record_module}_READS']
        write_cnt = io_stat_data[f'{record_module}_WRITES']
        read_size_byte = io_stat_data[f'{record_module}_BYTES_READ']
        write_size_byte = io_stat_data[f'{record_module}_BYTES_WRITTEN']
        stdio_open = io_stat_data[f'{record_module}_OPENS']

        read_ave_kb = read_size_byte / read_cnt / 1024 if read_cnt != 0 else 0
        write_ave_kb = write_size_byte / write_cnt / 1024 if write_cnt != 0 else 0

        read_bw_mb = read_size_byte/(1024*1024) / duration_sec
        write_bw_mb = write_size_byte/(1024*1024) / duration_sec

        trials_io_stat[ds_file] = {'read_cnt': read_cnt, 'write_cnt': write_cnt, 
                                   'read_size_byte': read_size_byte, 'write_size_byte': write_size_byte, 
                                   'stdio_open': stdio_open, 'read_ave_kb': read_ave_kb, 'write_ave_kb': write_ave_kb,
                                   'dureation_sec': duration_sec, 'read_bw_mb': read_bw_mb, 'write_bw_mb': write_bw_mb}

    all_read_cnt = []
    all_write_cnt = []
    all_read_size_byte = []
    all_write_size_byte = []
    all_stdio_open = []
    all_read_ave_kb = []
    all_write_ave_kb = []
    all_duration_sec = []
    all_read_bw_mb = []
    all_write_bw_mb = []


    for trial, io_stat in trials_io_stat.items():
        print(f"Trial: {trial}, IO Stat: {io_stat}")
        all_read_cnt.append(io_stat['read_cnt'])
        all_write_cnt.append(io_stat['write_cnt'])
        all_read_size_byte.append(io_stat['read_size_byte'])
        all_write_size_byte.append(io_stat['write_size_byte'])
        all_stdio_open.append(io_stat['stdio_open'])
        all_read_ave_kb.append(io_stat['read_ave_kb'])
        all_write_ave_kb.append(io_stat['write_ave_kb'])
        all_duration_sec.append(io_stat['dureation_sec'])
        all_read_bw_mb.append(io_stat['read_bw_mb'])
        all_write_bw_mb.append(io_stat['write_bw_mb'])
    print()

    # caculate stadard deviation
    ave_read_bw_stdev = statistics.pstdev(all_read_bw_mb)
    ave_write_bw_stdev = statistics.pstdev(all_write_bw_mb)

    # Print trial averages
    print(f"T1 Trial Ave Read Count: {sum(all_read_cnt)/len(all_read_cnt)}")
    print(f"T1 Trial Ave Write Count: {sum(all_write_cnt)/len(all_write_cnt)}")
    print(f"T1 Trial Ave Read Size: {sum(all_read_size_byte)/len(all_read_size_byte)}")
    print(f"T1 Trial Ave Write Size: {sum(all_write_size_byte)/len(all_write_size_byte)}")
    print(f"T1 Trial Ave STDIO Open: {sum(all_stdio_open)/len(all_stdio_open)}")
    print(f"T1 Trial Ave Read Ave KB: {sum(all_read_ave_kb)/len(all_read_ave_kb):.4f}")
    print(f"T1 Trial Ave Write Ave KB: {sum(all_write_ave_kb)/len(all_write_ave_kb):.4f}")
    print(f"T1 Trial Ave Duration (sec): {sum(all_duration_sec)/len(all_duration_sec):.4f}")
    print(f"T1 Trial Ave Read BW (MB/s): {sum(all_read_bw_mb)/len(all_read_bw_mb):.4f}")
    print(f"T1 Trial Ave Write BW (MB/s): {sum(all_write_bw_mb)/len(all_write_bw_mb):.4f}")
    print(f"T1 Trial Ave Read BW Stdev: {ave_read_bw_stdev:.4f}")
    print(f"T1 Trial Ave Write BW Stdev: {ave_write_bw_stdev:.4f}")


if __name__ == "__main__":

    # Get log folder from sys.argv
    log_folder_base = sys.argv[1]

    # # Get list of folder in log_folder
    # folders = [f for f in os.listdir(log_folder) if os.path.isdir(os.path.join(log_folder, f))]

    
    get_t2_average_bw(log_folder_base)
    print()

    # gen_t1_pdf_summary(log_folder_base)
    gen_t1_json_summary(log_folder_base)







## My parameter to analyze workflow logs: (TODO)
## 1. Total task time

## My graphs to generate(TODO):
## 1. POSIX and STDIO bandwidth per task read/write vs. concurrency

"""
dir(darshan)
['DarshanReport', '__builtins__', '__cached__', '__darshanutil_version__', 
'__doc__', '__file__', '__loader__', '__name__', '__package__', '__path__', 
'__spec__', '__version__', 'backend', 'datatypes', 'discover_darshan', 
'enable_experimental', 'logger', 'logging', 'options', 'report']


dir(report):  ['__add__', '__class__', '__deepcopy__', '__del__', 
'__delattr__', '__dict__', '__dir__', '__doc__', '__enter__', 
'__eq__', '__exit__', '__format__', '__ge__', '__getattribute__', 
'__gt__', '__hash__', '__init__', '__init_subclass__', 
'__le__', '__lt__', '__module__', '__ne__', '__new__', 
'__reduce__', '__reduce_ex__', '__repr__', '__setattr__', 
'__sizeof__', '__str__', '__subclasshook__', '__weakref__', 
'_cleanup', '_counters', '_heatmaps', '_metadata', '_modules', 
'_mounts', 'automatic_summary', 'converted_records', 'counters', 
'data', 'data_revision', 'dtype', 'end_time', 'filename', 
'heatmaps', 'info', 'log', 'lookup_name_records', 'metadata', 
'mod_read_all_apmpi_records', 'mod_read_all_apxc_records', '
mod_read_all_dxt_records', 'mod_read_all_lustre_records',
 'mod_read_all_records', 'mod_records', 'modules', 'mounts', 
 'name_records', 'open', 'provenance_enabled', 'provenance_graph', 
 provenance_reports', 'read_all', 'read_all_dxt_records', 
 'read_all_generic_records', 'read_all_heatmap_records', 
 'read_metadata', 'rebase_timestamps', 'records', 'start_time', 
 'summary', 'summary_revision', 'timebase', 'to_dict', 
 'to_json', 'update_name_records']

 dir(darshan.report)
 ['DarshanRecordCollection', 'DarshanReport', 'DarshanReportJSONEncoder', 
 'Heatmap', 'ModuleNotInDarshanLog', '__builtins__', '__cached__', 
 '__doc__', '__file__', '__loader__', '__name__', '__package__', 
 '__spec__', 'backend', 'collections', 'copy', 'datetime', 'json', 
 'logger', 'logging', 'np', 'pd', 're', 'sys']
"""
