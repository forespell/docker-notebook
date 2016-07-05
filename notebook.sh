# Create the EC2 spot instance.
docker-machine create supercomputer \
    --driver amazonec2 \
    --amazonec2-region us-east-1 \
    --amazonec2-zone d \
    --amazonec2-request-spot-instance \
    --amazonec2-spot-price 1.0 \
    --amazonec2-security-group docker-notebook \
    --amazonec2-instance-type c4.8xlarge

# Activate the spot instance as our current docker machine.
eval "$(docker-machine env supercomputer)"

# Attach the persistent EBS volume to the instance.
EC2_INSTANCE_ID="`docker-machine ssh supercomputer wget -q -O - http://instance-data/latest/meta-data/instance-id`"
aws ec2 attach-volume --volume-id vol-15a6f9bf --instance-id $EC2_INSTANCE_ID --device /dev/sdf

# Run the Jupyter notebook.
docker run -d -p 8888:8888 -v /dev/sdf:/home/jovyan/work -e PASSWORD=forespell forespell/docker-notebook
docker-machine ip
