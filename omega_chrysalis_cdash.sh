#!/bin/bash
#SBATCH  --job-name=OmegaCron
#SBATCH  --nodes=1
#SBATCH  --output=/home/ac.kimy/prjdir/omega/cdash_logs/OmegaCron_%j.out
#SBATCH  --error=/home/ac.kimy/prjdir/omega/cdash_logs/OmegaCron_%j.err
#SBATCH  --qos=high
#SBATCH  --time 00:30:00

MACHINE=chrysalis

#source /usr/share/lmod/8.3.1/init/sh
source /etc/bashrc

module load python
module load cmake

OMEGA_HOME="/lcrc/group/e3sm/soft/omega/cdash/Omega"
OUTROOT="/lcrc/group/e3sm/ac.kimy/omega/cdash"

cd ${OMEGA_HOME}
git checkout develop
git fetch origin
git reset --hard origin/develop
git submodule update --init --recursive

for COMPILER in "gnu" "intel"; do

DATE=$(date +"%d")
WORKDIR=${OUTROOT}/${COMPILER}/${DATE}
rm -rf ${WORKDIR}
mkdir -p ${WORKDIR}

PARMETIS_HOME=/lcrc/soft/climate/polaris/chrysalis/spack/dev_polaris_0_6_0_${COMPILER}_openmpi/var/spack/environments/dev_polaris_0_6_0_${COMPILER}_openmpi/.spack-env/view

cmake \
  -DOMEGA_CIME_MACHINE=${MACHINE} \
  -DOMEGA_CIME_COMPILER=${COMPILER} \
  -DOMEGA_ARCH=SERIAL \
  -DOMEGA_BUILD_TEST=ON \
  -DOMEGA_PARMETIS_ROOT=${PARMETIS_HOME} \
  -S ${OMEGA_HOME}/components/omega \
  -B ${WORKDIR}

mkdir -p ${WORKDIR}/test

ln -sf /gpfs/fs1/home/ac.kimy/opt/ocean_test_mesh.nc ${WORKDIR}/test/OmegaMesh.nc
ln -sf /gpfs/fs1/home/ac.kimy/opt/global_test_mesh.nc ${WORKDIR}/test/OmegaSphereMesh.nc
ln -sf /gpfs/fs1/home/ac.kimy/opt/planar_test_mesh.nc ${WORKDIR}/test/OmegaPlanarMesh.nc

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

#  -DCTEST_SUBMIT_URL="https://my.cdash.org/submit.php?project=omega"

done
