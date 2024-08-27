# AWS Test Deployment
Automates the deployment of the Benchmark using Terraform, Ansible, and AWS. It includes a test environment using LocalStack and mock EC2 containers for local testing before actual AWS deployment.

# Prerequisites
Ensure you have the following tools installed:
    
- Terraform
- AWS CLI
- Ansible
- Docker and Docker Compose (for local testing)

# Runing the Terraform
   
- terraform init
- terraform plan
- terraform apply
- terraform output

# Local Testing
1. Start LocalStack and Mock EC2 Containers: The mock-ec2 container uses a Dockerfile defined in the cloud-scripts directory. Ensure you have a public key (benchmark_key.pub) for SSH communication. Then, start the containers:
```bash
docker-compose up -d
```
2. Run the Ansible playbook with the mock inventory:
```bash
ansible-playbook -i inventory-mock.ini testansible.yml

ansible-playbook -i inventory-mock.ini playbook.yml
```
# AWS Deployment
1. Configure AWS CLI:
```bash
# set your_access_key_id to "test" for local test
aws configure
# Or set environment variables:
export AWS_ACCESS_KEY_ID=your_access_key_id
export AWS_SECRET_ACCESS_KEY=your_secret_access_key
export AWS_DEFAULT_REGION=your_region
```
2. Initialize Terraform:
```bash
terraform init
```
3. Plan and apply the Terraform configuration:
```bash
terraform plan
terraform apply
```
4. View the created resources:
```bash
terraform output
```
5. List EC2 instances:
```bash
 aws --endpoint-url=http://localhost:4566 ec2 describe-instances --query 'Reservations[].Instances[].[InstanceId,InstanceType,PublicIpAddress,Tags[?Key==`Name`]| [0].Value]' --output table --region us-west-2
```
    ------------------------------------------------------------------------------
    |                              DescribeInstances                             |
    +----------------------+-----------+-----------------+-----------------------+
    |  i-336fe92b8bc02b11b |  t2.micro |  54.214.17.173  |  bookie-0             |
    |  i-fcc293f05e4ce3cc2 |  t2.micro |  54.214.54.195  |  zk-2                 |
    |  i-40aea0772e9447714 |  t2.micro |  54.214.92.201  |  bookkeeper-client-1  |
    |  i-206fd71491b2cdf18 |  t2.micro |  54.214.85.38   |  bookkeeper-client-0  |
    |  i-87a4fbedcb1076cb7 |  t2.micro |  54.214.70.224  |  zk-0                 |
    |  i-2509f9fe79c67902c |  t2.micro |  54.214.55.127  |  bookie-2             |
    |  i-3d88722677cbd9109 |  t2.micro |  54.214.35.9    |  zk-1                 |
    |  i-21b8593ea3847f47d |  t2.micro |  54.214.254.185 |  bookie-1             |
    +----------------------+-----------+-----------------+-----------------------+

# Verifying the Deployment
## ZooKeeper
```bash
/opt/zookeeper/bin/zkServer.sh status
```
## BookKeeper
```bash
/opt/bookkeeper/bin/bookkeeper shell listbookies -rw
```
# Cleaning Up
To destroy the AWS resources created by Terraform:
```bash
terraform destroy
docker-compose down
```
