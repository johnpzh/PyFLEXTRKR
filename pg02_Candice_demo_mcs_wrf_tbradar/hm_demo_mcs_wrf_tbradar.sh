#!/bin/bash
#SBATCH --job-name=hm_demo_wrf_tbradar_0
#SBATCH --partition=short
#SBATCH --time=01:30:00
#SBATCH -N 2
#SBATCH --ntasks=80
#SBATCH --ntasks-per-node=40
#SBATCH --output=./R_%x.out
#SBATCH --error=./R_%x.err

## --exclude=dc[009-099,119] --exclude=a100-[05] --exclude=dl[05-10]

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

## Prepare Slurm Host Names and IPs
NODE_NAMES=`echo $SLURM_JOB_NODELIST|scontrol show hostnames`

hostlist=$(echo "$NODE_NAMES" | tr '\n' ',')
echo "hostlist: $hostlist"

rm -rf ./host_ip
touch ./host_ip
host_arr=()
for node in $NODE_NAMES
do
    # "$node.ibnet:1"
    # grep "$node.local" /etc/hosts | awk '{print $1}' >> ./host_ip
    host_arr+=("$node")
    nost_ip=`getent hosts "$node.ibnet" | awk '{ print $1 }'`
    # echo "$node ibnet_ip = $nost_ip"
    echo "$nost_ip" >> ./host_ip
done

cat ./host_ip
ib_hostlist=$(cat ./host_ip | xargs | sed -e 's/ /,/g')
echo "ib_hostlist: $ib_hostlist"


## Prepare Test Directories
TEST_NAME='wrf_tbradar_hm'
# FS_PREFIX="/qfs/projects/oddite/$USER" # NFS
FS_PREFIX="/rcfs/projects/chess/$USER" # PFS

