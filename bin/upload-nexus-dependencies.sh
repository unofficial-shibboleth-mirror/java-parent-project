#! /bin/bash

LOCATION=$0
LOCATION=${LOCATION%/*}

source $LOCATION/create-project-common.sh

$ECHO ""
$ECHO "This script will prompt you to upload signed transitive dependencies to Nexus."
$ECHO ""
$ECHO "This script is a work in progress, ymmv."
$ECHO ""
$ECHO "This script must be executed on the Nexus host to access the thirdparty repository."
$ECHO ""
$ECHO "Execute this script in a project directory containing pom.xml".
$ECHO ""
$ECHO "If pom.new.xml is present it should contain the new dependencies to be added."
$ECHO ""

declare -r DIFF=${DIFF:-"/usr/bin/diff"}
declare -r MVN=${MVN:-"/opt/maven/bin/mvn"}
declare -r RSYNC=${RSYNC:-"/usr/bin/rsync"}

declare -r SHIB_NEXUS_URL="https://build.shibboleth.net/nexus"
declare -r SHIB_NEXUS_HOME="/home/nexus"

declare YES_TO_ALL=n

# Prompts and returns user input.
function ask {
    # $1 = default y or n 
    # $2 = message text
    # $3 = return variable 
    local _RESULTVAR=$3
    local RESULT="$1"

    if [ $YES_TO_ALL == "y" ] ; then
	RESULT="y"
    else
		read -p "$2 (y/n) ? [$1] : " -e REPLY
		if [ -n "$REPLY" ] ; then
            RESULT=$REPLY
		fi
    fi

    eval $_RESULTVAR="'$RESULT'"
}

ask $SHIB_NEXUS_URL "Nexus URL" NEXUS_URL
$ECHO "Nexus URL is : $NEXUS_URL"
$ECHO ""

ask $SHIB_NEXUS_HOME "Nexus home directory" NEXUS_HOME
$ECHO "Nexus home directory is : $NEXUS_HOME"
$ECHO ""

ask n "Delete repository directories from previous attempt" CLEANUP
if [ $CLEANUP == "y" ] ; then
    $RM -rf "repository-old"
    check_retval $? "Unable to delete repository-old"
    
    $RM -rf "repository-new"
    check_retval $? "Unable to delete repository-new"
    
    $RM -rf "repository-diff"
    check_retval $? "Unable to delete repository-diff"
    
    $RM -rf "repository-test"
    check_retval $? "Unable to delete repository-test"
fi
$ECHO ""

ask y "Create directories" CREATE_DIRS
if [ $CREATE_DIRS == "y" ] ; then
    $MKDIR -v "repository-old"
    check_retval $? "Unable to create repository-old"
    
    $MKDIR -v "repository-new"
    check_retval $? "Unable to create repository-new"
    
    $MKDIR -v "repository-diff"
    check_retval $? "Unable to create repository-diff"
    
    $MKDIR -v "repository-test"
    check_retval $? "Unable to create repository-test"
fi
$ECHO ""

ask y "Build with old pom" BUILD_OLD_POM
if [ $BUILD_OLD_POM == "y" ] ; then
    $ECHO "$MVN --strict-checksums -Dmaven.repo.local=repository-old clean verify site -Prelease -DskipTests"
    $MVN --strict-checksums -Dmaven.repo.local=repository-old clean verify site -Prelease -DskipTests
fi
$ECHO ""

if [ -e pom.new.xml ] ; then
    ask y "Copy repository-old to repository-new" COPY_REPO_OLD_TO_REPO_NEW
    if [ $COPY_REPO_OLD_TO_REPO_NEW == "y" ] ; then
        $CP -pr repository-old/* repository-new/
    fi
    $ECHO ""

    ask n "Diff repository-old to repository-new" DIFF_REPO_OLD_TO_REPO_NEW
    if [ $DIFF_REPO_OLD_TO_REPO_NEW == "y" ] ; then
        $DIFF -r repository-old repository-new
    fi
    $ECHO ""

    ask y "Build with new pom" BUILD_NEW_POM
    if [ $BUILD_NEW_POM == "y" ] ; then
        $ECHO "$MVN --strict-checksums -Dmaven.repo.local=repository-new verify site -Prelease -DskipTests -f pom.new.xml"
        $MVN --strict-checksums -Dmaven.repo.local=repository-new verify site -Prelease -DskipTests -f pom.new.xml
    fi
fi
$ECHO ""

ask y "Create repository-diff" CREATE_REPO_DIFF
if [ $CREATE_REPO_DIFF == "y" ] ; then
    if [ -e pom.new.xml ] ; then
        $RSYNC -rcmv --include='*.jar' --include='*.pom' --exclude='net/shibboleth' --exclude='org/opensaml' -f 'hide,! */' --compare-dest=$NEXUS_HOME/sonatype-work/nexus/storage/thirdparty/ --compare-dest=$PWD/repository-old/ repository-new/ repository-diff/
    else
        $RSYNC -rcmv --include='*.jar' --include='*.pom' --exclude='net/shibboleth' --exclude='org/opensaml' -f 'hide,! */' --compare-dest=$NEXUS_HOME/sonatype-work/nexus/storage/thirdparty/ repository-old/ repository-diff/
    fi
fi
$ECHO ""

cd repository-diff

ask y "Delete empty directories from repository-diff" DEL_EMPTY_REPO_DIFF
if [ $DEL_EMPTY_REPO_DIFF == "y" ] ; then
    $FIND * -type d -empty -delete
fi
$ECHO ""

ask y "Print repository-diff" PRINT_REPO_DIFF
if [ $PRINT_REPO_DIFF == "y" ] ; then
    $FIND *
fi
$ECHO ""

ask y "Download signatures" DOWNLOAD_SIGNATURES
if [ $DOWNLOAD_SIGNATURES == "y" ] ; then
    $FIND * -name '*.jar' -exec $CURL -v -f -o {}.asc http://repo1.maven.org/maven2/{}.asc 2>&1 \; | grep 'GET\|HTTP'
    $FIND * -name '*.pom' -exec $CURL -v -f -o {}.asc http://repo1.maven.org/maven2/{}.asc 2>&1 \; | grep 'GET\|HTTP'
fi
$ECHO ""

ask y "Print unsigned artifacts" PRINT_UNSIGNED_ARTIFACTS
if [ $PRINT_UNSIGNED_ARTIFACTS == "y" ] ; then
    $FIND * -name '*.jar' '!' -exec test -e "{}.asc" \; -print
    $FIND * -name '*.pom' '!' -exec test -e "{}.asc" \; -print
fi
$ECHO ""

ask y "Validate signatures and retrieve keys automatically" SIGS
if [ $SIGS == "y" ] ; then
    $FIND * -name '*.asc' -exec gpg --keyserver hkp://pool.sks-keyservers.net --keyserver-options "auto-key-retrieve no-include-revoked" --verify {} \; -exec echo "$?" \;
fi
$ECHO ""

ask y "Make changes to Nexus" MODIFY_NEXUS
if [ $MODIFY_NEXUS == "y" ] ; then
    
    ask y "Print repository-diff before upload" PRINT_REPO_DIFF_AGAIN
    if [ $PRINT_REPO_DIFF_AGAIN == "y" ] ; then
        $FIND *
    fi
    $ECHO ""
    
    ask y "Write files to upload to log file" LOG_UPLOADED_FILES
    if [ $LOG_UPLOADED_FILES == "y" ] ; then
         $ECHO "$FIND * -type f -printf "%f\n" | sort > "../uploaded-to-nexus-$(date +%Y-%m-%d_%H-%M-%S).txt""
         $FIND * -type f -printf "%f\n" | sort > "../uploaded-to-nexus-$(date +%Y-%m-%d_%H-%M-%S).txt"
    fi
    $ECHO ""
    
    ask $USER "Nexus username" USERNAME
    $ECHO ""
    
    read -s -p "Enter Nexus password : " -e PASSWORD
    $ECHO ""
    
    ask y "Upload to Nexus" UPLOAD_TO_NEXUS
    if [ $UPLOAD_TO_NEXUS == "y" ] ; then
        $ECHO "$FIND * -name '*.asc' -exec $CURL -v -u $USERNAME:<pwd> --upload-file {} $NEXUS_URL/content/repositories/thirdparty/{} \; 2>&1 \; | grep 'PUT\|HTTP'"
        $FIND * -name '*.asc' -exec $CURL -v -u $USERNAME:$PASSWORD --upload-file {} $NEXUS_URL/content/repositories/thirdparty/{} 2>&1 \; | grep 'PUT\|HTTP'
    
        $ECHO "$FIND * -name '*.jar' -exec $CURL -v -u $USERNAME:<pwd> --upload-file {} $NEXUS_URL/content/repositories/thirdparty/{} \; 2>&1 \; | grep 'PUT\|HTTP'"
        $FIND * -name '*.jar' -exec $CURL -v -u $USERNAME:$PASSWORD --upload-file {} $NEXUS_URL/content/repositories/thirdparty/{} 2>&1 \; | grep 'PUT\|HTTP'
    
        $ECHO "$FIND * -name '*.pom' -exec $CURL -v -u $USERNAME:<pwd> --upload-file {} $NEXUS_URL/content/repositories/thirdparty/{} \; 2>&1 \; | grep 'PUT\|HTTP'"
        $FIND * -name '*.pom' -exec $CURL -v -u $USERNAME:$PASSWORD --upload-file {} $NEXUS_URL/content/repositories/thirdparty/{} 2>&1 \; | grep 'PUT\|HTTP'
    fi

    # TODO only rebuild Nexus metadata for new artifacts

    ask y "Rebuild Nexus metadata" REBUILD_NEXUS_METADATA
    if [ $REBUILD_NEXUS_METADATA == "y" ] ; then
        $ECHO "$CURL -v -u $USERNAME:$PASSWORD -X DELETE $NEXUS_URL/service/local/repositories/thirdparty/routing 2>&1 \; | grep 'DELETE\|HTTP'"
        $CURL -v -u $USERNAME:$PASSWORD -X DELETE $NEXUS_URL/service/local/repositories/thirdparty/routing 2>&1 \; | grep 'DELETE\|HTTP'
        
        $ECHO "$CURL -v -u $USERNAME:$PASSWORD -X DELETE $NEXUS_URL/service/local/metadata/repositories/thirdparty/content 2>&1 \; | grep 'DELETE\|HTTP'"
        $CURL -v -u $USERNAME:$PASSWORD -X DELETE $NEXUS_URL/service/local/metadata/repositories/thirdparty/content 2>&1 \; | grep 'DELETE\|HTTP'
        
        $ECHO "$CURL -v -u $USERNAME:$PASSWORD -X DELETE $NEXUS_URL/service/local/data_index/repositories/thirdparty/content 2>&1 \; | grep 'DELETE\|HTTP'"
        $CURL -v -u $USERNAME:$PASSWORD -X DELETE $NEXUS_URL/service/local/data_index/repositories/thirdparty/content 2>&1 \; | grep 'DELETE\|HTTP'
    fi
fi
$ECHO ""

$ECHO "If you want to build with central disabled, you should probably wait a few minutes for Nexus to update its checksums."

ask y "Build with central disabled" BUILD_TEST
if [ $BUILD_TEST == "y" ] ; then
    cd ../
    if [ -e pom.new.xml ] ; then
        $ECHO "$MVN --strict-checksums -Dmaven.repo.local=$HOME/repository-test clean verify site -Prelease,central-disabled -DskipTests -f pom.new.xml"
        $MVN --strict-checksums -Dmaven.repo.local=$HOME/repository-test clean verify site -Prelease,central-disabled -DskipTests -f pom.new.xml
    else 
        $ECHO "$MVN --strict-checksums -Dmaven.repo.local=$HOME/repository-test clean verify site -Prelease,central-disabled -DskipTests"
        $MVN --strict-checksums -Dmaven.repo.local=$HOME/repository-test clean verify site -Prelease,central-disabled -DskipTests
    fi
fi
$ECHO ""

$ECHO "Done."
exit 0
