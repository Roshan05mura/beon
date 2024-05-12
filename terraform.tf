terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# provider "aws" {
#   region     = "us-west-2"
#   access_key = ""
#   secret_key = ""
# }

provider "aws" {
  region                  = "us-east-1"
  shared_config_files      = ["C:\\Users\\rmural147\\.aws\\config"]
  shared_credentials_files = ["C:\\Users\\rmural147\\.aws\\credentials"]
}

resource "aws_vpc" "tenant0" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "tenant0"
  }
}

resource "aws_vpc" "tenant1" {
  cidr_block = "10.1.0.0/16"
  tags = {
    Name = "tenant1"
  }
}

resource "aws_vpc" "tenant2" {
  cidr_block = "10.2.0.0/16"
  tags = {
    Name = "tenant2"
  }
}

resource "aws_vpn_gateway" "tenant0" {
  vpc_id = aws_vpc.tenant0.id
}

resource "aws_vpc_peering_connection" "tenant0-1" {
  peer_vpc_id = aws_vpc.tenant1.id
  vpc_id      = aws_vpc.tenant0.id
  auto_accept = true
}

resource "aws_vpc_peering_connection" "tenant0-2" {
  peer_vpc_id = aws_vpc.tenant2.id
  vpc_id      = aws_vpc.tenant0.id
  auto_accept = true
}

resource "aws_route" "tenant0-1" {
  route_table_id         = aws_vpc.tenant0.main_route_table_id
  destination_cidr_block = aws_vpc.tenant1.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.tenant0-1.id
}

resource "aws_route" "tenant0-2" {
  route_table_id         = aws_vpc.tenant0.main_route_table_id
  destination_cidr_block = aws_vpc.tenant2.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.tenant0-2.id
}

resource "aws_subnet" "tenant0" {
  vpc_id     = aws_vpc.tenant0.id
  cidr_block = "10.0.1.0/24"
}

resource "aws_subnet" "tenant1" {
  vpc_id     = aws_vpc.tenant1.id
  cidr_block = "10.1.1.0/24"
}

resource "aws_subnet" "tenant2" {
  vpc_id     = aws_vpc.tenant2.id
  cidr_block = "10.2.1.0/24"
}

resource "aws_security_group" "allow_tenant0" {
  name        = "allow_tenant0"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.tenant0.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_security_group" "allow_tenant1" {
  name        = "allow_tenant1"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.tenant1.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "allow_tenant2" {
  name        = "allow_tenant2"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.tenant2.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "tenant0" {
  ami                    = "ami-04b70fa74e45c3917" 
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.tenant0.id
  vpc_security_group_ids = [aws_security_group.allow_tenant0.id]
  key_name      = "demo"
}

resource "aws_instance" "tenant1" {
  ami           = "ami-04b70fa74e45c3917" 			
  instance_type = "t2.micro"
  key_name      = "demo"
  subnet_id     = aws_subnet.tenant1.id
  vpc_security_group_ids = [aws_security_group.allow_tenant1.id]
}

resource "aws_instance" "tenant2" {
  ami           = "ami-04b70fa74e45c3917" 			
  instance_type = "t2.micro"
  key_name      = "demo"
  subnet_id     = aws_subnet.tenant2.id
  vpc_security_group_ids = [aws_security_group.allow_tenant2.id]
}


#data "aws_ami" "eks_worker" {
#  filter {
#    name   = "name"
#    values = ["amazon-eks-node-1.21-v*"]
#  }
#
#  most_recent = true
#  owners      = ["602401143452"]
#}

resource "aws_iam_role" "cluster" {
  name = "my-cluster-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "cluster_ro" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
}

resource "aws_iam_role" "node" {
  name = "my-node-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "node" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}


resource "aws_eks_cluster" "cluster" {
  name     = "my-cluster"
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids = [aws_subnet.tenant2.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster,
    aws_iam_role_policy_attachment.cluster_ro,
  ]
}

resource "aws_eks_node_group" "node_group" {
  cluster_name    = aws_eks_cluster.cluster.name
  node_group_name = "my-node-group"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = [aws_subnet.tenant2.id]

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  instance_types = ["t3.medium"]

  remote_access {
    ec2_ssh_key = "demo"
    source_security_group_ids = [aws_security_group.allow_tenant2.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.node,
  ]
}



output "tenant0_instance_private_ip" {
  value = aws_instance.tenant0.private_ip
}

output "tenant1_instance_private_ip" {
  value = aws_instance.tenant1.private_ip
}

output "tenant2_instance_private_ip" {
  value = aws_instance.tenant2.private_ip
}

#output "tenant0_security_group0" {
#  value = aws_security_group.allow_tenant0
#}
#output "tenant0_security_group1" {
#  value = aws_security_group.allow_tenant1
#}
#output "tenant0_security_group2" {
#  value = aws_security_group.allow_tenant2
#}
