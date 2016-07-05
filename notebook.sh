# Create the EC2 spot instance.
docker-machine create supercomputer \
    --driver amazonec2 \
    --amazonec2-region eu-west-1 \
    --amazonec2-zone b \
    --amazonec2-request-spot-instance \
    --amazonec2-spot-price 1.0 \
    --amazonec2-security-group docker-notebook \
    --amazonec2-instance-type c4.8xlarge

# Activate the spot instance as our current docker machine.
eval "$(docker-machine env supercomputer)"

# Attach the persistent EBS volume to the instance.
EC2_INSTANCE_ID="`docker-machine ssh supercomputer wget -q -O - http://instance-data/latest/meta-data/instance-id`"
EBS_VOLUME_ID="`aws ec2 describe-volumes --query "Volumes[*].[VolumeId]" --filters "Name=tag:Name,Values=docker-notebook" --region eu-west-1 --output text`"
aws ec2 attach-volume --volume-id $EBS_VOLUME_ID --instance-id $EC2_INSTANCE_ID --device /dev/xvdf --region eu-west-1
docker-machine ssh supercomputer "sudo mkdir /data && sudo mount /dev/xvdf /data"

# Run the Jupyter notebook.
docker run -d -p 8888:8888 -v /data:/home/jovyan/work -e PASSWORD=forespell forespell/docker-notebook
docker-machine ip supercomputer
