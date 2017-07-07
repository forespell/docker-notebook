REM Configuration parameters.
REM 36xCPU: c4.8xlarge, 1xGPU: p2.xlarge, 8xGPU: p2.8xlarge
SET MACHINE_NAME=supercomputer
SET AWS_REGION=eu-west-1
SET AWS_ZONE=b
SET AWS_INSTANCE_TYPE=r4.8xlarge
SET AWS_SPOT_PRICE=3.0
SET AWS_SECURITY_GROUP=default
SET AWS_EFS_NAME=docker-notebook-fs
SET NOTEBOOK_PASSWORD=sha1:7ee9c7fb3a3a:7e6eafcf492c5c595d71f9acf8df6bb3848a0e78

REM Remove any existing key pairs on AWS.
docker-machine rm -f %MACHINE_NAME%
cmd /c aws ec2 delete-key-pair --key-name %MACHINE_NAME%

REM Create the EC2 spot instance.
docker-machine create %MACHINE_NAME% ^
    --driver amazonec2 ^
    --amazonec2-region %AWS_REGION% ^
    --amazonec2-zone %AWS_ZONE% ^
    --amazonec2-request-spot-instance ^
    --amazonec2-spot-price %AWS_SPOT_PRICE% ^
    --amazonec2-security-group %AWS_SECURITY_GROUP% ^
    --amazonec2-instance-type %AWS_INSTANCE_TYPE% ^
    --engine-install-url=https://web.archive.org/web/20170623081500/https://get.docker.com

REM Activate the spot instance as our current docker machine.
@FOR /f "tokens=*" %%i IN ('docker-machine env %MACHINE_NAME%') DO @%%i

REM Mount the EFS.
cmd /c aws efs describe-file-systems --region %AWS_REGION% --output text > tmp.txt
@FOR /f "delims=" %%i in ('grep -Po "fs-\w+(?=\s+available\s+%AWS_EFS_NAME%)" tmp.txt') do SET AWS_EFS_ID=%%i
cmd /c rm tmp.txt
SET AWS_EFS_URL=%AWS_REGION%%AWS_ZONE%.%AWS_EFS_ID%.efs.%AWS_REGION%.amazonaws.com
docker-machine ssh %MACHINE_NAME% "sudo apt-get install -y nfs-common && sudo mkdir /efs && sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 %AWS_EFS_URL%:/ /efs"

REM Point notebook.forespell.com to the notebook server.
@FOR /f "delims=" %%i in ('docker-machine ip %MACHINE_NAME%') do SET AWS_EC2_INSTANCE_IP=%%i
REM curl -X PUT "https://api.cloudflare.com/client/v4/zones/27be6cf860eca466a0b1cdcadd719544/dns_records/1bbcf7bc8625624b9977c851cf38c409" -H "X-Auth-Email: devs@forespell.com" -H "X-Auth-Key: %CLOUDFLARE_API_KEY%" -H "Content-Type: application/json" --data "{\"id\":\"1bbcf7bc8625624b9977c851cf38c409\",\"type\":\"A\",\"name\":\"notebook.forespell.com\",\"content\":\"%AWS_EC2_INSTANCE_IP%\"}"

REM Run the Jupyter notebook.
docker run -d ^
    -p 443:8888 ^
    -p 6006:6006 ^
    -v /efs:/home/jovyan/work ^
    -e GEN_CERT=yes ^
    -e GRANT_SUDO=yes ^
    forespell/docker-notebook ^
    start-notebook.sh --NotebookApp.password='%NOTEBOOK_PASSWORD%'

REM Set a CloudWatch alarm that terminates the notebook server after 2 hours of inactivity.
@FOR /f "delims=" %%i in ('docker-machine ssh %MACHINE_NAME% wget -q -O - http://instance-data/latest/meta-data/instance-id') do SET AWS_EC2_INSTANCE_ID=%%i
@FOR /f "delims=" %%i in ('aws ec2 describe-security-groups --group-names default --query "SecurityGroups[0].OwnerId" --output text') do SET AWS_ACCOUNT_ID=%%i
REM aws cloudwatch put-metric-alarm --alarm-name cpu-mon --alarm-description "Alarm when CPU is idle for 2 hours" --metric-name CPUUtilization --namespace AWS/EC2 --statistic Maximum --period 1800 --threshold 1 --comparison-operator LessThanThreshold  --dimensions "Name=InstanceId,Value=%AWS_EC2_INSTANCE_ID%" --evaluation-periods 4 --alarm-actions arn:aws:swf:%AWS_REGION%:%AWS_ACCOUNT_ID%:action/actions/AWS_EC2.InstanceId.Terminate/1.0 --unit Percent
