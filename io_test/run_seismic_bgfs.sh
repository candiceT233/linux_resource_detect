#!/bin/bash

# MSHOCK_DATA_PATH=///qfs/people/tang584/scripts/linux_resource_detect/example_workflow/seismology-workflow/input/MShock
# EGF_INPUT_PATH=///qfs/people/tang584/scripts/linux_resource_detect/example_workflow/seismology-workflow/input/EGF

set -e

IterDecon_BIN=///qfs/people/tang584/scripts/linux_resource_detect/example_workflow/seismology-workflow/bin
EXP_DATA_PATH=/rcfs/scratch/$USER/seismic_data # BeeGFS
MSHOCK_DATA_PATH=$EXP_DATA_PATH/MShock
EGF_INPUT_PATH=$EXP_DATA_PATH/EGF

cd $EXP_DATA_PATH

# record start time in milliseconds
time_1=$(($(date +%s%N)/1000000))
echo "Start sG1IterDcon --------------------------------"

sh $IterDecon_BIN/sG1IterDecon $MSHOCK_DATA_PATH/b916-pb-_ldsp.lht $EGF_INPUT_PATH/b916-pb-_ldsp.lht 
mv _iter_g1.stf b916-pb-_ldsp.lht_iter_g1.stf 
sh $IterDecon_BIN/sG1IterDecon $MSHOCK_DATA_PATH/g43a-ta-_ldsp.lht $EGF_INPUT_PATH/g43a-ta-_ldsp.lht 
mv _iter_g1.stf g43a-ta-_ldsp.lht_iter_g1.stf 
sh $IterDecon_BIN/sG1IterDecon $MSHOCK_DATA_PATH/d27-xt-_ldsp.lht $EGF_INPUT_PATH/d27-xt-_ldsp.lht 
mv _iter_g1.stf d27-xt-_ldsp.lht_iter_g1.stf 
sh $IterDecon_BIN/sG1IterDecon $MSHOCK_DATA_PATH/nc05-xq-_ldsp.lht $EGF_INPUT_PATH/nc05-xq-_ldsp.lht 
mv _iter_g1.stf nc05-xq-_ldsp.lht_iter_g1.stf 
sh $IterDecon_BIN/sG1IterDecon $MSHOCK_DATA_PATH/q43a-ta-_ldsp.lht $EGF_INPUT_PATH/q43a-ta-_ldsp.lht 
mv _iter_g1.stf q43a-ta-_ldsp.lht_iter_g1.stf 
sh $IterDecon_BIN/sG1IterDecon $MSHOCK_DATA_PATH/ss64-xi-_ldsp.lht $EGF_INPUT_PATH/ss64-xi-_ldsp.lht 
mv _iter_g1.stf ss64-xi-_ldsp.lht_iter_g1.stf 
sh $IterDecon_BIN/sG1IterDecon $MSHOCK_DATA_PATH/enh-ic-00_ldsp.lht $EGF_INPUT_PATH/enh-ic-00_ldsp.lht 
mv _iter_g1.stf enh-ic-00_ldsp.lht_iter_g1.stf 
sh $IterDecon_BIN/sG1IterDecon $MSHOCK_DATA_PATH/ss72-xi-_ldsp.lht $EGF_INPUT_PATH/ss72-xi-_ldsp.lht 
mv _iter_g1.stf ss72-xi-_ldsp.lht_iter_g1.stf 
sh $IterDecon_BIN/sG1IterDecon $MSHOCK_DATA_PATH/maja-xv-_ldsp.lht $EGF_INPUT_PATH/maja-xv-_ldsp.lht 
mv _iter_g1.stf maja-xv-_ldsp.lht_iter_g1.stf 
sh $IterDecon_BIN/sG1IterDecon $MSHOCK_DATA_PATH/n02d-ta-_ldsp.lht $EGF_INPUT_PATH/n02d-ta-_ldsp.lht 
mv _iter_g1.stf n02d-ta-_ldsp.lht_iter_g1.stf 
sh $IterDecon_BIN/sG1IterDecon $MSHOCK_DATA_PATH/i55a-ta-_ldsp.lht $EGF_INPUT_PATH/i55a-ta-_ldsp.lht 
mv _iter_g1.stf i55a-ta-_ldsp.lht_iter_g1.stf 
sh $IterDecon_BIN/sG1IterDecon $MSHOCK_DATA_PATH/149a-ta-_ldsp.lht $EGF_INPUT_PATH/149a-ta-_ldsp.lht 
mv _iter_g1.stf 149a-ta-_ldsp.lht_iter_g1.stf 
sh $IterDecon_BIN/sG1IterDecon $MSHOCK_DATA_PATH/bar-ci-_ldsp.lht $EGF_INPUT_PATH/bar-ci-_ldsp.lht 
mv _iter_g1.stf bar-ci-_ldsp.lht_iter_g1.stf 
sh $IterDecon_BIN/sG1IterDecon $MSHOCK_DATA_PATH/dac-lb-_ldsp.lht $EGF_INPUT_PATH/dac-lb-_ldsp.lht 
mv _iter_g1.stf dac-lb-_ldsp.lht_iter_g1.stf 
sh $IterDecon_BIN/sG1IterDecon $MSHOCK_DATA_PATH/d34-xt-_ldsp.lht $EGF_INPUT_PATH/d34-xt-_ldsp.lht 
mv _iter_g1.stf d34-xt-_ldsp.lht_iter_g1.stf 
sh $IterDecon_BIN/sG1IterDecon $MSHOCK_DATA_PATH/pats-ps-_ldsp.lht $EGF_INPUT_PATH/pats-ps-_ldsp.lht 
mv _iter_g1.stf pats-ps-_ldsp.lht_iter_g1.stf 
sh $IterDecon_BIN/sG1IterDecon $MSHOCK_DATA_PATH/tato-iu-10_ldsp.lht $EGF_INPUT_PATH/tato-iu-10_ldsp.lht 
mv _iter_g1.stf tato-iu-10_ldsp.lht_iter_g1.stf 
sh $IterDecon_BIN/sG1IterDecon $MSHOCK_DATA_PATH/gugu-xf-_ldsp.lht $EGF_INPUT_PATH/gugu-xf-_ldsp.lht 
mv _iter_g1.stf gugu-xf-_ldsp.lht_iter_g1.stf 
sh $IterDecon_BIN/sG1IterDecon $MSHOCK_DATA_PATH/b026-pb-_ldsp.lht $EGF_INPUT_PATH/b026-pb-_ldsp.lht 
mv _iter_g1.stf b026-pb-_ldsp.lht_iter_g1.stf 
sh $IterDecon_BIN/sG1IterDecon $MSHOCK_DATA_PATH/frb-cn-_ldsp.lht $EGF_INPUT_PATH/frb-cn-_ldsp.lht 
mv _iter_g1.stf frb-cn-_ldsp.lht_iter_g1.stf

