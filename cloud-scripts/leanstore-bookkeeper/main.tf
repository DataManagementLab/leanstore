terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.56"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.1"
    }
    ansible = {
      source = "ansible/ansible"
      version = "1.3.0"
    }
  }
}

variable "public_key_path" {
  description = <<DESCRIPTION
Path to the SSH public key to be used for authentication.
Ensure this keypair is added to your local SSH agent so provisioners can
connect.

Example: ~/.ssh/bookkeeper_aws.pub
DESCRIPTION
}

resource "random_id" "hash" {
  byte_length = 8
}

variable "key_name" {
  default     = "bookkeeper-benchmark-key"
  description = "Desired name prefix for the AWS key pair"
}

variable "region" {}
variable "az" {}
variable "ami" {}
variable "spot" {}
variable "instance_types" {}
variable "num_instances" {}

provider "aws" {
  region = var.region
   default_tags {
      tags = {
      Project = "logservice"
    }
  }
}

# Create a VPC to launch our instances into
resource "aws_vpc" "benchmark_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "Bookkeeper-Benchmark-VPC-${random_id.hash.hex}"
  }
}

# Create an internet gateway to give our subnet access to the outside world
resource "aws_internet_gateway" "bookkeeper" {
  vpc_id = aws_vpc.benchmark_vpc.id
}

# Grant the VPC internet access on its main route table
resource "aws_route" "internet_access" {
  route_table_id         = aws_vpc.benchmark_vpc.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.bookkeeper.id
}

# Create a subnet to launch our instances into
resource "aws_subnet" "benchmark_subnet" {
  vpc_id                  = aws_vpc.benchmark_vpc.id
  cidr_block              = "10.0.0.0/24"
  map_public_ip_on_launch = true
  availability_zone       = var.az
}

resource "aws_security_group" "benchmark_security_group" {
  name   = "terraform-bookkeeper-${random_id.hash.hex}"
  vpc_id = aws_vpc.benchmark_vpc.id

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All ports open within the VPC
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Prometheus/Dashboard access
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Benchmark-Security-Group-${random_id.hash.hex}"
  }
}

resource "aws_key_pair" "auth" {
  key_name   = "${var.key_name}-${random_id.hash.hex}"
  public_key = file(var.public_key_path)
}

resource "aws_instance" "zookeeper" {
  ami           = var.ami
  instance_type = var.instance_types["zookeeper"]
  key_name      = aws_key_pair.auth.id
  subnet_id     = aws_subnet.benchmark_subnet.id
  vpc_security_group_ids = [
  aws_security_group.benchmark_security_group.id]
  count = var.num_instances["zookeeper"]
  dynamic "instance_market_options" {
     for_each = var.spot ? [1] : []
     content {
         market_type = "spot"
         spot_options {
           max_price = 0.5
         }
       }
   }

  tags = {
    Name = "zk-${count.index}"
  }
}

resource "aws_instance" "bookie" {
  ami           = var.ami
  instance_type = var.instance_types["bookkeeper"]
  key_name      = aws_key_pair.auth.id
  subnet_id     = aws_subnet.benchmark_subnet.id
  vpc_security_group_ids = [
  aws_security_group.benchmark_security_group.id]
  count = var.num_instances["bookkeeper"]
  dynamic "instance_market_options" {
     for_each = var.spot ? [1] : []
     content {
         market_type = "spot"
         spot_options {
           max_price = 0.7
         }
     }
  }

  tags = {
    Name = "bookie-${count.index}"
  }
}

resource "aws_instance" "client" {
  ami           = var.ami
  instance_type = var.instance_types["client"]
  key_name      = aws_key_pair.auth.id
  subnet_id     = aws_subnet.benchmark_subnet.id
  vpc_security_group_ids = [
  aws_security_group.benchmark_security_group.id]
  count = var.num_instances["client"]
  dynamic "instance_market_options" {
     for_each = var.spot ? [1] : []
     content {
         market_type = "spot"
         spot_options {
           max_price = 1.0428
         }
     }
  }

  tags = {
    Name = "bookkeeper-client-${count.index}"
  }
}

# Inventory host resource.
resource "ansible_host" "zookeeper" {
  name = "zk-${count.index}"
  groups = ["zookeepers"] # Groups this host is part of.
  count = var.num_instances["zookeeper"]

  variables = {
    # Connection vars.
    ansible_user = "ubuntu" # Default user depends on the OS.
    ansible_host = aws_instance.zookeeper[count.index].public_ip

    # Custom vars that we might use in roles/tasks.
  }
}
resource "ansible_host" "bookie" {
  name = "bookie-${count.index}"
  groups = ["bookies"] # Groups this host is part of.
  count = var.num_instances["bookkeeper"]

  variables = {
    # Connection vars.
    ansible_user = "ubuntu" # Default user depends on the OS.
    ansible_host = aws_instance.bookie[count.index].public_ip

    # Custom vars that we might use in roles/tasks.
  }
}
resource "ansible_host" "client" {
  name = "client-${count.index}"
  groups = ["clients"] # Groups this host is part of.
  count = var.num_instances["client"]

  variables = {
    # Connection vars.
    ansible_user = "ubuntu" # Default user depends on the OS.
    ansible_host = aws_instance.client[count.index].public_ip

    # Custom vars that we might use in roles/tasks.
  }
}

output "zookeeper" {
  value = {
    for instance in aws_instance.zookeeper :
    instance.public_ip => instance.private_ip
  }
}

output "bookie" {
  value = {
    for instance in aws_instance.bookie :
    instance.public_ip => instance.private_ip
  }
}

output "client" {
  value = {
    for instance in aws_instance.client :
    instance.public_ip => instance.private_ip
  }
}

output "client_ssh_host" {
  value = aws_instance.client.0.public_ip
}
