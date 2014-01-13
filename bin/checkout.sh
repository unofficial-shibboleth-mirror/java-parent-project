#! /bin/bash

LOCATION=$0
LOCATION=${LOCATION%/*}

source $LOCATION/create-project-common.sh

SVN_URL="https://svn.shibboleth.net"

$ECHO ""
$ECHO "This script will prompt you to checkout source code from $SVN_URL."
$ECHO ""

declare CHECKOUT_ALL=n

# Prompt to checkout a project.
function checkout {
    # $1 = utilities or "" or java-parent-projects
    # $2 = project
    # $3 = branch or tag or trunk

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
		CMD="$SVN checkout $SVN_URL$SVN_PATH/$PROJ/$3 $LOCAL_PATH$PROJ"
        $ECHO "$CMD"
        $CMD
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
    checkout "" "java-identity-provider" "trunk"
    checkout "" "java-opensaml" "trunk"
    checkout "" "java-metadata-aggregator" "trunk"
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
    		checkout "utilities" $PROJ "trunk"
    	fi    	
    done   
fi

$ECHO ""