time_2=$(($(date +%s%N)/1000000))

echo "Start siftSTFByMisfit.py --------------------------------"

python $IterDecon_BIN/siftSTFByMisfit.py b916-pb-_ldsp.lht_iter_g1.stf g43a-ta-_ldsp.lht_iter_g1.stf d27-xt-_ldsp.lht_iter_g1.stf nc05-xq-_ldsp.lht_iter_g1.stf q43a-ta-_ldsp.lht_iter_g1.stf ss64-xi-_ldsp.lht_iter_g1.stf enh-ic-00_ldsp.lht_iter_g1.stf ss72-xi-_ldsp.lht_iter_g1.stf maja-xv-_ldsp.lht_iter_g1.stf n02d-ta-_ldsp.lht_iter_g1.stf i55a-ta-_ldsp.lht_iter_g1.stf 149a-ta-_ldsp.lht_iter_g1.stf bar-ci-_ldsp.lht_iter_g1.stf dac-lb-_ldsp.lht_iter_g1.stf d34-xt-_ldsp.lht_iter_g1.stf pats-ps-_ldsp.lht_iter_g1.stf tato-iu-10_ldsp.lht_iter_g1.stf gugu-xf-_ldsp.lht_iter_g1.stf b026-pb-_ldsp.lht_iter_g1.stf frb-cn-_ldsp.lht_iter_g1.stf

time_3=$(($(date +%s%N)/1000000))

# Calculate duration, convert milliseconds to seconds
echo "Duration sG1IterDcon: $((time_2-time_1)) ms [$(echo "scale=2; ($time_2-$time_1)/1000" | bc) sec]"
echo "Duration siftSTFByMisfit.py: $((time_3-time_2)) ms [$(echo "scale=2; ($time_3-$time_2)/1000" | bc) sec

echo "End --------------------------------"

# Check if the output files are generated
set -x
ls -l $EXP_DATA_PATH | grep ".stf" | wc -l
ls -l $EXP_DATA_PATH | grep "good-fit" | wc -l
