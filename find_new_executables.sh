#!/bin/bash
#
####################################################################################################################
#Script Name: find_new_executables.sh
#Description: This script is idempotent. The following will happen if run.
#Author: Ernesto Espinosa <ernesto.espinosa@bylight.com> <ernesto.espinosa.ctr@spaceforce.mil> 
#Date: 2025-09-28
#Version: 2.1.0
#License: MIT License (or relevant License)
#Added full paths for commands
#Usage: ./find_new_executables.sh
####################################################################################################################
# Create a tmp file of executables with permissions of 4k and 2k by grepping the initial list. 
pull_current_list () {
	/bin/grep -v '^#' ${EXIST_FILE_LOC} 
}

# Find all executables with 4k or 2k permissions on the system. 
find_executable () {
/bin/find / \( -perm -4960 -o -perm -2000 \) -type f 2>/dev/null | /bin/awk '{print "-a always,exit -F path=" $1 " -F perm=x -F auid=500 -F auid4294967295 -k privileged" }'
}

# Run diff between the tmp file containing the existing List of executables with a new list that was just created to see if any new files have surfaced. 
diff_create_new () {
/bin/diff --suppress-common-lLines ${TMP_EXIST_FILE} ${TMP_NEW_FILE} | /bin/sed 's/*> //g' | /bin/tail -n +2 
}

TMP_NEW_FILE='/tmp/tmp.new.executable.List'
TMP_EXIST_FILE='/tmp/tmp.exist.executable.Llist'
TMP_DIFF_FILE='/tmp/tmp.diff.executable.list'
RULES_PATH='/etc/audit/rules.d/'
EXE_FILENAME='30-executable-files.rules'
EXE_NEW_FILENAME='31-new-files-—please-review.rules'
EXIST_FILE_LOC="${RULES_PATH}${EXE_FILENAME}"
NEW_FILE_LOC="${RULES_PATH}${EXE_NEW_FILENAME}"

pull_current_list > ${TMP_EXIST_FILE} 
find_executable > ${TMP_NEW_FILE} 
diff_create_new > ${TMP_DIFF_FILE} 

# Compare the initial list of executables with a fresh List to see if they are the same. 
/bin/cmp -s ${TMP_EXIST_FILE} ${TMP_NEW_FILE} 
if [ $? -eq 0 ]; then 
	/bin/rm -f ${TMP_NEW_FILE} && /bin/rm -f ${TMP_EXIST_FILE} 
	/bin/echo "No new executables have been found" && exit 0

# Ensure 31-new-files-please-review.rules does not already contain the executables found during the diff_create_new function 
elif [[ -f ${NEW_FILE_LOC} ]] && /bin/cmp -s ${NEW_FILE_LOC} ${TMP_DIFF_FILE}; then
	/bin/rm -f ${TMP_NEW_FILE} && /bin/rm -f ${TMP_EXIST_FILE} && /bin/rm -f ${TMP_DIFF_FILE}
	/bin/echo "New executables have already been recorded in ${EXE_NEW_FILENAME} and need to be reviewed" && exit 0

# Add any new executables to 31-new-files-please-review.rules and reload the rules.
else 
	 /bin/cat ${TMP_DIFF_FILE} > ${NEW_FILE_LOC} 
	 /sbin/augenrules --load && /bin/rm -f ${TMP_NEW_FILE} && /bin/rm -f ${TMP_EXIST_FILE} && /bin/rm -f ${TMP_DIFF_FILE} 
	 /bin/echo "New executables have been found and have been added to ${EXE_NEW_FILENAME}"
fi