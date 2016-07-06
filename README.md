# Jupyter notebook data science stack

## One-time setup

1. Install the AWS CLI with `pip install awscli`. Install your AWS credentials under `~/.aws/credentials`.
2. Create an EBS volume in the availability zone `eu-west-1a` in the AWS console and give it the name `docker-notebook`.
3. After creation, an EBS volume is a raw block volume. To create a file system on it, run `docker-machine ssh supercomputer sudo mkfs -t ext4 /dev/xvdf` right after attaching the volume.
4. Add an inbound rule to the `docker-notebook` security group in the AWS console to allow traffic from port 80 and 443.
5. Set the environment variables `CLOUDFLARE_API_KEY` and `FORESPELL_NOTEBOOK_PASSWORD`. On Linux, use `~/.bashrc`, on macOS use `~/.bash_profile` and on Windows use `setx`.

## Starting and stopping the notebook server

To start the notebook server, simply run `notebook.sh` on Linux and macOS, or `notebook.bat` on Windows. Then go to https://notebook.forespell.com.

To stop the notebook server, simply run `docker-machine rm supercomputer`.
