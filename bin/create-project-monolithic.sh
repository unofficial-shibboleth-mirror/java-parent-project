#! /bin/bash

LOCATION=$0
LOCATION=${LOCATION%/*}

source $LOCATION/create-project-common.sh

$ECHO "This script will create a new monolithic project."
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

declare -r MVN_ARTF_ID=${SVN_PROJ_URL##*/}

# Check to make sure this command is going to write in to some existing directory
declare -r SVN_PROJ_DIR="$TMPDIR/$MVN_ARTF_ID-project"
check_path_not_exist $SVN_PROJ_DIR

$ECHO "Creating project structure"
create_svn_structure $SVN_PROJ_DIR
declare -r PROJ_DIR="$SVN_PROJ_DIR/trunk"

create_src $PROJ_DIR
create_assembly $PROJ_DIR
create_doc $PROJ_DIR
create_eclipse_files $PROJ_DIR $MVN_ARTF_ID
create_pom_file $PROJ_DIR $PARENT_PROJ_URL/resources/maven/pom.xml.tmpl $MVN_GROUP_ID $MVN_ARTF_ID 
create_site_file $PROJ_DIR

$ECHO "Importing project structure into SVN repository $SVN_PROJ_URL and checking out working copy to ./$MVN_ARTF_ID"
import_checkout_svn_project $SVN_PROJ_DIR $SVN_PROJ_URL $MVN_ARTF_ID

$ECHO "Setting SVN externals and ignore properties on ./$MVN_ARTF_ID"
set_svn_properties_commit_and_update "$MVN_ARTF_ID"

$ECHO "Creation of project $MVN_ARTF_ID completed.  Working copy is located at ./$MVN_ARTF_ID"
exit 0