#! /bin/bash

LOCATION=$0
LOCATION=${LOCATION%/*}

source $LOCATION/create-project-common.sh

$ECHO "This script will create a new multi-module project and set up the parent module for the project."
$ECHO ""

read -p "Please enter the project name, e.g. idp-extension : " PROJ_ID
if [ -z "$PROJ_ID" ] ; then
    $ECHO "Project name can not be empty"
    exit 1
fi

read -p "Please enter the maven group ID, e.g. net.shibboleth.idp : " MVN_GROUP_ID
if [ -z "$MVN_GROUP_ID" ] ; then
    $ECHO "Maven group ID can not be empty"
    exit 1
fi

declare -r PROJ_DIR="java-$PROJ_ID"

$ECHO "Creating project directory $PROJ_DIR"
$MKDIR $PROJ_DIR
check_retval $? "Unable to create project directory $PROJ_DIR"

declare -r PROJ_PARENT_DIR=$PROJ_DIR/$PROJ_ID-parent
$ECHO "Creating project parent module directory $PROJ_DIR"
$MKDIR $PROJ_PARENT_DIR
check_retval $? "Unable to create project parent module directory $PROJ_PARENT_DIR"

$ECHO "Creating Eclipse default settings"
# create_eclipse_defaults $PROJ_PARENT_DIR

$ECHO "Creating parent POM"
create_pom_file $PROJ_PARENT_DIR $PARENT_PROJ_URL"resources/maven/pom.xml.tmpl" $MVN_GROUP_ID $PROJ_ID-parent
expand_macro $PROJ_PARENT_DIR/pom.xml "<packaging>jar<\/packaging>" "<packaging>pom<\/packaging>"

$ECHO "Creating Eclipse .project"
download_file "$PARENT_PROJ_URL"resources/eclipse/parent-project.tmpl $PROJ_PARENT_DIR/.project
expand_macro $PROJ_PARENT_DIR/.project "MVN_ARTF_ID" $PROJ_ID-parent

$ECHO "Creating Maven site file"
create_site_file $PROJ_PARENT_DIR

$ECHO "Creating template POM for modules"
download_file "$PARENT_PROJ_URL"resources/maven/module-pom.xml.tmpl $PROJ_PARENT_DIR/module-pom.xml.tmpl
expand_macro $PROJ_PARENT_DIR/module-pom.xml.tmpl "MVN_GROUP_ID" $MVN_GROUP_ID
expand_macro $PROJ_PARENT_DIR/module-pom.xml.tmpl "MVN_PARENT_ARTF_ID" $PROJ_ID-parent
expand_macro $PROJ_PARENT_DIR/module-pom.xml.tmpl "PROJ_PARENT_DIR" ${PROJ_PARENT_DIR##*/}

$ECHO "Creating git repository"
git_start_project $PROJ_DIR

$ECHO "Creation of project $PROJ_ID completed.  Working copy is located at ./$PROJ_ID"
$ECHO "Next, add modules using add-module-local.sh"
exit 0
