#!/bin/bash
#SBATCH --job-name=tbpf_summer_sam_0
#SBATCH --partition=slurm
#SBATCH --time=01:30:00
#SBATCH -N 8
#SBATCH --ntasks=240
#SBATCH --output=./R_%x.out
#SBATCH --error=./R_%x.err
# --cpus-per-task=4
# --mem=8G

###############################################################################################
# This script demonstrates running cell tracking on NEXRAD data (KHGX)
# To run this demo script:
# 1. Modify the dir_demo to a directory on your computer to download the sample data
# 2. Run the script: bash demo_cell_nexrad.sh
# 
# By default the demo config uses 4 processors for parallel processing, 
#    assuming most computers have at least 4 CPU cores. 
#    If your computer has more than 4 processors, you may modify 'nprocesses' 
#    in config_nexrad500m_example.yml to reduce the run time.
###############################################################################################

# export SCRATCH=/scratch/tang584
# export SCRATCH=.
# export PMIX_MCA_gds=hash

# # Specify directory for the demo data
# dir_demo='/qfs/people/tang584/scripts/PyFLEXTRKR/hm_nexrad_demo' 
# # Example config file name
# config_demo='config_nexrad_cell_demo.yml'
# # Demo input data directory
# dir_input='/qfs/people/tang584/scripts/PyFLEXTRKR/input_data/nexrad_reflectivity1' #data downloaded


## Prepare Test Directories
TEST_NAME='olr_pcp'
FS_PREFIX="/qfs/projects/oddite/$USER" # NFS
# FS_PREFIX="/rcfs/projects/chess/$USER" # PFS

# Specify directory for the demo data
dir_demo="${FS_PREFIX}/flextrkr_runs/${TEST_NAME}" # NFS
mkdir -p $dir_demo
rm -rf $dir_demo/*
# Example config file name
config_example='run_mcs_tbpf_saag_summer_sam_template.yml'
config_demo='run_mcs_tbpf_saag_summer_sam.yml'
cp ./$config_demo $dir_demo
# Demo input data directory
dir_input="${FS_PREFIX}/flextrkr_runs/input_data/${TEST_NAME}"


# dir_script="/people/tang584/scripts/PyFLEXTRKR"

## Prepare Slurm Host Names and IPs
NODE_NAMES=`echo $SLURM_JOB_NODELIST|scontrol show hostnames`

hostlist=$(echo "$NODE_NAMES" | tr '\n' ',')
echo "hostlist: $hostlist"
export HOSTLIST=$hostlist


PREPARE_CONFIG () {

    # Add '\' to each '/' in directory names
    dir_raw1=$(echo ${dir_input} | sed 's_/_\\/_g')
    dir_input1=$(echo ${dir_input} | sed 's_/_\\/_g')
    dir_demo1=$(echo ${dir_demo} | sed 's_/_\\/_g')
    # Replace input directory names in example config file
    sed 's/INPUT_DIR/'${dir_input1}'/g;s/TRACK_DIR/'${dir_demo1}'/g;s/RAW_DATA/'${dir_raw1}'/g' ${config_example} > ${config_demo}
    # sed 's/INPUT_DIR/'${dir_input1}'/g;s/TRACK_DIR/'${dir_demo1}'/g' ${config_example} > ${config_demo}
    echo 'Created new config file: '${config_demo}
}

RUN_TRACKING () {
    # Creating a scheduler file
    # rm -rf $SCRATCH/scheduler.json

    set -x 
    # mpirun -np 4 -host $hostlist dask-mpi --scheduler-file $SCRATCH/scheduler.json &

    # Run tracking
    echo 'Running PyFLEXTRKR ...'
    # Calculate number of processors per node
    NPERNODE=$(($SLURM_NTASKS / $SLURM_JOB_NUM_NODES))
    # mpirun --oversubscribe --host $hostlist --npernode $NPERNODE python ../runscripts/run_mcs_tbpf_saag_summer_sam.py ${config_demo} &> ${FUNCNAME[0]}-${TEST_NAME}.log
    
    # if [[ $SLURM_JOB_NUM_NODES -gt 1 ]]; then
    #     # srun ${SLURM_NTASKS} --ntasks-per-node=${SLURM_NTASKS_PER_NODE} -w $hostlist python ../runscripts/run_mcs_tbpf_saag_summer_sam.py ${config_demo} &> ${FUNCNAME[0]}-${TEST_NAME}.log
    # else
    #     python ../runscripts/run_mcs_tbpf_saag_summer_sam.py ${config_demo} &> ${FUNCNAME[0]}-demo.log
    # fi

    srun -n$SLURM_NTASKS -w $hostlist python ../runscripts/run_mcs_tbpf_saag_summer_sam.py ${config_demo} &> ${FUNCNAME[0]}-${TEST_NAME}.log


    echo 'Tracking is done.'

}

MAKE_QUICKLOOK_PLOTS () {
    # Make quicklook plots
    echo 'Making quicklook plots ...'
    quicklook_dir=${dir_demo}'/quicklooks_trackpaths/'
    python ../Analysis/plot_subset_tbze_mcs_tracks_demo.py -s '2015-05-06T00' -e '2015-05-10T00' \
        -c ${config_demo} -o horizontal -p 1 --figsize 8 12 --output ${quicklook_dir}
    echo 'View quicklook plots here: '${quicklook_dir}
}

MAKE_ANIMATION () {
    # Make animation using ffmpeg
    echo 'Making animations from quicklook plots ...'
    ffmpeg -framerate 2 -pattern_type glob -i ${quicklook_dir}'*.png' -c:v libx264 -r 10 -crf 20 -pix_fmt yuv420p \
        -y ${quicklook_dir}quicklook_animation.mp4
    echo 'View animation here: '${quicklook_dir}quicklook_animation.mp4
}

date


# # Activate PyFLEXTRKR conda environment
echo 'Activating PyFLEXTRKR environment ...'
source activate pyflextrkr # pyflextrkr flextrkr

export FLUSH_MEM=TRUE # TRUE for flush, FALSE for no flush
export CURR_TASK=""

PREPARE_CONFIG


# ulimit -v $((10 * 1024 * 1024)) # in KB

srun -n$SLURM_JOB_NUM_NODES -w $hostlist --oversubscribe sudo /sbin/sysctl vm.drop_caches=3

start_time=$(($(date +%s%N)/1000000))
RUN_TRACKING
duration=$(( $(date +%s%N)/1000000 - $start_time))
echo "RUN_TRACKING done... $duration milliseconds elapsed." | tee -a RUN_TRACKING-${TEST_NAME}.log




echo 'MCS_TBPF_SAGG_SUMMER_SAM Demo completed!'
date

sacct -j $SLURM_JOB_ID --format="JobID,JobName,Partition,CPUTime,AllocCPUS,State,ExitCode,MaxRSS,MaxVMSize"
