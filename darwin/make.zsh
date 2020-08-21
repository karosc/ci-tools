#!/usr/bin/env zsh
#
#
#  make.sh - Builds swmm/epanet executable
#
#  Date Created: 06/29/2020
#       Updated: 08/21/2020
#
#  Authors:      Michael E. Tryby
#                US EPA - ORD/NRMRL
#                
#                Caleb A. Buahin
#                Xylem Inc.
#
#  Environment Variables:
#    PROJECT
#  
#  Optional Arguments:
#    -g ("GENERATOR") defaults to "Ninja"
#    -t builds and runs unit tests (requires Boost)


# Check to make sure PROJECT is defined
[[ ! -v PROJECT ]] && { echo "ERROR: PROJECT must be defined"; return 1 }

export BUILD_HOME="build"

# determine project directory
SCRIPT_HOME=${0:a:h}
cd ${SCRIPT_HOME} 
cd ./../../
PROJECT_DIR=${PWD}


echo INFO: Building ${PROJECT}  ...

GENERATOR="Xcode"
TESTING=0


POSITIONAL=()

while [[ $# -gt 0 ]]
do
key="$1"
case $key in
    -g|--gen)
    GENERATOR="$2"
    shift # past argument
    shift # past value
    ;;
    -t|--test)
    TESTING=1
    shift # past argument
    ;;
    *)    # unknown option
    shift # past argument
    ;;
esac
done

set -- "${POSITIONAL[@]}" # restore positional parameters

# perform the build
cmake -E make_directory ${BUILD_HOME}

if [ ${TESTING} -eq 1 ]; 
then
    echo "Building debug"
    cmake -E chdir ./${BUILD_HOME} cmake -G "${GENERATOR}" -DBUILD_TESTS=ON .. \
    && cmake --build ./${BUILD_HOME}  --config Debug \
    && cmake -E chdir ./${BUILD_HOME}  ctest -C Debug --output-on-failure
else
    echo "Building release"
    cmake -E chdir ./${BUILD_HOME} cmake -G ${GENERATOR} -DBUILD_TESTS=OFF .. \
    && cmake --build ./${BUILD_HOME} --config Release --target package \
    && cp ./${BUILD_HOME}/*.zip ./upload >&1
fi

export PLATFORM="Darwin"

#GitHub Actions
echo ::set-env name=PLATFORM::$PLATFORM

# return user to current dir
cd ${PROJECT_DIR}
