#!/bin/sh

tarfile="AmberTools18-dev.tar.gz"
url="http://ambermd.org/downloads/ambertools-dev/$tarfile"
version='16'
AMBERTOOLS_VERSION=18.0
CONDA_BUILD_AMBERTOOLS_VERSION=18.dev


function download_ambertools_from_circleci(){
    export CIRCLE_TOKEN='?circle-token=${ambertools_test_prep_download_token}'
    curl https://circleci.com/api/v1.1/project/github/hainm/ambertools-ci-prep/latest/artifacts$CIRCLE_TOKEN |
      grep -o 'https://[^"]*' > artifacts.txt
    <artifacts.txt xargs -P4 -I % wget %$CIRCLE_TOKEN -O $HOME/$tarfile
    (cd $HOME && tar -xf $tarfile)
}


function download_ambertools(){
    wget $url -O $tarfile
    mv $tarfile $HOME/
    (cd $HOME && tar -xf $tarfile)
}


function install_conda_package_osx(){
    bash $HOME/amber${version}/AmberTools/src/configure_python --prefix $HOME
    export PATH=$HOME/miniconda/bin:$PATH
    conda install conda-build=2.1.17 -y
    mkdir $HOME/TMP
    cd $HOME/TMP
    python $HOME/ambertools-binary-build/build_all.py \
        --amberhome $HOME/amber${version} \
        --py 2.7 \
        -v $CONDA_BUILD_AMBERTOOLS_VERSION \
        --exclude-linux
}


function install_ambertools_travis(){
    # This AmberTools version is not an official release. It is meant for testing.
    # DO NOT USE IT PLEASE.
    osname=`python -c 'import sys; print(sys.platform)'`
    cd $HOME/amber$version
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


function install_ambertools_cmake(){
    bash $HOME/amber$version/AmberTools/src/configure_python --prefix $HOME
    export PATH=/usr/local/gfortran/bin:$HOME/miniconda/bin:$PATH
    
    if [ "$TRAVIS_OS_NAME" = "linux" ]; then
        mkdir $HOME/cmake_install
        curl https://cmake.org/files/v3.9/cmake-3.9.4-Linux-x86_64.sh -O
        bash cmake-3.9.4-Linux-x86_64.sh --prefix=$HOME/cmake_install --skip-license
        export PATH=$HOME/cmake_install/bin:$PATH
    else
        conda install cmake -c conda-forge -y
    fi
    mkdir -p $HOME/TMP/build
    mkdir -p $HOME/TMP/install
    cd $HOME/TMP/build
    cmake -DCOMPILER=GNU \
        -DFORCE_INTERNAL_LIBS=readline \
        -DCMAKE_INSTALL_PREFIX=$HOME/TMP/install \
        -DBUILD_GUI=FALSE \
        -DUSE_MINICONDA=FALSE \
        $HOME/amber$version
    make install
    cd $HOME/TMP/install && source amber.sh
    echo "AMBERHOME = " $AMBERHOME
    echo "ls $AMBERHOME"
    ls $AMBERHOME
    echo "ls $HOME/TMP/install"
    ls $HOME/TMP/install
    rm -rf $HOME/TMP/build
}


function install_ambertools_circleci(){
    mkdir $HOME/TMP
    cd $HOME/TMP
    # dry run
    python $HOME/ambertools-binary-build/build_all.py \
        --exclude-osx --sudo --date \
        --amberhome $HOME/amber$version \
        -v $AMBERTOOLS_VERSION -d

    python $HOME/ambertools-binary-build/build_all.py \
        --exclude-osx --sudo --date \
        --amberhome $HOME/amber$version \
        -v $AMBERTOOLS_VERSION
}


function run_long_test_simplified(){
    # not running all tests, skip any long long test.
    cd $AMBERHOME/AmberTools/test
    python -m pip install numpy --user # in case Miniconda is not installed
    python $HOME/amber.run_tests -t $TEST_TASK -x $HOME/EXCLUDED_TESTS -n 1
}


function post_process_osx_build(){
    # Change absolute path to loader_path
    python $HOME/ambertools-binary-build/conda_tools/update_shebang.py \
        $HOME/amber${version}
    python $HOME/ambertools-binary-build/conda_tools/fix_rpath_osx.py \
        $HOME/amber${version}
    python $HOME/ambertools-binary-build/conda_tools/update_gfortran_libs_osx.py \
        --copy-gfortran \
        $HOME/amber${version}
}


function run_tests(){
    if [ "$USE_AMBER_PREFIX" = "True" ]; then
        source $HOME/TMP/amber.sh
        ls $AMBERHOME
        ls $HOME/TMP/
        ls $HOME/TMP/*/
    else
        source $HOME/amber$version/amber.sh
    fi
    if [ "$TEST_TASK" != "" ]; then
        run_long_test_simplified
    else
        if [ "$SKIP_PYTHON" != "True" ]; then
            cat $HOME/amber$version/AmberTools/src/conda-recipe/run_test.sh | sed "s/python/amber.python/g" > $HOME/run_test.sh
            bash $HOME/run_test.sh
        else
            (cd $AMBERHOME/AmberTools/test && make test.ambermini)
        fi
    fi
}


function run_tests_cmake(){
    # source $HOME/tmp/install/amber.sh # /Users/travis/tmp/install\nOverriding shell_session_update/config.h'
    python -m pip install numpy --user # in case Miniconda is not installed
    python $HOME/amber.run_tests -t test.pytraj -x $HOME/EXCLUDED_TESTS -n 1
    python $HOME/amber.run_tests -t test.pdb4amber -x $HOME/EXCLUDED_TESTS -n 1
    parmed -h # parmed test is too slow.
    python -c "import sander; print(sander)"
}
