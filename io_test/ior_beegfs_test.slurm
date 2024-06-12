#!/bin/sh
#SBATCH --job-name=beegfs_ior_test
#SBATCH --partition=slurm
#SBATCH --time=08:00:00
#SBATCH -N 1
#SBATCH --output=./ior_bgfs_%x_R.out
#SBATCH --error=./ior_bgfs_%x_R.err
#SBATCH -A oddite


TEST_FS="/rcfs/projects/chess/$USER/ior_test"


cd $HOME/scripts/linux_resource_detect/io_test
mkdir -p $TEST_FS

bash seismic_ior_ptest.sh $TEST_FS "sudo /sbin/sysctl vm.drop_caches=3"
