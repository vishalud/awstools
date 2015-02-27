#!/bin/bash
# Safety feature: exit script if error is returned, or if variables not set.
# Exit if a pipeline results in an error.
set -ue
set -o pipefail

#######################################################################
#
## Automatic EBS Volume Snapshot Creation & Clean-Up Script
#
# - Determine the instance ID of the EC2 server on which the script runs
# - Gather a list of all volume IDs attached to that instance
# - Take a snapshot of each attached volume
# - The script will then delete all associated snapshots taken by the script that are older than 7 days
#
#######################################################################

## REQUIREMENTS:

## IAM USER:
#
# This script requires that a new user (e.g. ebs-snapshot) be created in the IAM section of AWS. 
# Here is a sample IAM policy for AWS permissions that this new user will require:
#
#{
#  "Statement": [
#    {
#      "Sid": "Stmt1345661449962",
#      "Action": [
#        "ec2:CreateSnapshot",
#        "ec2:DeleteSnapshot",
#        "ec2:CreateTags",
#        "ec2:DescribeInstanceAttribute",
#        "ec2:DescribeInstanceStatus",
#        "ec2:DescribeInstances",
#        "ec2:DescribeSnapshotAttribute",
#        "ec2:DescribeSnapshots",
#        "ec2:DescribeVolumeAttribute",
#        "ec2:DescribeVolumeStatus",
#        "ec2:DescribeVolumes",
#        "ec2:ReportInstanceStatus",
#        "ec2:ResetSnapshotAttribute"
#      ],
#      "Effect": "Allow",
#      "Resource": [
#        "*"
#      ]
#    }
#  ]
#}


## AWS CLI: This script requires the AWS CLI tools to be installed.
# Read more about AWS CLI at: https://aws.amazon.com/cli/

# ASSUMPTION: these commands are ran as the root user.
#
# Linux install instructions for AWS CLI:
# - Install Python pip (e.g. yum install python-pip or apt-get install python-pip)
# - Then run: pip install awscli

# Configure AWS CLI by running this command: 
#		aws configure

# Access Key & Secret Access Key: enter in the credentials generated above for the new IAM user
# Region Name: the region that this instance is currently in.
# Output Format: enter "text"

## SCRIPT SETUP:
# Copy this script to /opt/aws/ebs-snapshot.sh
# And make it exectuable: chmod +x /opt/aws/ebs-snapshot.sh

# Then setup a crontab job for nightly backups:
# (You will have to specify the location of the AWS CLI Config file)
#
# AWS_CONFIG_FILE="/root/.aws/config"
# 00 06 * * *     root    /opt/aws/ebs-snapshot.sh >> /var/log/ebs-snapshot.log 2>&1

export PATH=$PATH:/usr/local/bin/:/usr/bin

## START SCRIPT

# Set Variables
instance_id=`wget -q -O- http://169.254.169.254/latest/meta-data/instance-id`
today=`date +"%m-%d-%Y"+"%T"`
logfile="/var/log/ebs-snapshot.log"

# How many days do you wish to retain backups for? Default: 7 days
retention_days="7"
retention_date_in_seconds=`date +%s --date "$retention_days days ago"`

# Start log file: today's date
echo $today >> $logfile

# Grab all volume IDs attached to this instance, and export the IDs to a text file
aws ec2 describe-volumes  --filters Name=attachment.instance-id,Values=$instance_id --query Volumes[].VolumeId --output text | tr '\t' '\n' > /tmp/volume_info.txt 2>&1

# Take a snapshot of all volumes attached to this instance
for volume_id in $(cat /tmp/volume_info.txt)
do
    description="$(hostname)-backup-$(date +%Y-%m-%d)"
	echo "Volume ID is $volume_id" >> $logfile
    
	# Next, we're going to take a snapshot of the current volume, and capture the resulting snapshot ID
	snapresult=$(aws ec2 create-snapshot --output=text --description $description --volume-id $volume_id --query SnapshotId)
	
    echo "New snapshot is $snapresult" >> $logfile
         
    # And then we're going to add a "CreatedBy:AutomatedBackup" tag to the resulting snapshot.
    # Why? Because we only want to purge snapshots taken by the script later, and not delete snapshots manually taken.
    aws ec2 create-tags --resource $snapresult --tags Key=CreatedBy,Value=AutomatedBackup
done

# Get all snapshot IDs associated with each volume attached to this instance
rm /tmp/snapshot_info.txt --force
for vol_id in $(cat /tmp/volume_info.txt)
do
    aws ec2 describe-snapshots --output=text --filters "Name=volume-id,Values=$vol_id" "Name=tag:CreatedBy,Values=AutomatedBackup" --query Snapshots[].SnapshotId | tr '\t' '\n' | sort | uniq >> /tmp/snapshot_info.txt 2>&1
done

# Purge all instance volume snapshots created by this script that are older than 7 days as this is the retention period decided on 
for snapshot_id in $(cat /tmp/snapshot_info.txt)
do
    echo "Checking $snapshot_id..."
	snapshot_date=$(aws ec2 describe-snapshots --output=text --snapshot-ids $snapshot_id --query Snapshots[].StartTime | awk -F "T" '{printf "%s\n", $1}')
    snapshot_date_in_seconds=`date "--date=$snapshot_date" +%s`

    if (( $snapshot_date_in_seconds <= $retention_date_in_seconds )); then
        echo "Deleting snapshot $snapshot_id ..." >> $logfile
        aws ec2 delete-snapshot --snapshot-id $snapshot_id
    else
        echo "Not deleting snapshot $snapshot_id ..." >> $logfile
    fi
done

# One last carriage-return in the logfile...
echo "" >> $logfile

echo "Results logged to $logfile"
