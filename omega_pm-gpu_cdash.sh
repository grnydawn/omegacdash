#!/bin/bash -e
#SBATCH  --job-name=OmegaSCronCDash
#SBATCH  --nodes=1
#SBATCH  --ntasks-per-node=8
#SBATCH  --gpus-per-node=4
#SBATCH  --output=/global/cfs/cdirs/e3sm/omega/cdash/logs/OmegaCDashGPU_%j.out
#SBATCH  --error=/global/cfs/cdirs/e3sm/omega/cdash/logs/OmegaCDashGPU_%j.err
#SBATCH  --constraint=gpu
#SBATCH  --account=e3sm_g 
#SBATCH  --qos regular
#SBATCH  --exclusive
#SBATCH  --time 02:00:00
  
#source /etc/profile
  
#source /opt/cray/pe/cpe/24.07/restore_lmod_system_defaults.sh

module reset
module load cray-python
module load cmake
  
OMEGA_HOME="/global/cfs/cdirs/e3sm/youngsun/Omega/cdash/Omega"
#OMEGA_HOME="/pscratch/sd/y/youngsun/omega/cdash/Omega"
OUTROOT="/pscratch/sd/y/youngsun/omega/cdash"

cd ${OMEGA_HOME}
git checkout develop
git fetch origin
git reset --hard origin/develop
git submodule update --init --recursive

for COMPILER in "gnugpu"; do

DATE=$(date +"%d")
WORKDIR=${OUTROOT}/${COMPILER}/${DATE}
rm -rf ${WORKDIR}
mkdir -p ${WORKDIR}

MACHINE=pm-gpu
ARCH=CUDA
PARMETIS_ROOT=/global/cfs/cdirs/e3sm/software/polaris/pm-gpu/spack/dev_polaris_0_6_0_${COMPILER}_mpich/var/spack/environments/dev_polaris_0_6_0_${COMPILER}_mpich/.spack-env/view

cmake \
  -DOMEGA_CIME_MACHINE=${MACHINE} \
  -DOMEGA_CIME_COMPILER=${COMPILER} \
  -DOMEGA_ARCH=${ARCH} \
  -DOMEGA_BUILD_TEST=ON \
  -DOMEGA_PARMETIS_ROOT=${PARMETIS_ROOT} \
  -S ${OMEGA_HOME}/components/omega \
  -B ${WORKDIR}

mkdir -p ${WORKDIR}/test

ln -sf /global/common/software/e3sm/omega/cdash/data/ocean_test_mesh.nc ${WORKDIR}/test/OmegaMesh.nc
ln -sf /global/common/software/e3sm/omega/cdash/data/global_test_mesh.nc ${WORKDIR}/test/OmegaSphereMesh.nc
ln -sf /global/common/software/e3sm/omega/cdash/data/planar_test_mesh.nc ${WORKDIR}/test/OmegaPlanarMesh.nc
    
source ${WORKDIR}/omega_env.sh

ctest \
  -S ${OMEGA_HOME}/components/omega/CTestScript.cmake \
  -DCTEST_SOURCE_DIRECTORY=${OMEGA_HOME}/components/omega \
  -DCTEST_BINARY_DIRECTORY=${WORKDIR} \
  -DCTEST_SITE=${MACHINE} \
  -DCTEST_BUILD_GROUP="Omega Unit-test" \
  -DCTEST_BUILD_NAME="unitest-develop-${COMPILER}" \
  -DCTEST_NIGHTLY_START_TIME="06:00:00 UTC" \
  -DCTEST_BUILD_COMMAND="${WORKDIR}/omega_build.sh" \
  -DCTEST_BUILD_CONFIGURATION="Release" \
  -DCTEST_DROP_SITE_CDASH=TRUE \
  -DCTEST_SUBMIT_URL="https://my.cdash.org/submit.php?project=e3sm"

#  -DCTEST_SUBMIT_URL="https://my.cdash.org/submit.php?project=e3sm"

done
