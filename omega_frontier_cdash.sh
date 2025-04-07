#!/bin/bash
#SBATCH  --job-name=OmegaCron
#SBATCH  --nodes=1
#SBATCH  --output=/lustre/orion/cli115/scratch/grnydawn/omega/cdash/logs/OmegaCron_%j.out
#SBATCH  --error=/lustre/orion/cli115/scratch/grnydawn/omega/cdash/logs/OmegaCron_%j.err
#SBATCH  --account=cli115 
#SBATCH  -p batch
#SBATCH  --time 02:00:00

MACHINE=frontier

source /etc/bash.bashrc
#source /opt/cray/pe/lmod/lmod/init/sh

# allow Frontier computing nodes to send the cdash output to external servers
export all_proxy=socks://proxy.ccs.ornl.gov:3128/
export ftp_proxy=ftp://proxy.ccs.ornl.gov:3128/
export http_proxy=http://proxy.ccs.ornl.gov:3128/
export https_proxy=http://proxy.ccs.ornl.gov:3128/
export no_proxy='localhost,127.0.0.0/8,*.ccs.ornl.gov'

OMEGA_HOME="/ccs/proj/cli115/software/omega/cdash/Omega"
POLARIS_SPACK="/ccs/proj/cli115/software/polaris/frontier/spack"
OUTROOT="/lustre/orion/cli115/scratch/grnydawn/omega/cdash"

cd ${OMEGA_HOME}
git checkout develop
git fetch origin
git reset --hard origin/develop
git submodule update --init --recursive

cd ${OUTROOT}

#for COMPILER in "craycray-mphipcc" "crayamd-mphipcc" "craygnu-mphipcc" "craycray" "crayamd" "craygnu"; do
for COMPILER in "crayamd-mphipcc" "craygnu-mphipcc" "craycray" "crayamd" "craygnu" "craycray-mphipcc"; do

DATE=$(date +"%d")
WORKDIR=${OUTROOT}/${COMPILER}/${DATE}
rm -rf ${WORKDIR}
mkdir -p ${WORKDIR}

if [[ $COMPILER == *-mphipcc ]]; then
    ARCH=HIP
else
    ARCH=SERIAL
fi

if [[ $COMPILER == craygnu* ]]; then

#source /opt/cray/pe/lmod/lmod/init/sh
#module load python/3.11.7 #failed with "Lmod unknown error"
module reset
module load Core/25.03
module load PrgEnv-gnu
module load cray-python/3.11.7
module load cmake

#module reset
#module load PrgEnv-gnu
#module load cpe/24.11
#module load cray-python/3.11.7
#module load cmake/3.27.9

else

#source /opt/cray/pe/lmod/lmod/init/sh
#module load python/3.11.7 #failed with "Lmod unknown error"

module reset
module load Core/24.00
module load cray-python/3.11.7
#module load cray-python
module load cmake

#module load cray-python/3.9.13.1
#module load cmake/3.21.3

fi

PARMETIS_HOME="${POLARIS_SPACK}/dev_polaris_0_6_0_${COMPILER}_mpich/var/spack/environments/dev_polaris_0_6_0_${COMPILER}_mpich/.spack-env/view"

cmake \
  -DOMEGA_CIME_MACHINE=${MACHINE} \
  -DOMEGA_CIME_COMPILER=${COMPILER} \
  -DOMEGA_ARCH=${ARCH} \
  -DOMEGA_BUILD_TEST=ON \
  -DOMEGA_PARMETIS_ROOT=${PARMETIS_HOME} \
  -S ${OMEGA_HOME}/components/omega \
  -B ${WORKDIR}

mkdir -p ${WORKDIR}/test

ln -sf /ccs/proj/cli115/software/omega/cdash/data/ocean_test_mesh.nc ${WORKDIR}/test/OmegaMesh.nc
ln -sf /ccs/proj/cli115/software/omega/cdash/data/global_test_mesh.nc ${WORKDIR}/test/OmegaSphereMesh.nc
ln -sf /ccs/proj/cli115/software/omega/cdash/data/planar_test_mesh.nc ${WORKDIR}/test/OmegaPlanarMesh.nc

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
