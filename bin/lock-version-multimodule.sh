#! /bin/bash

# Adjusts the references to the reference to the super POM in the parent module
# and the eclipse settings and checkstyle configuration for each project module
# such that it points to static, tagged parent project information.

if [ $# != 2 ] ; then
    echo "Usage: $(basename $0) <VERSION> <DIRECTORY>"
    echo "   VERSION - the numeric version number of the parent project that the given project should be locked to"
    echo "   DIRECTORY - path to the project"
    exit 1;
fi

LOCATION=$0
LOCATION=${LOCATION%/*}

source $LOCATION/lock-version-common.sh

for module in `ls "$2"` ; do
    if [ -d "$2/$module" ] ; then
        if [ ${module##*-} = "parent" ] ; then
            lock_pom $1 $2/$module
        else
            lock_externals $1 $2/$module
            lock_checkstyle $1 $2/$module
        fi
    fi
done
