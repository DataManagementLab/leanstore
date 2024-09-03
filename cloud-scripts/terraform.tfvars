# terraform.tfvars

public_key_path = "benchmark_key.pub" # create ssh key to be used
region          = "us-west-2"
az              = "us-west-2a"
ami             = "ami-01f519a731dd64ba7"  # us-west-2	Jammy Jellyfish	22.04 LTS

instance_types = {
  "bookkeeper" = "i3.4xlarge"
  "zookeeper"  = "t2.small"
  "client"     = "c4.large"
}

num_instances = {
  "bookkeeper" = 3
  "zookeeper"  = 3
  "client"     = 1
}
