terraform {
  cloud {
    organization = "test9248"

    workspaces {
      name = "Test-cursos-terraform"
    }
  }
}

# main.tf

provider "aws" {
  region = "eu-west-3"
}

# variable path clave ssh
variable "ssh_key_path" {}

# Recurso de clave SSH en AWS
resource "aws_key_pair" "deployer_Alumno11" {
 key_name = "deployer-key-Alumno11"
 public_key = file(var.ssh_key_path)
}


# variable del Id de la VPC
variable "vpc_id" {}
variable "availability_zone" {}

module "vpc" {
  source               = "terraform-aws-modules/vpc/aws"
  name                 = "vpc-main-alumno11"
  cidr                 = "10.11.0.0/16"
  azs                  = [var.availability_zone]
  private_subnets      = ["10.11.0.0/24", "10.11.1.0/24"]
  public_subnets       = ["10.11.100.0/24", "10.11.101.0/24"]
  enable_dns_hostnames = true
  enable_dns_support   = true
  enable_nat_gateway   = false
  enable_vpn_gateway   = false
  tags = {
    Terraform   = "true",
    Environment = "dev"
  }
}

resource "aws_security_group" "allow_ports_alumno11" {
  name        = "allow_ssh_http_https_alumno11"
  description = "Allow inbound SSH, HTTP and HTTPS traffic and http from any IP"
  vpc_id      = module.vpc.vpc_id

  #ssh access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    # Restrict ingress to necessary IPs/ports.
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    # Restrict ingress to necessary IPs/ports.
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    # Restrict ingress to necessary IPs/ports.
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

# RHEL 9
data "aws_ami" "rhel_9_alumno11" {
  most_recent = true
  owners = ["309956199498"] // Red Hat's Account ID
  filter {
    name   = "name"
    values = ["RHEL-9.0*"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


resource "aws_instance" "web_alumno11" {
  ami           = data.aws_ami.rhel_9_alumno11.id
  availability_zone = var.availability_zone
  instance_type = "t3.micro"
  key_name               = aws_key_pair.deployer_Alumno11.key_name
  user_data              = data.template_file.userdata_alumno11.rendered
  vpc_security_group_ids = [aws_security_group.allow_ports_alumno11.id]
  subnet_id              = element(module.vpc.public_subnets,1)
  tags = {
    Name = "HelloWorld_alumno11"
  }
}

data "template_file" "userdata_alumno11" {
  template = file("${path.module}/userdata_alumno11.sh")
}

#definición del recurso EBS
resource "aws_ebs_volume" "web_alumno11" {
  availability_zone = var.availability_zone
  size              = 4
  type = "gp3"
  encrypted =   true
  tags = {
    Name = "web-ebs-alumno11"
  }
}

resource "aws_volume_attachment" "web_alumno11" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.web_alumno11.id
  instance_id = aws_instance.web_alumno11.id
}

output "ami-rhel" {
  value = data.aws_ami.rhel_9_alumno11
}

output "ip_instance" {
  value = aws_instance.web_alumno11.public_ip
}

output "ssh" {
  value = "ssh -l ec2-user ~${aws_instance.web_alumno11.public_ip}"
}

