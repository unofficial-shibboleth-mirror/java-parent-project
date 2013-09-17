#! /bin/bash

shopt -s -o nounset

# Commands used herein
declare -r CP=${CP:-"/bin/cp"}
declare -r CURL=${CURL:-"/usr/bin/curl"}
declare -r ECHO=${ECHO:-"/bin/echo"}
declare -r MKDIR=${MKDIR:-"/bin/mkdir"}
declare -r PERL=${PERL:-"/usr/bin/perl"}
declare -r RM=${RM:-"/bin/rm"}
declare -r SVN=${SVN:-"/usr/bin/svn"}
declare -r TOUCH=${TOUCH:-"/usr/bin/touch"}

# URL to the java parent project from which everything inherits
# we start with the trunk version and then use the *-lock-version commands before
# we do a release in order to lock this project to a specific parent project version
declare -r PARENT_PROJ_URL="https://svn.shibboleth.net/java-parent-projects/java-parent-project-v3/trunk"

# Checks that the given return value was 0 and, if not, prints a given error messages and exits
#
# $1 the return value to check
# $2 the error message to print if the return value is non-zero
function check_retval {
    if [ "$1" != 0 ]; then
        $ECHO "$2"
        exit 1
    fi
}

# Checks that a given path does not yet exist
# 
# $1 the path (directory or file) to check
function check_path_not_exist {
    if [ -e "$1" ]; then
        $ECHO "Path $1 already exists, can not continue"
        exit 1
    fi
}

# Downloads a file from a URL and stores it on the file system
#
# $1 URL of the file to download
# $2 local file to which the downloaded file will be written
function download_file {
    $CURL -s -o "$2" "$1"
    check_retval $? "Unable to download $1 and store it in $2"
}

# Creates the tradition branches, tags, trunk SVN structure within a given directory.
# If the given directory does not exist it will be created.
#
# $1 directory in which the SVN structure will be created
function create_svn_structure {
    $MKDIR -p "$1/branches" "$1/tags" "$1/trunk"
    check_retval $? "Unable to create SVN project directory $SVN_PROJ_DIR"
}

# Expand a macro within a file.
#
# $1 file that contains macros
# $2 macro; note this will be used in a regular expression so escape it properly
# $3 expanded value; note this will be used in a regular expression so escape it properly
function expand_macro {
    $PERL -p -i -e "s/$2/$3/g" "$1"
    check_retval $? "Unable to replace MVN_GROUP_ID macro in $1 with value $2"
}

# Creates the ./src directory structure within a given directory and places a logback-text.xml
# configuration file in the src/test/resources directory
#
# $1 directory within which the ./src directory structure will be created
function create_src {
    $MKDIR -p "$1/src/main/java" "$1/src/main/resources" "$1/src/test/java" "$1/src/test/resources"
    check_retval $? "Unable to create Maven src directories"
    
    download_file "$PARENT_PROJ_URL/resources/logback/logback-test.xml" "$1/src/test/resources/logback-test.xml"
    check_retval $? "Unable to download logback-text.xml into src/test/resources"
}

# Creates the src/main/assembly directory and places an initial assembly descriptor in it
#
# $1 directory within which the assembly directory will be created and descriptor placed
function create_assembly {
    $MKDIR -p "$1/src/main/assembly"
    check_retval $? "Unable to create src/main/assembly directory"

    download_file "$PARENT_PROJ_URL/resource/maven/assembly-bin.xml" "$1/src/main/assembly/bin.xml"
}

# Creates the doc directory with an empty RELEASE-NOTES.txt file and Apache 2 license
#
# $1 directory within which the doc directory will be created
function create_doc {
    $MKDIR "$1/doc"
    check_retval $? "Unable to create doc directory"

    download_file "$PARENT_PROJ_URL/resources/doc/LICENSE.txt" "$1/doc/LICENSE.txt"

    $TOUCH "$1/doc/RELEASE-NOTES.txt"
    check_retval $? "Unable to create empty RELEASE-NOTES.txt"
}

# Creates the .checkstyle, .classpath, and .project Eclipse settings files
#
# $1 directory in which the Eclipse settings files will be placed
# $2 project/artifact ID
function create_eclipse_files {
    download_file "$PARENT_PROJ_URL/resources/eclipse/.checkstyle" "$1/.checkstyle"
    download_file "$PARENT_PROJ_URL/resources/eclipse/.classpath" "$1/.classpath"
    download_file "$PARENT_PROJ_URL/resources/eclipse/.project.tmpl" "$1/.project"

    expand_macro $1/.project "MVN_ARTF_ID" $2
}

# Fetchs the template POM file and populates its macros.
#
# $1 directory in which the POM file will be placed
# $2 URL of the POM template
# $3 maven group ID
# $4 maven artifact ID
function create_pom_file {
    download_file $2 $1/pom.xml
    expand_macro $1/pom.xml "MVN_GROUP_ID" $3
    expand_macro $1/pom.xml "MVN_ARTF_ID" $4
}

# Creates the Maven site configuration
#
# $1 directory in which the site configuration will be placed
function create_site_file {
    $MKDIR -p "$1/src/site"
    check_retval $? "Unable to create site source directory"

    download_file "$PARENT_PROJ_URL/resources/maven/site.xml" "$1/src/site/site.xml"
    check_retval $? "Unable to download site descriptor"
}

# Import a new project in to a repository
#
# $1 Project directory; removed once import is completed
# $2 URL of repository into which the project will be imported
# $3 working directory into which the project will be checked out
function import_checkout_svn_project {
    $SVN import -q -m "Importing new project" "$1" "$2"
    check_retval $? "Unable to import $1 into SVN repository $2"

    $RM -rf $SVN_PROJ_DIR
    check_retval $? "Unable to delete temporary project directory $1"

    $SVN checkout -q "$2/trunk" "$3"
    check_retval $? "Unable to checkout $2/trunk into $3"
}

# Sets the SVN externals and ignore properties on a given directory, commits the change,
# and performs and SVN update to pull in the externals
#
# $1 directory on which the SVN properties will be set
function set_svn_properties_commit_and_update {
    download_file "$PARENT_PROJ_URL/resources/svn/externals.svn" "$TMPDIR/externals.svn"
    $SVN propset -q "svn:externals" -F "$TMPDIR/externals.svn" "$1"
    check_retval $? "Unable to set svn:externals property on $1"
    $RM "$TMPDIR/externals.svn"

    download_file "$PARENT_PROJ_URL/resources/svn/ignore.svn" "$TMPDIR/ignore.svn"
    $SVN propset -q "svn:ignore" -F "$TMPDIR/ignore.svn" "$1"
    check_retval $? "Unable to set svn:ignore property on $1"
    $RM "$TMPDIR/ignore.svn"
    
    $SVN commit -q -m "Committing svn.externals and svn.ignore" "$1"
    check_retval $? "Unable to commit svn:externals and svn:ignore of $1 failed."

    $SVN update -q $1
    check_retval $? "SVN udpate of $1 failed."
}
