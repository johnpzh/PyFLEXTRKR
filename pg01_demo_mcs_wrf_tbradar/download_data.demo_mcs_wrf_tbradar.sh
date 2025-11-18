#!/bin/bash
###############################################################################################
# This script demonstrates running MCS tracking on WRF Tb + radar data
# To run this demo script:
# 1. Modify the dir_demo to a directory on your computer to download the sample data
# 2. Run the script: bash demo_mcs_wrf_tbradar.sh
#
# By default the demo config uses 8 processors for parallel processing,
#    assuming most computers have at least 8 CPU cores.
#    You may adjust 'nprocesses' in the config_wrf_mcs_tbradar_example.yml.
#    Running with more processors will run the demo faster since the demo WRF data is
#    a real simulation with a decent size domain 1000 x 1000 (lat x lon) and 96 time frames.
###############################################################################################

set -eu

# Specify directory for the demo data
PREV_PWD=$(readlink -f .)
#dir_demo='/Users/feng045/data/demo/mcs_tbpfradar3d/wrf/'
dir_demo="${PREV_PWD}/data/demo/mcs_tbpfradar3d/wrf/"

# Demo input data directory
dir_input=${dir_demo}'input/'

# Create the demo directory
if [ ! -d "${dir_input}" ]; then
    mkdir -p ${dir_input}
fi

# Download sample WRF Tb+Precipitation data:
echo 'Downloading demo input data ...'
wget https://portal.nersc.gov/project/m1867/PyFLEXTRKR/sample_data/tb_radar/wrf_tbradar.tar.gz \
  -O ${dir_input}/wrf_tbradar.tar.gz

# Extract intput data
echo 'Extracting demo input data ...'
tar -xvzf ${dir_input}wrf_tbradar.tar.gz -C ${dir_input}
# Remove downloaded tar file
rm -fv ${dir_input}wrf_tbradar.tar.gz

echo 'Download completed!'
