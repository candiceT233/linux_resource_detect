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


def plot_heatmap(corrM,outfile):
    plt.figure(figsize=(14, 8))
    #labels = list(corrM.columns)
    plt.subplots_adjust(bottom=0.19)

    # # use only lower triangle
    # corrM = corrM.where(np.triu(np.ones(corrM.shape)).astype(np.bool))

    ## plot all correlation heatmap
    map = sns.heatmap(corrM, vmin=-1, vmax=1,
        linewidths=0.5, linecolor='grey', cmap='BrBG') #annot=True,
    map.set_title('Correlation Matrix Heatmap', fontdict={'fontsize':12}, pad=12)
    #plt.show()
    out_file=f'{outfile}.png'
    plt.savefig(out_file)
    plt.clf()

def get_redundant_pairs(df):
    '''Get diagonal and lower triangular pairs of correlation matrix'''
    pairs_to_drop = set()
    cols = df.columns
    for i in range(0, df.shape[1]):
        for j in range(0, i+1):
            pairs_to_drop.add((cols[i], cols[j]))
    return pairs_to_drop
    
def corrM_sorted_csv(corrM, outfile):
  n=5
  au_corr = corrM.corr().abs().unstack()
  labels_to_drop = get_redundant_pairs(corrM)
  au_corr = au_corr.drop(labels=labels_to_drop).sort_values(ascending=False)
  sorted_corrM = au_corr[0:n]

  out_file= outfile
  sorted_corrM.to_csv(out_file)

def corr_matrix(df,outname=""):

    # calculte correlation matrix
    corrM = df.corr()

    corrM.to_csv(f'{outname}.csv')
    plot_heatmap(corrM,outname)
    #corrM_sorted_csv(corrM, f'sorted_{outname}.csv')

def _2d_trend(X, y, x_label="x-axis", y_label="bwMiB", title="", show=False):
        # X = X.reshape(-1, 1)
        X = X.values.reshape(-1, 1)
        # poly = PolynomialFeatures(degree=2)
        poly = PolynomialFeatures(degree=1)
        poly_data = poly.fit_transform(X)
        model = LinearRegression()
        model.fit(poly_data,y)
        coef = model.coef_
        intercept = model.intercept_
        # Set figure size (80,50)
        plt.figure(figsize=(10,5))

        plt.scatter(X,y,color='red')
        plt.plot(X,model.predict(poly.fit_transform(X)),color='blue')
        # Show the fit parameters on graph with scientific notation
        plt.annotate(f"y = {coef[1]:.2e}x + {intercept:.2e}", xy=(0.05, 0.95), xycoords='axes fraction')

        # print(f"y = {coef[1]}x + {intercept}")
        plt.legend(['Original','Prediction'])
        plt.xlabel(x_label)
        plt.ylabel(y_label)
        plt.title(title)
        if show:
            plt.show()
        return coef[1], intercept

def _3d_trend(x,y,z, title=""):
    # ref: https://stackoverflow.com/questions/2298390/fitting-a-line-in-3d
    # Convert Pandas Series to NumPy arrays
    x = x.to_numpy()
    y = y.to_numpy()
    z = z.to_numpy()
    
    data = np.concatenate((x[:, np.newaxis], 
                        y[:, np.newaxis], 
                        z[:, np.newaxis]), 
                        axis=1)
    
    data = data.astype('float64')

    # Calculate the mean of the points, i.e. the 'center' of the cloud
    datamean = data.mean(axis=0)
    print(datamean)

    # Do an SVD on the mean-centered data.
    # full_matrices=False reduce memory
    uu, dd, vv = np.linalg.svd(data - datamean, full_matrices=False)

    # Get the sptread of data with mean 0 from all axis
    x_min = np.min(data[:,0])
    y_min = np.min(data[:,1])
    z_min = np.min(data[:,2])

    x_max = np.max(data[:,0])
    y_max = np.max(data[:,1])
    z_max = np.max(data[:,2])

    low_bound = min(x_min, y_min, z_min)
    high_bound = max(x_max, y_max, z_max)

    # Now vv[0] contains the first principal component, i.e. the direction
    # vector of the 'best fit' line in the least squares sense.
    # Adjust axist limits (Optional)
    linepts = vv[0] * np.mgrid[low_bound:high_bound:2j][:, np.newaxis]
    # shift by the mean to get the line in the right place
    linepts += datamean

    # Verify that everything looks right.

    # import mpl_toolkits.mplot3d as m3d
    fig = plt.figure()
    ax = fig.add_subplot(111, projection='3d')
    ax.scatter3D(*data.T)
    ax.plot3D(*linepts.T)
    # ax.scatter3D(data[:,0], data[:,1], data[:,2])
    ax.set_xlabel("transferSize")
    ax.set_ylabel("aggregateFilesizeMB")
    ax.set_zlabel("bwMiB")
    ax.set_title(title)
    plt.show()

