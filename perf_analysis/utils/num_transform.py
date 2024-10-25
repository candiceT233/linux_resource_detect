from sklearn import preprocessing
from sklearn.metrics import mean_squared_error, mean_absolute_percentage_error, r2_score, mean_absolute_percentage_error


# For 2D analysis
from sklearn.preprocessing import PolynomialFeatures
from sklearn.linear_model import LinearRegression
from scipy.optimize import curve_fit
from sklearn.preprocessing import MinMaxScaler
# from utils import period2freq, freq2period

# For PCA
from sklearn.decomposition import PCA
from sklearn.preprocessing import StandardScaler
from scipy.optimize import curve_fit
from sklearn.metrics import mean_squared_error

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
import json
import csv
import time
import glob
import os


# Datasize in KB
data_size_kb = {'4mb': 4096, '16mb': 16384, '64mb': 65536,
            '256mb': 262144, '512mb': 524288, '1gb': 1048576,
            '5gb': 5242880, '50gb': 52428800, '100gb': 104857600,
            '300gb': 314572800,}

# Key Parameters
IOR_PARAMS = ['operation', 'randomOffset', 'transferSize', 
            'aggregateFilesizeMB', 'numTasks', 'totalTime', 
            'numNodes', 'tasksPerNode', 'bwMiB', "storageType"]

TARGET_PARAMS = [ "bestStorage" ]
op_dict = {0: "write", 1: "read"}

def byte_size_to_human_size(byte_size):
    if byte_size < 1024:
        return f"{byte_size} B"
    elif byte_size < 1024**2:
        return f"{byte_size/1024} KiB"
    elif byte_size < 1024**3:
        return f"{byte_size/1024**2} MiB"
    elif byte_size < 1024**4:
        return f"{byte_size/1024**3} GiB"
    else:
        return f"{byte_size/1024**4} TiB"


def file_size_to_mb(file_size):
    # If file_size is a string, convert to float
    if isinstance(file_size, str):
        # Translate KiB, MiB, and GiB to bytes
        size_num, size_unit = file_size.split()
        size_num = float(size_num)
        
        if size_unit == "KiB":
            return size_num / 1024  # Convert KiB to MB
        elif size_unit == "MiB":
            return size_num  # Already in MB
        elif size_unit == "GiB":
            return size_num * 1024  # Convert GiB to MB
        else:
            raise ValueError(f"Unknown size unit: {size_unit}")
    elif isinstance(file_size, (int, float)):
        # If file_size is an integer or float, assume it's in bytes and convert to MB
        return file_size / (1024 ** 2)  # Convert bytes to MB
    else:
        raise TypeError("file_size must be a string or a number")