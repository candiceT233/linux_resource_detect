# wf_analysis_fastflow.ipynb
1. Prepare a task order with input output json file, currently 1 is prepared for 1000_genome under `perf_analysis/1kgenome_data/fastflow_tests/1kg_script_order.json`, this is ready to use.

1. Test data folder
Create a evaluation result folder and place under `perf_analysis/1kgenome_data/fastflow_tests`, example test folder name:
```bash
perf_analysis/1kgenome_data/fastflow_tests/par_6000_10n_nfs_ps300
perf_analysis/1kgenome_data/fastflow_tests/par_6000_10n_nfs_ps300
perf_analysis/1kgenome_data/fastflow_tests/par_6000_10n_nfs_ps300
```
2. Trial data folder
Create a trial folder under the test folder, example names:
```bash
perf_analysis/1kgenome_data/fastflow_tests/par_3000_10n_nfs_ps300/300_p_10n_NFS_t1

```

3. Json file location
Place json file under the *trial data folder* and run the script `wf_analysis_fastflow.ipynb`