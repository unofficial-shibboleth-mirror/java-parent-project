#! /bin/bash

LOCATION=$0
LOCATION=${LOCATION%/*}

source $LOCATION/create-project-common.sh

$ECHO "This script will create a new multi-module project and set up the parent module for the project."
$ECHO "Before you begin you must have already created an empty SVN repository that will recieve the project."
$ECHO ""

read -p "Please enter the SVN server URL, do not include the project name: " SVN_PROJ_URL
if [ -z "$SVN_PROJ_URL" ] ; then
    $ECHO "SVN repository URL can not be empty"
    exit 1
fi

read -p "Please enter the maven group ID for the project: " MVN_GROUP_ID
if [ -z "$MVN_GROUP_ID" ] ; then
    $ECHO "Maven group ID can not be empty"
    exit 1
fi

declare -r PROJ_ID=${SVN_PROJ_URL##*/}

# Check to make sure this command is going to write in to some existing directory
declare -r SVN_PROJ_DIR="$TMPDIR/$PROJ_ID-project"
check_path_not_exist $SVN_PROJ_DIR

$ECHO "Creating project structure"
create_svn_structure $SVN_PROJ_DIR
declare -r PROJ_DIR="$SVN_PROJ_DIR/trunk"

declare -r PROJ_PARENT_DIR=$PROJ_DIR/$PROJ_ID-parent
$MKDIR $PROJ_PARENT_DIR
check_retval $? "Unable to create project parent module directory"

create_pom_file $PROJ_PARENT_DIR $PARENT_PROJ_URL/resources/maven/pom.xml.tmpl $MVN_GROUP_ID $PROJ_ID-parent

download_file $PARENT_PROJ_URL/resources/eclipse/.parent-project.tmpl $PROJ_PARENT_DIR/.project
expand_macro $PROJ_PARENT_DIR/.project "MVN_ARTF_ID" $PROJ_ID-parent

create_site_file $PROJ_PARENT_DIR

download_file $PARENT_PROJ_URL/resources/maven/module-pom.xml.tmpl $PROJ_PARENT_DIR/module-pom.xml.tmpl
expand_macro $PROJ_PARENT_DIR/module-pom.xml.tmpl "MVN_GROUP_ID" $MVN_GROUP_ID
expand_macro $PROJ_PARENT_DIR/module-pom.xml.tmpl "MVN_PARENT_ARTF_ID" $PROJ_ID-parent
expand_macro $PROJ_PARENT_DIR/module-pom.xml.tmpl "PROJ_PARENT_DIR" ${PROJ_PARENT_DIR##*/}


$ECHO "Importing project structure into SVN repository $SVN_PROJ_URL"
import_checkout_svn_project $SVN_PROJ_DIR $SVN_PROJ_URL $PROJ_ID

$ECHO "Creation of project $PROJ_ID completed.  Working copy is located at ./$PROJ_ID"
exit 0
