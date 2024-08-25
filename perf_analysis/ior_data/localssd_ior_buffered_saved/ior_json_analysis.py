# Python script to collect json data from IOR output files and generate a summary

import os
import json
import sys
import numpy as np
import matplotlib.pyplot as plt
# import pandas as pd
# import seaborn as sns

def get_json_data(json_file):
    with open (json_file, "r") as f:
        data = json.load(f)
    return data

# Get the target parameter from the 3 trials
def get_data_from_trials(t1_json_file, param):
    t2_json_file = t1_json_file.replace("_1.json", "_2.json")
    t3_json_file = t1_json_file.replace("_1.json", "_3.json")
    all_json_files = [t1_json_file, t2_json_file, t3_json_file]
    print("all_json_files: ", all_json_files)
    data = {"write": [], "read": []}
    for json_file in all_json_files:
        json_data = get_json_data(json_file)
        summary = json_data["summary"]

        if len(summary) >= 1:
            write_summary = summary[0]
            if write_summary['operation'] != "write":
                print("Error: operation is not write")
                sys.exit(1)
            data['write'].append(write_summary[param])
        
        if len(summary) >= 2:
            read_summary = summary[1]
            if read_summary['operation'] != "read":
                print("Error: operation is not read")
                sys.exit(1)
            data['read'].append(read_summary[param])

    t3_summary = {"write(MiB/sec)": sum(data['write'])/len(data['write']), "read(MiB/sec)": sum(data['read'])/len(data['read'])}
    # only keep 4 decimal places
    t3_summary = {key: round(value, 4) for key, value in t3_summary.items()}

    print("t3_summary: ", t3_summary)

# main function
def main():
    # check if the number of arguments is correct
    if len(sys.argv) != 3:
        print("Usage: python ior_json_analysis.py json_file_path json_file_basename")
        sys.exit(1)
    
    json_file_path = sys.argv[1]
    json_file_basename = sys.argv[2]

    json_file = sys.argv[1]

    data = get_data_from_trials(json_file, "bwMeanMIB")

if __name__ == "__main__":
    main()