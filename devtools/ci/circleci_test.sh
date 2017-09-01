#!/bin/sh

version=16
function circleci_test(){
    # install conda
    bash $HOME/ambertools-ci/amber$version/AmberTools/src/configure_python --prefix $HOME
    export PATH=$HOME/miniconda/bin:$PATH
    for tarfile in `ls $HOME/TMP/amber-conda-bld/linux-64/ambertools-*.tar.bz2`; do
        python $HOME/ambertools-ci/amber$version/AmberTools/src/ambertools-binary-build/conda_tools/test_multiple_pythons.py $tarfile
    done
}

circleci_test
