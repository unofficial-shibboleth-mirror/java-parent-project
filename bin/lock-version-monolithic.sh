#! /bin/bash

# Adjusts the reference to the eclipse settings, project POM, and project 
# checkstyle configuration such that it points to static, tagged parent project
# information.

if [ $# != 2 ] ; then
    echo "Usage: $(basename $0) <VERSION> <DIRECTORY>"
    echo "   VERSION - the numeric version number of the parent project that the given project should be locked to"
    echo "   DIRECTORY - path to the project"
    exit 1;
fi

LOCATION=$0
LOCATION=${LOCATION%/*}

source $LOCATION/lock-version-common.sh

lock_externals $1 $2
lock_pom $1 $2
lock_checkstyle $1 $2
