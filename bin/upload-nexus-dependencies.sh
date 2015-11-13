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
		read -p "$2 ? [$1] : " -e REPLY
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
    $MKDIR -pv "repository-old"
    check_retval $? "Unable to create repository-old"
    
    $MKDIR -pv "repository-new"
    check_retval $? "Unable to create repository-new"
    
    $MKDIR -pv "repository-diff"
    check_retval $? "Unable to create repository-diff"
    
    $MKDIR -pv "repository-test"
    check_retval $? "Unable to create repository-test"
fi
$ECHO ""

$ECHO "There are 4 (really only 3) choices :"
$ECHO " 1. Run verify goal"
$ECHO " 2. Run a Maven plugin"
$ECHO " 3. Upload an artifact"
$ECHO " You will be prompted for each."
$ECHO ""

ask n "1. Run verify goal" BUILD_OLD_POM
if [ $BUILD_OLD_POM == "y" ] ; then
    DEFAULT_COMMAND_LINE_OPTIONS="-DskipTests=true"
    ask $DEFAULT_COMMAND_LINE_OPTIONS " Command line options" COMMAND_LINE_OPTIONS

    $ECHO "$MVN --strict-checksums -Dmaven.repo.local=repository-old clean verify site -Prelease $COMMAND_LINE_OPTIONS"
    $MVN --strict-checksums -Dmaven.repo.local=repository-old clean verify site -Prelease  $COMMAND_LINE_OPTIONS
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

ask n "2. Run a Maven plugin" RUN_MAVEN_PLUGIN
if [ $RUN_MAVEN_PLUGIN == "y" ] ; then
    read -p "Command line options ? " RUN_MAVEN_PLUGIN_COMMAND_LINE_OPTIONS
    DEFAULT_MAVEN_PLUGIN="dependency:resolve"
    ask $DEFAULT_MAVEN_PLUGIN " Which plugin" MAVEN_PLUGIN
    $ECHO "MAVEN_PLUGIN is : $MAVEN_PLUGIN"
    $ECHO "DEFAULT_MAVEN_PLUGIN is : $DEFAULT_MAVEN_PLUGIN"
    $ECHO ""
    $ECHO "$MVN --strict-checksums -Dmaven.repo.local=repository-old $MAVEN_PLUGIN $RUN_MAVEN_PLUGIN_COMMAND_LINE_OPTIONS"
    $MVN --strict-checksums -Dmaven.repo.local=repository-old $MAVEN_PLUGIN $RUN_MAVEN_PLUGIN_COMMAND_LINE_OPTIONS
fi
$ECHO ""

ask n "3. Upload an artifact" UPLOAD_ARTIFACT
if [ $UPLOAD_ARTIFACT == "y" ] ; then
    DEFAULT_ARTIFACT_TO_UPLOAD="groupId:artifactId:version"
    $ECHO " Specify artifact in format : groupId:artifactId:version[:packaging][:classifier]"
    $ECHO " For example : org.eclipse.jetty:jetty-distribution:9.3.2.v20150730:tar.gz"
    ask $DEFAULT_ARTIFACT_TO_UPLOAD " Which artifact" ARTIFACT_TO_UPLOAD
    $ECHO " ARTIFACT_TO_UPLOAD is : $ARTIFACT_TO_UPLOAD"
    $ECHO ""
    DEFAULT_COMMAND_LINE_OPTIONS="-Dtransitive=true"
    ask $DEFAULT_COMMAND_LINE_OPTIONS " Command line options, for example -Dtransitive=false" COMMAND_LINE_OPTIONS
    $ECHO " COMMAND_LINE_OPTIONS is : $COMMAND_LINE_OPTIONS"
    $ECHO ""
    
    $ECHO "$MVN --strict-checksums -Dmaven.repo.local=repository-old org.apache.maven.plugins:maven-dependency-plugin:RELEASE:get -Dartifact=$ARTIFACT_TO_UPLOAD $COMMAND_LINE_OPTIONS"
    $MVN --strict-checksums -Dmaven.repo.local=repository-old org.apache.maven.plugins:maven-dependency-plugin:RELEASE:get -Dartifact=$ARTIFACT_TO_UPLOAD $COMMAND_LINE_OPTIONS
fi
$ECHO ""

ask y "Create repository-diff" CREATE_REPO_DIFF
if [ $CREATE_REPO_DIFF == "y" ] ; then
    if [ -e pom.new.xml ] ; then
        $RSYNC -rcmv --include='*.pom' --include='*.jar' --include='*.war' --include='*.zip' --include='*.tar.gz' --exclude='net/shibboleth' --exclude='org/opensaml' --exclude='edu/internet2/middleware' -f 'hide,! */' --compare-dest=$NEXUS_HOME/sonatype-work/nexus/storage/thirdparty/ --compare-dest=$PWD/repository-old/ repository-new/ repository-diff/
    else
        $RSYNC -rcmv --include='*.pom' --include='*.jar' --include='*.war' --include='*.zip' --include='*.tar.gz' --exclude='net/shibboleth' --exclude='org/opensaml' --exclude='edu/internet2/middleware' -f 'hide,! */' --compare-dest=$NEXUS_HOME/sonatype-work/nexus/storage/thirdparty/ repository-old/ repository-diff/
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
    $ECHO " Signatures are downloaded using cURL from Maven Central by default."
    $ECHO " An alternative repository may be provided, for example, http://repo.spring.io/snapshot."
    DEFAULT_DOWNLOAD_ASC_URL="http://repo1.maven.org/maven2"
    ask $DEFAULT_DOWNLOAD_ASC_URL " Download signatures from" DOWNLOAD_ASC_URL
    $ECHO " DOWNLOAD_ASC_URL is : $DOWNLOAD_ASC_URL"
    $ECHO ""
    $ECHO "$FIND * -type f -exec $CURL -v -f -o {}.asc $DOWNLOAD_ASC_URL/maven2/{}.asc 2>&1 \; | grep 'GET\|HTTP'"
    $FIND * -type f -exec $CURL -v -f -o {}.asc $DOWNLOAD_ASC_URL/{}.asc 2>&1 \; | grep 'GET\|HTTP'
 
