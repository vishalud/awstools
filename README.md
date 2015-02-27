The AWS scripts repo


**How it works:**
#ebs-snapshot.sh
- Determine the instance ID of the EC2 server on which the script runs
- Gather a list of all volume IDs attached to that instance
- Take a snapshot of each attached volume
- The script will then delete all associated snapshots taken by the script that are older than 7 days



===================================

**REQUIREMENTS**

**IAM User:** This script requires that a new user (e.g. ebs-snapshot) be created in the IAM section of AWS.   
Here is a sample IAM policy for AWS permissions that this new user will require:

```
{
  "Statement": [
    {
      "Action": [
        "ec2:CreateSnapshot",
        "ec2:DeleteSnapshot",
        "ec2:CreateTags",
        "ec2:DescribeInstanceAttribute",
        "ec2:DescribeInstanceStatus",
        "ec2:DescribeInstances",
        "ec2:DescribeSnapshotAttribute",
        "ec2:DescribeSnapshots",
        "ec2:DescribeVolumeAttribute",
        "ec2:DescribeVolumeStatus",
        "ec2:DescribeVolumes",
        "ec2:ReportInstanceStatus",
        "ec2:ResetSnapshotAttribute"
      ],
      "Effect": "Allow",
      "Resource": [
        "*"
      ]
    }
  ]
}
```
<br />

**AWS CLI:** This script requires the AWS CLI tools to be installed.

Linux install instructions for AWS CLI:
 - Make sure Python pip is installed (e.g. yum install python-pip, or apt-get install python-pip)
 - Then run: 
```
pip install awscli
```
Once the AWS CLI has been installed, you'll need to configure it with the credentials of the IAM user created above:

```
aws configure
```

_Access Key & Secret Access Key_: enter in the credentials generated above for the new IAM user.  
_Region Name_: the region that this instance is currently in.  
_Output Format_: enter "text"  


Then copy this Bash script to /opt/aws/ebs-snapshot.sh and make it executable:
```
chmod +x /opt/aws/ebs-snapshot.sh
```

You should then setup a cron job in order to schedule a nightly backup. Example crontab job:
```
55 22 * * * root  AWS_CONFIG_FILE="/root/.aws/config" /opt/aws/ebs-snapshot.sh > /var/log/ebs-snapshot.log 2>&1


#modify-ebs.sh
# Introduction:
modify-ebs-volume.py was created to modify an EBS volumes attached to a running instance. The typical use case would be to increase the size of the EBS device or to change the volume type from standard to provisioned iops. The script follows the procedure detailed in http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-expand-volume.html. The script does not change the file system on the volume itself - this is left up to the user although some operating systems may automatically grow the file system to the size of a given volume.
# Directions For Use:
## Examples of Use:

    ./ec2-modify-ebs-volume.py --instance-id i-6702f11d --volume-size 60
the above example would modify the root device of i-6702f11d to be 60 GB in size.

    ./ec2-modify-ebs-volume.py --instance-id i-6702f11d --device /dev/sdf --volume-size 60
the above example would modify the /dev/sdf device to be 60 GB in size.

    ./ec2-modify-ebs-volume.py --instance-id i-6702f11d --volume-type io1 --iops 527
the above example would modify the root device of i-6702f11d to a provisioned iops volume with 527 iops performance.
## Required Parameters:
ec2-modify-ebs-volume.py requires the `--instance-id` parameter.
## Optional Parameters:
optional parameters are available by running `ec2-modify-ebs-volume.py --help`.
