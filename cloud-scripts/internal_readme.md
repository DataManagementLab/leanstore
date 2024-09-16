### Prerequisites

1. terraform installed
    - e.g download the latest linux binary https://developer.hashicorp.com/terraform/install

2. ansible, (important: min version 2.16)
    - https://docs.ansible.com/ansible/latest/installation_guide/installation_distros.html#installing-ansible-on-ubuntu


3. ansible terraform extension 

```
ansible-galaxy collection install cloud.terraform
```

### Project structure

- `main.tf` and `terraform.tfvars` define the cloud resources to be used
- `deploy.yml` sets up the VMs (software deps, configuration, etc.)

### Basic commands

1. Initialize terraform project:

```
terraform init
```

2. Make sure, that valid aws credentials are available,
eg. export the access keys from the portal within your shell

```
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."
```

3. Provide an SSH public key which will be used by ansible to access the VMs. Copy your pub key into the working directory with the name `benchmark_key.pub`

4. Sanity check, whether credentials work and infra setup is correct:

```
terraform plan
```

5. Provision (spin up) instances

```
terraform apply
```

6. Run ansible script to setup the machines. The IPs (inventory) are obtained from the terraform project via the terraform plugin for ansible. 

    6.1 install rsync on local machine and do sudo update before running the ansible-playbook 

```
ansible-playbook --user ubuntu --inventory terraform.yaml deploy.yml
```

7. Do the actual stuff on the machines. Either through custom ansible scripts or through vanilla SSH. 

8. Deprovision (destroy) instances
```
terraform destroy
```
