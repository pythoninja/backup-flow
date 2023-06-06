# backup-flow

`backup-flow` is a Bash script that internally utilizes Restic for backing up files to a repository (referred to as a "repository" in Restic). It also provides the option to use Rclone for copying files from remote storage to the local system. Systemd Timers are employed to schedule periodic backups.

Please read the [Disclaimer](#disclaimer) section.

## Table of Contents

- [backup-flow](#backup-flow)
  - [Table of Contents](#table-of-contents)
  - [Disclaimer](#disclaimer)
  - [Features](#features)
  - [Installation](#installation)
    - [Prerequisites](#prerequisites)
    - [Installation Steps](#installation-steps)
  - [Configuration](#configuration)
      - [backup-flow](#backup-flow-1)
      - [Rclone](#rclone)
      - [Databases](#databases)
        - [MySQL / MariaDB](#mysql--mariadb)
        - [PostgreSQL](#postgresql)
      - [Restic](#restic)
      - [Systemd and Timers](#systemd-and-timers)
    - [Backup Scenarios](#backup-scenarios)
    - [Backup with Docker](#backup-with-docker)
  - [License](#license)

## Disclaimer

1. THIS SCRIPT IS STILL WORK IN PROGRESS AND CONTAINS KNOWN OR UNKNOWN ERRORS
2. USE THIS SCRIPT AT YOUR OWN RISK
3. ALWAYS CHECK YOUR BACKUPS AFTER RUNNING THIS SCRIPT

## Features

1. Back up selected folders to local storage.
2. Back up selected MySQL / PostgreSQL database to local storage.
3. Copy files from remote storage (using Rclone) to the local storage.
4. Upload folders from local storage to the Restic repository.
5. Includes a Systemd service unit and timer.
6. Clean up old files from the local storage.

## Installation

### Prerequisites

Before using the `backup-flow` script, please ensure that you have:

1. Knowledge of how to configure PostgreSQL or MySQL/MariaDB.
2. Installed `mysqldump` or `pg_dump` utilities.
3. Installed and configured [Rclone](https://rclone.org/downloads/).
4. Installed and configured [Restic](https://restic.readthedocs.io/en/latest/020_installation.html).

### Installation Steps

Follow these steps for installation.

## Configuration

#### backup-flow

Open the script and change the following options:

`BACKUP_STORAGE_PATH`— local directory path where to store all copied files

`BACKUP_DIR_PATH`— local directory path

`BACKUP_FILES`— array of files to copy to `BACKUP_STORAGE_PATH`

`BACKUP_DIRS`— as previous but for directories

`BACKUP_DATABASE_TYPE` — mysql or postgresql

`RCLONE_REMOTE_BACKUP` — enable if files from remote storage managed by Rclone should be copied to the `BACKUP_STORAGE_PATH`

`RCLONE_STORAGE_NAME` — Rclone remote storage name (check `~/.config/rclone/rclone.conf` or `rclone config`)

`RCLONE_REMOTE_PATH` — Rclone remote path

`BACKUP_RESTIC` — enable if you want to use Restic

`RESTIC_BACKUP_TAGS` — change from default value

Additionally, please review the script for other parameters. The options are documented with comments.

#### Rclone

Install and configure Rclone remote storage. Here is an example configuration for Minio:

```
[bs-s3]
type = s3
provider = Minio
access_key_id = access_key
secret_access_key = secret_key
endpoint = https://s3.domain.com
no_check_bucket = true
```

Check if it works with the command: `rclone ls bs-s3:/bucket-name/uploads`

```
     6467 untitled-design.jpg
     6467 scaled-1680-/untitled-design.jpg
     4203 thumbs-150-150/untitled-design.jpg
```

#### Databases

##### MySQL / MariaDB

To back up a MySQL / MariaDB server, put your credentials into `~/.my.cnf`. Here is an example:

```ini
[client]
#socket=
user=root
password="password"
```

To create this file, use the following command:

```bash
(umask 0077 && vim ~/.my.cnf)
```

Check if it works with the command: `mysql -e "select 1"`

```
+---+
| 1 |
+---+
| 1 |
+---+
```

##### PostgreSQL

To back up a PostgreSQL server, put your credentials into `~/.pgpass` (or specify the location using the PGPASSFILE environment variable). Here is an example:

```
# File format
# hostname:port:database:username:password
*:*:database_name:db_user:db_password
```

To create this file, use the following command:

```bash
(umask 0077 && vim ~/.pgpass)
```

Check if it works with the command: `psql -h db_hostname -d db_name -U db_user -c "select 1;"`

```
 ?column? 
----------
        1
(1 row)
```

Alternatively (without .pgpass file), you can pass environment variables: `PGPASSWORD=db_password psql -h db_hostname -d db_name -U db_user -c "select 1;"`

#### Restic

If you do not plan to use multiple Restic repositories, you can create a file with Restic configuration options. This allows you to use commands without providing common options to the CLI, such as `restic --repo path_to_repo snaphost` or `restic --repo path_to_repo prune`. Here is an example of `/etc/restic/environment`:

```
RESTIC_REPOSITORY="s3:https://minio.domain.com/backups-bucket"
AWS_ACCESS_KEY_ID="access_key"
AWS_SECRET_ACCESS_KEY="secret_key"
RESTIC_PASSWORD="restic_password"
```

Next, configure Bash (or your shell) to use these variables. In my case, I added the following to `~/.bashrc`:

```bash
# Restic configuration
if [ -f /etc/restic/environment ]; then
    set -o allexport
    . /etc/restic/environment
    set +o allexport
fi
```

Create Restic repository: `restic init`

Get stats: `restic stats`. Here is an example output:

```
repository 4021ce42 opened (version 2, compression level auto)
scanning...
Stats in restore-size mode:
     Snapshots processed:  2
        Total File Count:  1510
              Total Size:  32.015 MiB
```

#### Systemd and Timers

Download the service and timer files.

Run `systemctl daemon-reload`. Start the timer:

```bash
systemctl enable backup-flow-timer && systemctl start backup-flow.timer
```

### Backup Scenarios

Refer to the examples directory.

### Backup with Docker

If you have a database server running in Docker and don't want to install `pg_dump` or `mysqldump` locally, you can dump the database using a container. Here is an example to back up a PostgreSQL database:

```bash
docker run --rm --env PGUSER=db_user --env PGPASSWORD=db_password postgres:15 pg_dump -h db_hostname -d db_name -b -w --clean --if-exists > database_dump.sql
```

If you have a `.pgpass` file, mount it as a Docker volume:

```bash


docker run --rm --env PGUSER=db_user --volume "/root/.pgpass:/root/.pgpass" postgres:15 pg_dump -h db_hostname -d db_name -b -w --clean --if-exists > database_dump.sql
```

## License

There are no special requirements on usage and distribution.