# Specify directory for the demo data
dir_demo="${FS_PREFIX}/flextrkr_runs/${TEST_NAME}" # NFS
mkdir -p $dir_demo
rm -rf $dir_demo/*
# Example config file name
# config_example='config_wrf_mcs_tbradar_example.yml'
config_example='config_wrf_mcs_tbradar_short.yml'
# config_example='config_wrf_mcs_tbradar_seq.yml'
config_demo='config_wrf_mcs_tbradar_demo.yml'
cp ./$config_demo $dir_demo
# Demo input data directory
dir_input="${FS_PREFIX}/flextrkr_runs/input_data/${TEST_NAME}"

echo "dir_demo = $dir_demo"
echo "dir_input = $dir_input"

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

    # Run tracking
    set -x
    if [[ $SLURM_JOB_NUM_NODES -gt 1 ]]; then
        echo "Running PyFLEXTRKR w/ Hermes VFD on multiple nodes ..."
        export HDF5_DRIVER=hdf5_hermes_vfd
        export HDF5_PLUGIN_PATH=${HERMES_INSTALL_DIR}/lib:$HDF5_PLUGIN_PATH
        export HERMES_CONF=$HERMES_CONF
        export HERMES_CLIENT_CONF=$HERMES_CLIENT_CONF
        srun -n$SLURM_NTASKS -w $hostlist --oversubscribe python ../runscripts/run_mcs_tbpfradar3d_wrf.py ${config_demo} &> ${FUNCNAME[0]}-hm.log

        # HDF5_DRIVER=hdf5_hermes_vfd \
        #     HDF5_PLUGIN_PATH=${HERMES_INSTALL_DIR}/lib:$HDF5_PLUGIN_PATH \
        #     HERMES_CONF=$HERMES_CONF \
        #     HERMES_CLIENT_CONF=$HERMES_CLIENT_CONF \
        # srun -n$SLURM_NTASKS -w $hostlist --oversubscribe python ../runscripts/run_mcs_tbpfradar3d_wrf.py ${config_demo} &> ${FUNCNAME[0]}-hm.log

    else
        echo "Running PyFLEXTRKR w/ Hermes VFD on single node ..."
        HDF5_DRIVER=hdf5_hermes_vfd \
            HDF5_PLUGIN_PATH=${HERMES_INSTALL_DIR}/lib:$HDF5_PLUGIN_PATH \
            HERMES_CONF=$HERMES_CONF \
            HERMES_CLIENT_CONF=$HERMES_CLIENT_CONF \
            python ../runscripts/run_mcs_tbpfradar3d_wrf.py ${config_demo} &> ${FUNCNAME[0]}-hm.log
    fi

    # LD_LIBRARY_PATH=$TRACKER_VOL_DIR:$LD_LIBRARY_PATH \
    #     HDF5_VOL_CONNECTOR="${VOL_NAME} under_vol=0;under_info={};path=${SCRIPT_DIR}/vol-${task_id}_${FUNCNAME[0]}.log;level=2;format=" \
    #     HDF5_PLUGIN_PATH=$TRACKER_VOL_DIR \
    #         srun -n1 -N1 --oversubscribe --mpi=pmi2 \
    
    set +x 

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


HERMES_DIS_CONFIG () {

    hostfile_path="$(pwd)/host_ip"
    sed "s#\$HOSTFILE_PATH#${hostfile_path}#" $HERMES_DEFAULT_CONF  > $HERMES_CONF

    protocol="ucx+rc_verbs"
    # protocol="tcp"
    sed -i "s/\$PROTOCOL/${protocol}/" $HERMES_CONF

    if [ $protocol == "tcp" ]; then
        network_device=""
    else
        network_device=`ucx_info -d | grep Device | cut -d' ' -f11 | grep mlx5 | head -1`
    fi
    sed -i "s/\$NETWORK_DEVICE/${network_device}/" $HERMES_CONF

    echo "hostfile_path=${hostfile_path}"

    # INTERCEPT_PATHS=$(sed "s/\$TEST_OUT_PATH/${TEST_OUT_PATH}/g" i${ITER_COUNT}_sim_files.txt)
    # echo "$INTERCEPT_PATHS" >> $HERMES_CONF

    # echo "]" >> $HERMES_CONF

}

STOP_DAEMON () {

    set -x
    HERMES_CONF=$HERMES_CONF srun -n$SLURM_JOB_NUM_NODES -w $hostlist --oversubscribe \
        ${HERMES_INSTALL_DIR}/bin/finalize_hermes &

    set +x
}


START_HERMES_DAEMON () {
    # --mca shmem_mmap_priority 80 \ \
    # -mca mca_verbose stdout 
    # -x UCX_NET_DEVICES=mlx5_0:1 \
    # -mca btl self -mca pml ucx \
    # srun -n$SLURM_JOB_NUM_NODES -w $hostlist rm -rf $DEV1_DIR
    # srun -n$SLURM_JOB_NUM_NODES -w $hostlist mkdir -p $DEV1_DIR

    rm -rf $DEV2_DIR $DEV1_DIR
    mkdir -p $DEV2_DIR $DEV1_DIR

    set -x

    if [[ $SLURM_JOB_NUM_NODES -gt 1 ]]; then
        echo "Starting hermes_daemon on multiple nodes ..."

        HERMES_CONF=$HERMES_CONF srun -n$SLURM_JOB_NUM_NODES -w $hostlist --oversubscribe \
            ${HERMES_INSTALL_DIR}/bin/hermes_daemon & #> ${FUNCNAME[0]}.log &

        # mpirun --host $ib_hostlist --npernode 1 \
        #     -x HERMES_CONF=$HERMES_CONF $HERMES_INSTALL_DIR/bin/hermes_daemon & #> ${FUNCNAME[0]}.log &

        sleep 5
        # echo "Show hermes slabs : "
        # srun -n$SLURM_JOB_NUM_NODES -w $hostlist ls -l $DEV1_DIR/*; ls -l $DEV2_DIR/*

    else
        echo "Starting hermes_daemon on single node ..."
        HERMES_CONF=$HERMES_CONF ${HERMES_INSTALL_DIR}/bin/hermes_daemon &> ${FUNCNAME[0]}.log &
        sleep 5
        # echo "Show hermes slabs : "
        # ls -l $DEV1_DIR/*
        # ls -l $DEV2_DIR/*
    fi

    set +x
}

MON_MEM () {
    srun -n$SLURM_JOB_NUM_NODES -w $hostlist killall free

    log_name=wrf_tbpf_mem_usage
    log_file="${log_name}-demo.log"
    echo "Logging mem usage to $log_file"

    index=0  # Initialize the index variable

    free -h | awk -v idx="$index" 'BEGIN{OFS="\t"} NR==1{print "Index\t","Type\t" $0} NR==2{print idx, $0}' > "$log_file"

    free -h -s 1 | grep --line-buffered Mem | sed --unbuffered = | paste - - >> "$log_file"

}

date

# MON_MEM &

# spack load ior
# timeout 45 mpirun -n 10 ior -w -r -t 1m -b 30g -o $dir_demo/ior_test_file


source ./load_hermes_deps.sh
source ./env_var.sh

# # Activate PyFLEXTRKR conda environment
echo 'Activating PyFLEXTRKR environment ...'
source activate pyflextrkr_copy # flextrkr pyflextrkr

# export PYTHONLOGLEVEL=ERROR
# export PYTHONLOGLEVEL=INFO

srun -n1 -N1 killall hermes_daemon

export FLUSH_MEM=FALSE # TRUE for flush, FALSE for no flush
export CURR_TASK=""

PREPARE_CONFIG

set -x

HERMES_DIS_CONFIG

START_HERMES_DAEMON

# ulimit -v $((200 * 1024 * 1024)) # in KB
srun -n$SLURM_JOB_NUM_NODES -w $hostlist --oversubscribe sudo /sbin/sysctl vm.drop_caches=3

start_time=$(($(date +%s%N)/1000000))
RUN_TRACKING
duration=$(( $(date +%s%N)/1000000 - $start_time))
echo "RUN_TRACKING done... $duration milliseconds elapsed." | tee -a RUN_TRACKING-hm.log


echo 'MCS_WRF_TBRADAR Demo completed!'
date


# sacct -j $SLURM_JOB_ID -o jobid,submit,start,end,state
sacct -j $SLURM_JOB_ID --format="JobID,JobName,Partition,CPUTime,AllocCPUS,State,ExitCode,MaxRSS,MaxVMSize"
rm -rf $dir_demo/core.*

echo ""
ls -l $dir_demo/*/*