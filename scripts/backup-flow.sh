#!/usr/bin/env bash

# backup-flow v0.1.1

set -euo pipefail

# region Configuration
SCRIPT_NAME=$0
RANDOM_STRING=$(openssl rand -base64 50 | tr -dc 'a-z0-9' | fold -w 10 | head -n 1)
BACKUP_YEAR=$(date +%Y)
BACKUP_MONTH=$(date +%m)
BACKUP_DAY=$(date +%d)
BACKUP_HOUR=$(date +%H)
BACKUP_MINUTE=$(date +%M)

# Directory where to store backups
BACKUP_STORAGE_PATH=/var/backup/directory
BACKUP_GENERATED_PATH="$BACKUP_STORAGE_PATH/$BACKUP_YEAR/$BACKUP_MONTH/$BACKUP_DAY/$BACKUP_HOUR-$BACKUP_MINUTE"

# Directory where required to backup files are stored
BACKUP_DIR_PATH=/var/www/directory

# Specify files and folders below, separate values with space
BACKUP_FILES=("$BACKUP_DIR_PATH/.env" "$BACKUP_DIR_PATH/.file1" "$BACKUP_DIR_PATH/file2")
BACKUP_DIRS=("$BACKUP_DIR_PATH/directory1")

# If dababase backup is required, change this to one of the allowed values: mysql / postgres
BACKUP_DATABASE_TYPE=postgres
BACKUP_DATABASE_NAME=${1-}
BACKUP_DATABASE_FILENAME="$BACKUP_DATABASE_NAME-$RANDOM_STRING.sql"

# Required only if BACKUP_DATABASE_TYPE set to postgres, skip it for mysql 
DATABASE_HOST=localhost
DATABASE_USER=db_user

# Requires my.cnf file at /home/user/my.cnf directory
MYSQLDUMP_COMMAND="mysqldump --single-transaction --quick --lock-tables=false $BACKUP_DATABASE_NAME"

# Configure .pgpass file location
PGPASSFILE_LOCATION="$BACKUP_DIR_PATH/.pgpass"
PGDUMP_COMMAND="pg_dump -h $DATABASE_HOST -U $DATABASE_USER -d $BACKUP_DATABASE_NAME -b -w --clean --if-exists"

# Rclone configuration
RCLONE_REMOTE_BACKUP=false
RCLONE_BINARY_PATH=$(command -v rclone)
RCLONE_OPERATION=copy
RCLONE_STORAGE_NAME=example-s3
RCLONE_REMOTE_PATH=bucket-name
RCLONE_COMMAND="$RCLONE_BINARY_PATH $RCLONE_OPERATION $RCLONE_STORAGE_NAME:$RCLONE_REMOTE_PATH $BACKUP_GENERATED_PATH"

# Restic configuration
BACKUP_RESTIC=true
RESTIC_BINARY_PATH=$(command -v restic)
RESTIC_BACKUP_TAGS="default-$BACKUP_YEAR-$BACKUP_MONTH"
RESTIC_BACKUP_COMMAND="$RESTIC_BINARY_PATH backup --tag ${RESTIC_BACKUP_TAGS} $BACKUP_STORAGE_PATH"

# Retention configuration
KEEP_LOCAL_BACKUPS_DAYS=6
# endregion

function _sanity_check() {
    if [ ! -d "$BACKUP_STORAGE_PATH" ]; then
        mkdir -p "$BACKUP_STORAGE_PATH"
    fi

    if [ ! -d "$BACKUP_GENERATED_PATH" ]; then
        mkdir -p "$BACKUP_GENERATED_PATH"
    fi
}

function _backup_mysql() {
    if [ -n "$BACKUP_DATABASE_NAME" ]; then
        echo "Running backup database: $BACKUP_DATABASE_NAME"
        $MYSQLDUMP_COMMAND > "$BACKUP_GENERATED_PATH/$BACKUP_DATABASE_FILENAME"

        _result=$?

        if [[ $_result -gt 0 ]]; then
            echo "Database backup failed with exit code $_result"
            echo "Removing directory $BACKUP_GENERATED_PATH"
            rm -rf "$BACKUP_GENERATED_PATH"
            exit $_result
        fi
    else
        echo "Please run this script with database name as first argument. Example: $SCRIPT_NAME mydatabase"
        exit 1
    fi
}

function _backup_postgres() {
    if [ -n "$BACKUP_DATABASE_NAME" ]; then
        echo "Running backup database: $BACKUP_DATABASE_NAME"
        export PGPASSFILE="$PGPASSFILE_LOCATION"
        $PGDUMP_COMMAND > "$BACKUP_GENERATED_PATH/$BACKUP_DATABASE_FILENAME"

        _result=$?

        if [[ $_result -gt 0 ]]; then
            echo "Database backup failed with exit code $_result"
            echo "Removing directory $BACKUP_GENERATED_PATH"
            rm -rf "$BACKUP_GENERATED_PATH"
            exit $_result
        fi
    else
        echo "Please run this script with database name as first argument. Example: $SCRIPT_NAME mydatabase"
        exit 1
    fi
}

function _backup_files() {
    echo "Backing up files..."

    for file in "${BACKUP_FILES[@]}"; do
        local _filename
        _filename=$(basename "$file")

        echo "Copying file: $file"
        cp "$file" "$BACKUP_GENERATED_PATH/${_filename}-$RANDOM_STRING"
    done
}

function _backup_directories() {
    echo "Backing up folders..."

    for folder in "${BACKUP_DIRS[@]}"; do
        echo "Copying folder: $folder"
        cp -r "$folder" "$BACKUP_GENERATED_PATH"
    done
}

function _copy_from_remote() {
    echo "Copying files from configured Rclone remote"
    $RCLONE_COMMAND
}

function _backup_restic() {
    $RESTIC_BACKUP_COMMAND
}

function _cleanup() {
    echo "Removing files and folders older then $KEEP_LOCAL_BACKUPS_DAYS days"
    find "$BACKUP_STORAGE_PATH" -type f -ctime +"$KEEP_LOCAL_BACKUPS_DAYS" -delete -print

    echo "Removing empty folders"
    find "$BACKUP_STORAGE_PATH" -empty -type d -delete -print
}

function main() {
    _sanity_check

    if [[ $BACKUP_DATABASE_TYPE == "mysql" ]]; then
        _backup_mysql
    elif [[ $BACKUP_DATABASE_TYPE == "postgres" ]]; then
        _backup_postgres
    fi

    _backup_files
    _backup_directories

    if [[ "$RCLONE_REMOTE_BACKUP" == "true" ]]; then
        _copy_from_remote
    fi

    if [[ "$BACKUP_RESTIC" == "true" ]]; then
        _backup_restic
    fi

    _cleanup

    echo "Backup finished to the folder: $BACKUP_GENERATED_PATH"
}

main
