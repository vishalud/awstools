#!/bin/bash

#Stop mysql and mongo before begining dump
if (( $(ps -ef | grep -v grep | grep mysql | wc -l) > 0 ))
then 
	/etc/init.d/mysql stop
else
	echo "Mysql already stopped. Continuing..."
fi

if (( $(ps -ef | grep -v grep | grep mongo | wc -l) > 0 ))
then /etc/init.d/mongodb stop
else
	echo "Mongodb already stopped. Continuing"

fi 

#Umount the volumes
umount /vol/

#Get current mysql and mongo volume id's and umount them
current_mysql_vol_id=`aws ec2 describe-volumes --region us-east-1 --filters Name=attachment.instance-id,Values=i-81db5168 Name=attachment.device,Values=/dev/sdf | awk '{print$7}' | grep vol`
current_mongo_vol_id=`aws ec2 describe-volumes --region us-east-1 --filters Name=attachment.instance-id,Values=i-81db5168 Name=attachment.device,Values=/dev/sdg | awk '{print$7}' | grep vol`

#Detach the above volumes
aws ec2 detach-volume --volume-id $current_mysql_vol_id
aws ec2 detach-volume --volume-id $current_mongo_vol_id

#Get the latest snapshot id's from current snapshots
latest_mysql_snapshot=`aws ec2 describe-snapshots --owner-ids 353026054305 --filters Name=volume-id,Values=vol-4374ee0a --query 'Snapshots[*].{ID:SnapshotId,Time:StartTime}' | tail -1 | awk '{print $1}'`
latest_mongo_snapshot=`aws ec2 describe-snapshots --owner-ids 353026054305 --filters Name=volume-id,Values=vol-020bb048 --query 'Snapshots[*].{ID:SnapshotId,Time:StartTime}' | tail -1 | awk '{print $1}'`


#Create a new volume from a snapshots
new_mysql_vol_id=`/usr/local/bin/aws ec2 create-volume --snapshot-id $latest_mysql_snapshot --availability-zone us-east-1c --volume-type io1 --iops 600 | awk '{print$8}'`
new_mongo_vol_id=`/usr/local/bin/aws ec2 create-volume --snapshot-id $latest_mongo_snapshot --availability-zone us-east-1c --volume-type io1 --iops 600 | awk '{print$8}'`


#Attach the new volumes to the the instance and map devices accordingly
aws ec2 attach-volume --volume-id $new_mysql_vol_id --instance-id i-d85ab30a --device /dev/sdf
aws ec2 attach-volume --volume-id $new_mongo_vol_id --instance-id i-d85ab30a --device /dev/sdg

sleep 60
#Mount the volumes back and restart services
mount /dev/xvdf /vol/
mount /dev/xvdg /mnt/mongo/

/etc/init.d/mysqld start && export LC_ALL=C &&  rm -f /var/run/mongodb/mongod.pid && rm -f /mnt/mongo/mongo/mongod.lock  && mongod --config /etc/mongod.conf
