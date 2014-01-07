#! /bin/bash

LOCATION=$0
LOCATION=${LOCATION%/*}

source $LOCATION/create-project-common.sh

$ECHO "This script will create a new monolithic project locally."
$ECHO "Eclipse .settings are downloaded directly instead of via svn:externals."
$ECHO ""

read -p "Please enter the project name, e.g. java-artifactId: " PROJ_NAME
if [ -z "$PROJ_NAME" ] ; then
    $ECHO "Project name ID can not be empty"
    exit 1
fi

read -p "Please enter the maven group ID for the project: " MVN_GROUP_ID
if [ -z "$MVN_GROUP_ID" ] ; then
    $ECHO "Maven group ID can not be empty"
    exit 1
fi

read -p "Please enter the maven artifact ID for the project: " MVN_ARTF_ID
if [ -z "$MVN_ARTF_ID" ] ; then
    $ECHO "Maven artifact ID can not be empty"
    exit 1
fi

declare -r PROJ_DIR="./$PROJ_NAME"

$ECHO "Creating project structure"
$MKDIR $PROJ_DIR
check_retval $? "Unable to create project directory $PROJ_DIR"

create_src $PROJ_DIR
create_assembly $PROJ_DIR
create_doc $PROJ_DIR
create_eclipse_files $PROJ_DIR $MVN_ARTF_ID
create_eclipse_settings_files $PROJ_DIR
create_pom_file $PROJ_DIR $PARENT_PROJ_URL/resources/maven/pom.xml.tmpl $MVN_GROUP_ID $MVN_ARTF_ID 
create_site_file $PROJ_DIR

$ECHO "Creation of project $MVN_ARTF_ID completed and is located at $PROJ_DIR"
exit 0