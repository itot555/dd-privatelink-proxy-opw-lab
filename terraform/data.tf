data "aws_caller_identity" "current" {
  provider = aws.us_east_1
}

data "aws_availability_zones" "us_east_1" {
  provider = aws.us_east_1
  state    = "available"
}

data "aws_availability_zones" "ap_northeast_1" {
  provider = aws.ap_northeast_1
  state    = "available"
}

data "aws_ami" "ubuntu_us_east_1" {
  provider    = aws.us_east_1
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
