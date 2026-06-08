#!/bin/csh -f

####################################################
# Responsible for syncing the IH, SC, and PT folders
# to solsticedisk. Works similarly to sync_spio2.sh.

#Authors: Gergely Koban, Nikolett Biro
####################################################

# --- CONFIG ---
set CHECK_INTERVAL = 300        # 5 minutes
set MAX_IDLE = 7200             # 2 hours
set MAX_RUNTIME = 64800         # 18 hours

set SRC_BASE = "$1" 
set SRC_DIR  = "$SRC_BASE/$2/IO2" 
set DEST_DIR = "gergelyk@solstice:/data/CLEAR/nikolett/REALTIME"

set sLOG = /nobackupp28/gkoban/SWMF_AWSRT/SWMF/sync_op.log

# Prevents "No match" errors if the directory is empty
set nonomatch

# ---- SANITY CHECKS ----
if ( "$SRC_BASE" == "" || "$2" == "" ) then
    echo "Usage: $0 <base_directory> <what to sync>"
    exit 1
endif

if ( ! -d "$SRC_DIR" ) then
    echo "Error: $SRC_DIR does not exist"
    exit 1
endif

if ( "$2" == "PT" ) then
    set SYNC_TO = "gergelyk@solstice:/data/CLEAR/nikolett/MITTENS/${SRC_BASE:t}"
else
    set SYNC_TO = "$DEST_DIR/${SRC_BASE:t}/$2"
endif


# --- TRACKERS ---
set start_time = `date +%s`
set last_activity = $start_time
set last_sig = ""

# CHANGED: Start with an empty list so existing files are processed immediately
#set old_files = ()

if ( "$2" == "PT" ) then
	/usr/bin/rsync -avz --partial --perms --chmod=ugo=rwx --size-only "$SRC_BASE/PARAM.in" "$SYNC_TO/" >>& $sLOG
endif

while (1)
    set now = `date +%s`
    @ elapsed = $now - $start_time
    @ idle = $now - $last_activity

    if ($elapsed >= $MAX_RUNTIME) then
        echo "Maximum runtime reached. Exiting."
        exit 0
    endif

    if ($idle >= $MAX_IDLE) then
        echo "No new files for $MAX_IDLE seconds. Exiting."
        exit 0
    endif

    # Get current files
    set current_files = ( $SRC_DIR/* )

    # Check if directory is actually empty (nonomatch returns the glob string itself)
    if ("$current_files" == "$SRC_DIR/*") then
        #set current_files = ()
	echo "Directory empty, waiting for new files..."
    else
	set current_sig = `ls -l $SRC_DIR | cksum`

	if ( "$current_sig" != "$last_sig" ) then
	    echo "Changes detected or initial sync required. Initiating sync..."
	    echo "Syncing folder $SRC_DIR at `date`" >>& $sLOG

	    /usr/bin/rsync -avz --partial --perms --chmod=ugo=rwx --size-only "$SRC_DIR/" "$SYNC_TO/" >>& $sLOG

	    set last_sig = "$current_sig"
	    set last_activity = `date +%s`
	    echo $last_activity
	else
	    echo "No changes detected in $SRC_DIR."
	endif
    endif
 
    echo "Waiting $CHECK_INTERVAL seconds for new files..."
    sleep $CHECK_INTERVAL
end

