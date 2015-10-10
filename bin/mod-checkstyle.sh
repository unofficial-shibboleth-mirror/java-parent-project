#! /bin/bash

# 2015-10-09 A little WIP script to help change the .checkstyle config location, for example "
#  find . -name '.checkstyle' -exec java-parent-project-v3/bin/mod-checkstyle.sh {} \;

LOCATION=$0
LOCATION=${LOCATION%/*}

source $LOCATION/create-project-common.sh

declare -r OLD='https:\/\/svn.shibboleth.net\/java-parent-projects\/java-parent-project-v3\/trunk\/resources\/checkstyle\/checkstyle.xml'
declare -r NEW='http:\/\/git.shibboleth.net\/view\/?p=java-parent-project-v3.git;a=blob_plain;f=resources\/checkstyle\/checkstyle.xml;hb=HEAD'

expand_macro $1 $OLD $NEW

$ECHO "Done."
exit 0
