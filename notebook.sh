# Configuration parameters.
# 36xCPU: c4.8xlarge, 1xGPU: p2.xlarge, 8xGPU: p2.8xlarge
MACHINE_NAME=supercomputer
AWS_REGION=eu-west-1
AWS_ZONE=b
AWS_INSTANCE_TYPE=c4.8xlarge
AWS_SPOT_PRICE=3.0
AWS_SECURITY_GROUP=default
AWS_EFS_NAME=docker-notebook-fs
NOTEBOOK_PASSWORD=sha1:7ee9c7fb3a3a:7e6eafcf492c5c595d71f9acf8df6bb3848a0e78

# Remove any existing key pairs on AWS.
docker-machine rm -f $MACHINE_NAME
aws ec2 delete-key-pair --key-name $MACHINE_NAME

# Create the EC2 spot instance.
docker-machine create $MACHINE_NAME \
    --driver amazonec2 \
    --amazonec2-region $AWS_REGION \
    --amazonec2-zone $AWS_ZONE \
    --amazonec2-request-spot-instance $AWS_SPOT_PRICE \
    --amazonec2-spot-price $AWS_SPOT_PRICE \
    --amazonec2-security-group $AWS_SECURITY_GROUP \
    --amazonec2-instance-type $AWS_INSTANCE_TYPE

# Activate the spot instance as our current docker machine.
eval "$(docker-machine env $MACHINE_NAME)"

# Mount the EFS.
AWS_EFS_ID="`aws efs describe-file-systems --region $AWS_REGION --output text | grep -Po 'fs-\w+(?=\s+available\s+$AWS_EFS_NAME)'`"
AWS_EFS_URL=$AWS_REGION$AWS_ZONE.$AWS_EFS_ID.efs.$AWS_REGION.amazonaws.com
docker-machine ssh $MACHINE_NAME "sudo apt-get install -y nfs-common && sudo mkdir /efs && sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 $AWS_EFS_URL:/ /efs"

# Point notebook.forespell.com to the notebook server.
AWS_EC2_INSTANCE_IP="`docker-machine ip $MACHINE_NAME`"
curl -X PUT "https://api.cloudflare.com/client/v4/zones/27be6cf860eca466a0b1cdcadd719544/dns_records/1bbcf7bc8625624b9977c851cf38c409" -H "X-Auth-Email: devs@forespell.com" -H "X-Auth-Key: $CLOUDFLARE_API_KEY" -H "Content-Type: application/json" --data "{\"id\":\"1bbcf7bc8625624b9977c851cf38c409\",\"type\":\"A\",\"name\":\"notebook.forespell.com\",\"content\":\"$AWS_EC2_INSTANCE_IP\"}"

# Run the Jupyter notebook.
docker run -d \
    -p 443:8888 \
    -p 6006:6006 \
    -v /efs:/home/jovyan/work \
    -e GEN_CERT=yes \
    -e GRANT_SUDO=yes \
    forespell/docker-notebook \
    start-notebook.sh --NotebookApp.password='$NOTEBOOK_PASSWORD'

# Set a CloudWatch alarm that terminates the notebook server after 2 hours of inactivity.
AWS_EC2_INSTANCE_ID="`docker-machine ssh $MACHINE_NAME wget -q -O - http://instance-data/latest/meta-data/instance-id`"
AWS_ACCOUNT_ID="`aws ec2 describe-security-groups --group-names default --query "SecurityGroups[0].OwnerId" --output text`"
# aws cloudwatch put-metric-alarm --alarm-name cpu-mon --alarm-description "Alarm when CPU is idle for 2 hours" --metric-name CPUUtilization --namespace AWS/EC2 --statistic Maximum --period 1800 --threshold 1 --comparison-operator LessThanThreshold  --dimensions "Name=InstanceId,Value=$AWS_EC2_INSTANCE_ID" --evaluation-periods 4 --alarm-actions arn:aws:swf:$AWS_REGION:$AWS_ACCOUNT_ID:action/actions/AWS_EC2.InstanceId.Terminate/1.0 --unit Percent
