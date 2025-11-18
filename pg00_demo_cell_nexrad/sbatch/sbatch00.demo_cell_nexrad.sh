#!/bin/bash
#SBATCH --job-name="cell_nexrad"
#SBATCH --partition=slurm
######SBATCH --partition=short
######SBATCH --exclude=dc[119,077]
#SBATCH --account=oddite
#SBATCH -N 1
######SBATCH --time=01:01:01
#SBATCH --time=44:44:44
#SBATCH --output=output.%x.%j.out.log
#SBATCH --error=output.%x.%j.err.log
#SBATCH --mail-type=FAIL
#SBATCH --mail-user=zhen.peng@pnnl.gov
#SBATCH --exclusive

#### sinfo -p <partition>
#### sinfo -N -r -l
#### srun -A CENATE -N 1 -t 20:20:20 --pty -u /bin/bash

#First make sure the module commands are available.
source /etc/profile.d/modules.sh

#Set up your environment you wish to run in with module commands.
echo
echo "loaded modules"
echo
module purge
module load java/24.0.2 python/miniconda25.5.1
module list &> _modules.lis_
cat _modules.lis_
/bin/rm -f _modules.lis_

#Python version
source /share/apps/python/miniconda25.5.1/etc/profile.d/conda.sh
eval "$(conda shell.bash hook)"
conda activate pp
echo
echo "python version"
echo
command -v python
python --version
export PYTHON_PATH=$(command -v python)


#Next unlimit system resources, and set any other environment variables you need.
ulimit -s unlimited
echo
echo limits
echo
ulimit -a

#Is extremely useful to record the modules you have loaded, your limit settings,
#your current environment variables and the dynamically load libraries that your executable
#is linked against in your job output file.
# echo
# echo "loaded modules"
# echo
# module list &> _modules.lis_
# cat _modules.lis_
# /bin/rm -f _modules.lis_
# echo
# echo limits
# echo
# ulimit -a
echo
echo "Environment Variables"
echo
printenv
# echo
# echo "ldd output"
# echo
# ldd your_executable

#Now you can put in your parallel launch command.
#For each different parallel executable you launch we recommend
#adding a corresponding ldd command to verify that the environment
#that is loaded corresponds to the environment the executable was built in.


set -eu

TT_TIME_START=$(date +%s.%N)

set -x
bash demo_cell_nexrad.sh
set +x

######################
# Show all job states
######################
echo
echo "Job State Summary:"
hostname;date;
sacct -j $SLURM_JOB_ID -o jobid,submit,start,end,state

TT_TIME_END=$(date +%s.%N)
TT_TIME_EXE=$(echo "${TT_TIME_END} - ${TT_TIME_START}" | bc -l)
echo
echo "TT_TIME_EXE(s): ${TT_TIME_EXE}"
echo