# Take a column name for y_data
def x_mean_std(group, y_column):
    return pd.Series({
        f'{y_column}_ave': group[y_column].mean(),
        f'{y_column}_ave_std': group[y_column].std(ddof=0)  # Use population standard deviation by setting ddof=0
    })


def my_data_transform(df, cols_to_norm=[], cols_to_log=[]):
    # Create an empty DataFrame to store the results
    results = []

    # Get unique transfer sizes and number of tasks
    xfersizes = sorted(df['transferSize'].unique())
    numTasks = sorted(df['numTasks'].unique())
    op_type = [0, 1]  # Define outside the loop to avoid redefinition
    print("Transfer Sizes: ", xfersizes)
    print("Number of Tasks: ", numTasks)

    for xfer in xfersizes:
        for t in numTasks:
            for op in op_type:
                # Filter the DataFrame for specific conditions
                subdf = df[(df['numTasks'] == t) &
                           (df['transferSize'] == xfer) &
                           (df['operation'] == op)].copy()
                
                if not subdf.empty:
                    # Calculate the mean and standard deviation of the bwMiB column
                    ave_bw_df = subdf.groupby('aggregateFilesizeMB').apply(
                        lambda group: x_mean_std(group, 'bwMiB')
                    ).reset_index()

                    # Calculate percentage of standard deviation
                    ave_bw_df['bwMiB_ave_std_perc'] = (ave_bw_df['bwMiB_ave_std'] /
                                                       ave_bw_df['bwMiB_ave']) * 100

                    # Merge the aggregated results with the original DataFrame
                    merged_df = pd.merge(subdf, ave_bw_df, on='aggregateFilesizeMB', how='left')

                    # Append the merged DataFrame to the results list
                    results.append(merged_df)

    # Concatenate all the DataFrames in the results list
    new_df = pd.concat(results, ignore_index=True)

    # Log transformation
    if cols_to_log:
        log_new_cols = [f"{col}_log" for col in cols_to_log]
        print("Columns to log: ", cols_to_log)
        new_df[log_new_cols] = np.log(new_df[cols_to_log])

    # Min-Max normalization
    if cols_to_norm:
        norm_new_cols = [f"{col}_norm" for col in cols_to_norm]
        print("Columns to normalize: ", cols_to_norm)
        scaler = MinMaxScaler()
        new_df[norm_new_cols] = scaler.fit_transform(new_df[cols_to_norm])

    return new_df

def oscillatory_func(x, amplitude, frequency, phase, offset):
    return amplitude * np.sin(frequency * x + phase) + offset

def damped_sine_func(x, amplitude, frequency, phase, offset, decay):
    return amplitude * np.sin(frequency * x + phase) * np.exp(-decay * x) + offset

def cos_func(x, amplitude, frequency):
    return amplitude * np.cos(frequency * x)

def normalize_y(y_data):
    scaler = MinMaxScaler(feature_range=(-1, 1))
    return scaler.fit_transform(y_data.values.reshape(-1, 1)).flatten()

