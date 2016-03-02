#! /bin/bash

LOCATION=$0
LOCATION=${LOCATION%/*}

source $LOCATION/create-project-common.sh

read -p "Please enter the maven artifact ID for the project: " MVN_ARTF_ID
if [ -z "$MVN_ARTF_ID" ] ; then
    $ECHO "Maven artifact ID can not be empty"
    exit 1
fi

declare -r PROJ_DIR="."
declare -r MODULE_DIR="$PROJ_DIR/$MVN_ARTF_ID"

$ECHO "Creating module structure"
$MKDIR $MODULE_DIR
check_retval $? "Unable to create module directory $MODULE_DIR"

create_src $MODULE_DIR
create_eclipse_files $MODULE_DIR $MVN_ARTF_ID

$ECHO "Downloading Eclipse .settings files"
create_eclipse_settings_files $MODULE_DIR

$CP $PROJ_DIR/*-parent/module-pom.xml.tmpl "$MODULE_DIR/pom.xml"
check_retval $? "Unable to copy module POM template to $MODULE_DIR"

expand_macro $MODULE_DIR/pom.xml "MVN_ARTF_ID" $MVN_ARTF_ID

download_file $PARENT_PROJ_URL"resources/git/gitignore" "$MODULE_DIR/.gitignore"

$ECHO "Creation of module $MVN_ARTF_ID completed."
exit 0
