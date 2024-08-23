$DBUSER = "username"
$DBPASS= "password"
$MAX_INCREMENTALS = 20
$BACKUP_FOLDER = "C:\MariaDBBackups\"
$BASE_DIR = Join-Path $BACKUP_FOLDER "Base"
$LOG_FOLDER = "C:\Windows\MariaDBBackupLogs\"
$MARIABACKUPEXE = "C:\Program Files\MariaDB 10.5\bin\mariabackup.exe"

# Get the list of incremental backup folders
$IncFolders = Get-ChildItem $BACKUP_FOLDER -Directory | Where-Object { $_.Name -match "^Inc\d+$" }
$IncFolderCount = $IncFolders.Count

# Create the log folder and start the transcript
if (-not (Test-Path $LOG_FOLDER)) {
    New-Item -ItemType Directory -Path $LOG_FOLDER
}

$TIMESTAMP = Get-Date -Format "yyyyMMdd_HHmmss"
$LOGFILE = Join-Path $LOG_FOLDER "backup_$timestamp.log"
Start-Transcript -Path $LOGFILE

# Create first backup if the base directory doesn't exist
if (-not (Test-Path $BASE_DIR)) {
    Write-Output "Creating initial backup"
    New-Item -ItemType Directory -Path $BASE_DIR
    & $MARIABACKUPEXE --backup --target-dir=$BASE_DIR --user="$DBUSER" --password="$DBPASS"
} else {
    if ($IncFolderCount -ge $MAX_INCREMENTALS -or -not (Get-ChildItem $BASE_DIR)) {
        # Delete backups and recreate if incrementals exceed max or base directory is empty
        Write-Output "Max incrementals reached or base directory is empty. Creating a new full backup."
        Remove-Item -Recurse -Force "$BACKUP_FOLDER\*"
        New-Item -ItemType Directory -Path $BASE_DIR
        & $MARIABACKUPEXE --backup --target-dir=$BASE_DIR --user="$DBUSER" --password="$DBPASS"
    } else {
        # Create an incremental backup
		"Creating incremental backup"
        $num1 = $IncFolderCount
        $num2 = $IncFolderCount + 1
        $targetDir = Join-Path $BACKUP_FOLDER "Inc$num2"
        $baseDir = if ($num1 -eq 0) { $BASE_DIR } else { Join-Path $BACKUP_FOLDER "Inc$num1" }
        $baseDir
		$targetDir
        Write-Output "Creating incremental backup number $num2"
        & $MARIABACKUPEXE --backup --target-dir=$targetDir --incremental-basedir=$baseDir --user="$DBUSER" --password="$DBPASS"
    }
}

# Delete all but most recent 12 logs
$files = Get-ChildItem -Path $LOG_FOLDER "*.log" | Sort-Object LastWriteTime -Descending
$filesToKeep = $files | Select-Object -First 12
$filesToDelete = $files | Where-Object { $_ -notin $filesToKeep }
$filesToDelete | Remove-Item

Stop-Transcript
