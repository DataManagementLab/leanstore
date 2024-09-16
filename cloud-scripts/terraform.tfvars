public_key_path = "benchmark_key.pub"
region          = "us-west-2"
az              = "us-west-2a"
ami             = "ami-01f519a731dd64ba7" # us-west-2	Jammy Jellyfish	22.04 LTS
spot            = true

instance_types = {
  "bookkeeper" = "c3.large"
  "zookeeper"  = "c3.large"
  "client"     = "t2.medium"
}

num_instances = {
  "client"     = 1
  "bookkeeper" = 3
  "zookeeper"  = 3
}