fi
$ECHO ""

ask y "Print unsigned artifacts" PRINT_UNSIGNED_ARTIFACTS
if [ $PRINT_UNSIGNED_ARTIFACTS == "y" ] ; then
    $FIND * -type f '!' -name '*.asc' '!' -exec test -e "{}.asc" \; -print
fi
$ECHO ""

ask y "Validate signatures and retrieve keys automatically" SIGS
if [ $SIGS == "y" ] ; then
    $ECHO "$FIND * -name '*.asc' -exec gpg --keyserver hkp://pool.sks-keyservers.net --keyserver-options "auto-key-retrieve no-include-revoked" --verify {} \; -exec echo "$?" \;"
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
    
    ask y "Print repository-diff files before upload" PRINT_REPO_DIFF_FILES
    if [ $PRINT_REPO_DIFF_FILES == "y" ] ; then
        $FIND * -type f
    fi
    $ECHO ""
    
    ask y "Write files to upload to log file" LOG_UPLOADED_FILES
    if [ $LOG_UPLOADED_FILES == "y" ] ; then
         $ECHO "$FIND * -type f -print | sort | grep -v "\.asc" > "../uploaded-to-nexus-$(date +%Y-%m-%d_%H-%M-%S).txt""
         $FIND * -type f -print | sort | grep -v "\.asc"> "../uploaded-to-nexus-$(date +%Y-%m-%d_%H-%M-%S).txt"
    fi
    $ECHO ""
    
    ask $USER "Nexus username" USERNAME
    $ECHO ""
    
    read -s -p "Enter Nexus password : " -e PASSWORD
    $ECHO ""
    
    ask y "Upload to Nexus" UPLOAD_TO_NEXUS
    if [ $UPLOAD_TO_NEXUS == "y" ] ; then
    	$ECHO "$FIND * -type f -exec $CURL -v -u $USERNAME:<pwd> --upload-file {} $NEXUS_URL/content/repositories/thirdparty/{} \; 2>&1 \; | grep 'PUT\|HTTP'"
        $FIND * -type f -exec $CURL -v -u $USERNAME:$PASSWORD --upload-file {} $NEXUS_URL/content/repositories/thirdparty/{} 2>&1 \; | grep 'PUT\|HTTP'
    fi

    ask y "Rebuild Nexus metadata" REBUILD_NEXUS_METADATA
    if [ $REBUILD_NEXUS_METADATA == "y" ] ; then
        $ECHO "Rebuilding Nexus metadata for uploaded artifacts..."
        $FIND * -type d -links 2 | while read -r ARTIFACT; do
            $ECHO "Rebuilding Nexus metadata for $ARTIFACT"
            $ECHO "$CURL -v -u $USERNAME:$PASSWORD -X DELETE $NEXUS_URL/service/local/metadata/repositories/thirdparty/content/$ARTIFACT 2>&1 \; | grep 'DELETE\|HTTP'"
                   $CURL -v -u $USERNAME:$PASSWORD -X DELETE $NEXUS_URL/service/local/metadata/repositories/thirdparty/content/$ARTIFACT 2>&1 \; | grep 'DELETE\|HTTP'
        done
        $ECHO "Done rebuilding Nexus metadata for uploaded artifacts."

        $ECHO "$CURL -v -u $USERNAME:$PASSWORD -X DELETE $NEXUS_URL/service/local/repositories/thirdparty/routing 2>&1 \; | grep 'DELETE\|HTTP'"
        $CURL -v -u $USERNAME:$PASSWORD -X DELETE $NEXUS_URL/service/local/repositories/thirdparty/routing 2>&1 \; | grep 'DELETE\|HTTP'

        $ECHO "$CURL -v -u $USERNAME:$PASSWORD -X DELETE $NEXUS_URL/service/local/data_index/repositories/thirdparty/content 2>&1 \; | grep 'DELETE\|HTTP'"
        $CURL -v -u $USERNAME:$PASSWORD -X DELETE $NEXUS_URL/service/local/data_index/repositories/thirdparty/content 2>&1 \; | grep 'DELETE\|HTTP'
    fi
fi
$ECHO ""

$ECHO "If you want to build with central disabled, you should probably wait a few minutes for Nexus to update its checksums."

ask n "Build with central disabled" BUILD_TEST
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
