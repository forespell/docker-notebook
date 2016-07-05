REM Create the EC2 spot instance.
docker-machine create supercomputer ^
    --driver amazonec2 ^
    --amazonec2-region eu-west-1 ^
    --amazonec2-zone b ^
    --amazonec2-request-spot-instance ^
    --amazonec2-spot-price 1.0 ^
    --amazonec2-security-group docker-notebook ^
    --amazonec2-instance-type c4.8xlarge

REM Activate the spot instance as our current docker machine.
@FOR /f "tokens=*" %%i IN ('docker-machine env supercomputer') DO @%%i

REM Attach the persistent EBS volume to the instance.
@FOR /f "delims=" %%i in ('docker-machine ssh supercomputer wget -q -O - http://instance-data/latest/meta-data/instance-id') do SET EC2_INSTANCE_ID=%%i
@FOR /f "delims=" %%i in ('aws ec2 describe-volumes --query "Volumes[*].[VolumeId]" --filters "Name=tag:Name,Values=docker-notebook" --region eu-west-1 --output text') do SET EBS_VOLUME_ID=%%i
aws ec2 attach-volume --volume-id %EBS_VOLUME_ID% --instance-id %EC2_INSTANCE_ID% --device /dev/xvdf --region eu-west-1
docker-machine ssh supercomputer "sudo mkdir /data && sudo mount /dev/xvdf /data && sudo chmod a+w /data"

REM Point notebook.forespell.com to the notebook server.
@FOR /f "delims=" %%i in ('docker-machine ip supercomputer') do SET EC2_INSTANCE_IP=%%i
curl -X PUT "https://api.cloudflare.com/client/v4/zones/27be6cf860eca466a0b1cdcadd719544/dns_records/1bbcf7bc8625624b9977c851cf38c409" -H "X-Auth-Email: devs@forespell.com" -H "X-Auth-Key: %CLOUDFLARE_API_KEY%" -H "Content-Type: application/json" --data "{\"id\":\"1bbcf7bc8625624b9977c851cf38c409\",\"type\":\"A\",\"name\":\"notebook.forespell.com\",\"content\":\"%EC2_INSTANCE_IP%\"}"

REM Run the Jupyter notebook.
docker run -d -p 80:8888 -v /data:/home/jovyan/work -e PASSWORD=%FORESPELL_NOTEBOOK_PASSWORD% forespell/docker-notebook
