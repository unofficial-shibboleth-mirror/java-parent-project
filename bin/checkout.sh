#! /bin/bash

LOCATION=$0
LOCATION=${LOCATION%/*}

source $LOCATION/create-project-common.sh

SVN_URL="https://svn.shibboleth.net"

$ECHO ""
$ECHO "This script will prompt you to checkout source code from $SVN_URL."
$ECHO ""
$ECHO "This script is not that great, ymmv."
$ECHO ""

declare CHECKOUT_ALL=n
declare IGNORE_EXTERNALS=n
declare -r ECLIPSE_SETTINGS_TMP="$TMPDIR/eclipse-settings-tmp"

# Prompt to checkout a project.
function checkout {
    # $1 = utilities or "" or java-parent-projects
    # $2 = project
    # $3 = branch or tag or trunk
	# $4 = svn options

    # remove / from end of project name
    local PROJ="${2%/}"

    local LOCAL_PATH=''
    local SVN_PATH=''

    if [ -n "$1" ] ; then
        LOCAL_PATH="$1/"
        SVN_PATH="/$1"
    fi  

    read_y "Checkout $PROJ" CHECKOUT_PROJ
    if [ $CHECKOUT_PROJ == "y" ] ; then
		CMD="$SVN checkout ${4-} $SVN_URL$SVN_PATH/$PROJ/$3 $LOCAL_PATH$PROJ"
        $ECHO "$CMD"
        $CMD
                
        # If ignore externals was set _and_ passed as option, redundant conditional.
		if [ "$IGNORE_EXTERNALS" ] && [[ ${4-} == --ignore-externals ]] ; then
			if [ -n "$LOCAL_PATH" ] ; then
        		# Copy Eclipse settings to monolithic project
				copy_eclipse_settings "$LOCAL_PATH$PROJ"
        	else
        		# Copy Eclipse settings to multi-module project
				find_and_copy_eclipse_settings $PROJ
    		fi		
    	fi
    fi
}

# Prompts and returns user input.
function read_y {
    # $1 = text
    # $2 = return variable
    local _RESULTVAR=$2
    local RESULT="y"

    if [ $CHECKOUT_ALL == "y" ] ; then
	RESULT="y"
    else
		read -p "$1 (y/n) ? [y] : " -e REPLY
		if [ -n "$REPLY" ] ; then
            RESULT=$REPLY
		fi
    fi

    eval $_RESULTVAR="'$RESULT'"
}

# Download Eclipse .settings to newly created temporary directory
function download_eclipse_settings {
	check_path_not_exist $ECLIPSE_SETTINGS_TMP
	$MKDIR -p "$ECLIPSE_SETTINGS_TMP/.settings"
    check_retval $? "Unable to create Eclipse settings tmp directory"
	download_eclipse_settings_files $ECLIPSE_SETTINGS_TMP
}

# Copy Eclipse .settings from temporary directory
function find_and_copy_eclipse_settings {
	# TODO Make safer.
	for FILE in $(find "$1" -depth 2 -name .project -print)
	do    	
    	PARENT=$(dirname $FILE)
    	copy_eclipse_settings $PARENT
	done
}

# Copy Eclipse .settings from temporary directory to target
function copy_eclipse_settings {
    $ECHO "Copying Eclipse settings to $1"
    $CP -pr "$ECLIPSE_SETTINGS_TMP/.settings" "$1/"
}

# Ignore Subversion externals definitions for V3 projects ?
read -p "Ignore Subversion externals for V3 projects (y/n) ? [n] : " -e REPLY
if [ -n "$REPLY" ]
then
    echo "Downloading Subversion externals for V3 projects"
	IGNORE_EXTERNALS="--ignore-externals"
	download_eclipse_settings
fi

# Checkout all
read_y "Checkout all projects" CHECKOUT_ALL

# Checkout v2
read_y "Checkout v2 projects" CHECKOUT
if [ $CHECKOUT == "y" ] ; then
    checkout "java-parent-projects" "java-parent-project-v2" "trunk"
    checkout "" "java-opensaml2-main" "branches/REL_2"
    checkout "" "java-shib-idp2-main" "branches/REL_2"
    checkout "" "java-centralized-discovery" "branches/REL_1"
fi
$ECHO ""

# Checkout v3
read_y "Checkout v3 projects" CHECKOUT
if [ $CHECKOUT == "y" ] ; then
    checkout "java-parent-projects" "java-parent-project-v3" "trunk"
    checkout "" "java-identity-provider" "trunk" $IGNORE_EXTERNALS
    checkout "" "java-opensaml" "trunk" $IGNORE_EXTERNALS
    checkout "" "java-metadata-aggregator" "trunk" $IGNORE_EXTERNALS
fi
$ECHO ""

# Checkout utilities
read_y "Checkout utilities" CHECKOUT
if [ $CHECKOUT == "y" ] ; then
    for PROJ in `$SVN list $SVN_URL/utilities`
    do
    	# Ignore cpp* projects
    	if [[ $PROJ == cpp* ]] ; then
    		$ECHO "Ignoring $PROJ"
    	else
    		checkout "utilities" $PROJ "trunk" $IGNORE_EXTERNALS
    	fi    	
    done   
fi
$ECHO ""

# Cleanup temporary Eclipse settings directory
if [ -d "$ECLIPSE_SETTINGS_TMP" ] ; then
	echo "Deleting temporary Eclipse settings directory $ECLIPSE_SETTINGS_TMP"
	rm -r "$ECLIPSE_SETTINGS_TMP"
fi