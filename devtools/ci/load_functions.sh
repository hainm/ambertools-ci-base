#!/bin/sh

url="http://ambermd.org/downloads/ambertools-dev/AmberTools18-dev.tar.gz"
tarfile=`python -c "url='$url'; print(url.split('/')[-1])"`
version='16'
EXCLUDED_TESTS=test.parmed
AMBERTOOLS_VERSION=18.0

function download_ambertools(){
    wget $url -O $tarfile
    tar -xf $tarfile
}

function install_ambertools_travis(){
    set -ex
    # This AmberTools version is not an official release. It is meant for testing.
    # DO NOT USE IT PLEASE.
    osname=`python -c 'import sys; print(sys.platform)'`
    cd amber$version
    if [ $osname = "darwin" ]; then
        unset CC CXX
        compiler="-macAccelerate clang"
    else
        compiler="gnu"
    fi
    if [ "$MINICONDA_WILL_BE_INSTALLED" = "True" ]; then
        yes | ./configure $compiler
    elif [ "$MINICONDA_IN_AMBERHOME" = "True" ]; then
        bash AmberTools/src/configure_python --prefix `pwd`
        ./configure $compiler
    elif [ "$USE_AMBER_PREFIX" = "True" ]; then
        mkdir $HOME/TMP/
        yes | ./configure --prefix $HOME/TMP $compiler
    elif [ "$USE_WITH_PYTHON" = "True" ]; then
        bash AmberTools/src/configure_python --prefix $HOME
        export PATH=$HOME/miniconda/bin:$PATH
        ./configure --with-python $HOME/miniconda/bin/python $compiler
    elif [ "$SKIP_PYTHON" = "True" ]; then
        ./configure --skip-python $compiler
    elif [ "$AMBER_INSTALL_MPI" = "True" ]; then
        yes | ./configure $compiler
        make install -j2
        ./configure -mpi $compiler # will do make install later
    elif [ "$PYTHON_VERSION" = "3.6" ]; then
        bash AmberTools/src/configure_python --prefix $HOME -v 3
        export PATH=$HOME/miniconda/bin:$PATH
        ./configure --with-python $HOME/miniconda/bin/python $compiler
    fi
    
    make install -j2
}


function install_ambertools_travis_cmake(){
    set -ex
    bash amber$version/AmberTools/src/configure_python --prefix $HOME
    export PATH=$HOME/miniconda/bin:$PATH
    mkdir build install
    cd build
    cmake -DCOMPILER=gnu -DCMAKE_INSTALL_PREFIX=`pwd`/../install ../amber$version
    make install
    cd ../install && source amber.sh
}


function install_ambertools_circleci(){
    mkdir $HOME/TMP
    cd $HOME/TMP
    python $HOME/ambertools-binary-build/build_all.py \
        --exclude-osx --sudo --date \
        --amberhome $HOME/ambertools-ci/amber$version \
        -v $AMBERTOOLS_VERSION
}


function run_long_test_simplified(){
    # not running all tests, skip any long long test.
    cd $AMBERHOME/AmberTools/test
    python $HOME/amber.run_tests -t $TEST_TASK -x $HOME/EXCLUDED_TESTS
    # python $TRAVIS_BUILD_DIR/amber$version/AmberTools/src/conda_tools/amber.run_tests $TEST_TASK
}


function run_tests(){
    set -ex
    if [ "$USE_AMBER_PREFIX" = "True" ]; then
        source $HOME/TMP/amber.sh
        ls $AMBERHOME
        ls $HOME/TMP/
        ls $HOME/TMP/*/
    else
        source $TRAVIS_BUILD_DIR/amber$version/amber.sh
    fi
    if [ "$TEST_TASK" != "" ]; then
        run_long_test_simplified
    else
        if [ "$SKIP_PYTHON" != "True" ]; then
            cat $TRAVIS_BUILD_DIR/amber$version/AmberTools/src/conda-recipe/run_test.sh | sed "s/python/amber.python/g" > $HOME/run_test.sh
            bash $HOME/run_test.sh
        else
            (cd $AMBERHOME/AmberTools/test && make test.ambermini)
        fi
    fi
}
