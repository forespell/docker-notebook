# Jupyter notebook data science stack

Based on https://github.com/jupyter/docker-stacks.

## One-time setup

1. Install the AWS CLI with `pip install awscli`.
2. Create an EBS volume in the AWS console and use its volume id in notebook.[bat|sh].
3. After creation, an EBS volume is a raw block volume. To create a file system on it, run `docker-machine ssh supercomputer sudo mkfs -t ext4 /dev/xvdf`.
4. Don't forget to add an inbound rule to the `docker-notebook` security group in the AWS console to allow traffic from port 8888.

## Starting and stopping the notebook server

To start the notebook server, simply run `notebook.sh` on Linux and macOS, or `notebook.bat` on Windows.

To stop the notebook server, simply run `docker-machine rm supercomputer`.
