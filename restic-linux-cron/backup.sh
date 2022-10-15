#!/bin/bash

export RESTIC_PASSWORD="..."
export RESTIC_REPOSITORY="..."
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."

date
restic backup /home/fctrserver/serverfiles/saves
restic forget --prune --keep-last 10 --keep-hourly 72 --keep-daily 60 --keep-weekly 52 --keep-monthly 36
