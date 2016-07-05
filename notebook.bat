REM Create the EC2 spot instance.
docker-machine create supercomputer ^
    --driver amazonec2 ^
    --amazonec2-region us-east-1 ^
    --amazonec2-zone d ^
    --amazonec2-request-spot-instance ^
    --amazonec2-spot-price 1.0 ^
    --amazonec2-security-group docker-notebook ^
    --amazonec2-instance-type c4.8xlarge

REM Activate the spot instance as our current docker machine.
@FOR /f "tokens=*" %i IN ('docker-machine env supercomputer') DO @%i

REM Attach the persistent EBS volume to the instance.
FOR /f "delims=" %%i in ('docker-machine ssh supercomputer wget -q -O - http://instance-data/latest/meta-data/instance-id') do SET EC2_INSTANCE_ID=%%i
aws ec2 attach-volume --volume-id vol-15a6f9bf --instance-id %EC2_INSTANCE_ID% --device /dev/xvdf --region us-east-1
docker-machine ssh supercomputer "sudo mkdir /data && sudo mount /dev/xvdf /data"

REM Run the Jupyter notebook.
docker run -d -p 8888:8888 -v /data:/home/jovyan/work -e PASSWORD=forespell forespell/docker-notebook
docker-machine ip
