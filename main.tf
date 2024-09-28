provider "aws" {
  region = "us-east-1"  # Define your AWS region
}

# Create a VPC
resource "aws_vpc" "eks_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "eks-vpc"
  }
}

# Create Public Subnets
resource "aws_subnet" "public_subnet_1" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "eks-public-subnet-1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "eks-public-subnet-2"
  }
}

# Create Private Subnets
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "eks-private-subnet-1"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "eks-private-subnet-2"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.eks_vpc.id

  tags = {
    Name = "eks-igw"
  }
}

# Create Route Table for Public Subnets
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "eks-public-rt"
  }
}

# Associate Route Table with Public Subnets
resource "aws_route_table_association" "public_subnet_1_assoc" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_subnet_2_assoc" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

# EKS Cluster Role (IAM Role for EKS to manage resources)
resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
}

# Attach necessary policies to EKS Cluster Role
resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSVPCResourceControllerPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster_role.name
}

# EKS Cluster
resource "aws_eks_cluster" "eks_cluster" {
  name     = "my-eks-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.25"

  vpc_config {
    subnet_ids = [
      aws_subnet.private_subnet_1.id,
      aws_subnet.private_subnet_2.id
    ]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.eks_cluster_AmazonEKSVPCResourceControllerPolicy
  ]

  tags = {
    Name = "my-eks-cluster"
  }
}

# EKS Worker Node Role (IAM Role for EC2 instances to join the EKS cluster)
resource "aws_iam_role" "eks_node_role" {
  name = "eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# Attach necessary policies to Worker Node Role
resource "aws_iam_role_policy_attachment" "eks_node_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_node_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_node_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

# EKS Worker Nodes (Auto Scaling Group for EC2 instances)
resource "aws_launch_template" "eks_node_group_lt" {
  name_prefix   = "eks-node-group"
  image_id      = data.aws_ami.eks_ami.id  # Using EKS-optimized AMI
  instance_type = "t3.medium"
#   key_name      = "my-eks-key"  # Define your SSH key pair here

  iam_instance_profile {
    name = aws_iam_instance_profile.eks_node_instance_profile.name
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "eks-node"
    }
  }
}

data "aws_ami" "eks_ami" {
  most_recent = true
  owners      = ["602401143452"]  # Amazon EKS AMI

  filter {
    name   = "name"
    values = ["*amazon-eks-node-*"]
  }
}

resource "aws_iam_instance_profile" "eks_node_instance_profile" {
  name = "eks-node-instance-profile"
  role = aws_iam_role.eks_node_role.name
}

# Auto Scaling Group
resource "aws_autoscaling_group" "eks_node_asg" {
  desired_capacity     = 10
  max_size             = 12
  min_size             = 1
  launch_template {
    id      = aws_launch_template.eks_node_group_lt.id
    version = "$Latest"
  }
  vpc_zone_identifier = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
}


# Install Helm and Prometheus in EKS
resource "null_resource" "install_prometheus" {
  depends_on = [aws_eks_cluster.eks_cluster]

  provisioner "local-exec" {
    command = <<EOT
      # Set up Kubeconfig
      aws eks update-kubeconfig --region us-east-1 --name my-eks-cluster

      # Install Helm if it's not already installed
      if ! command -v helm &> /dev/null; then
        curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
      fi

      # Add Prometheus Helm repository
      helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

      # Install Prometheus
      helm install prometheus prometheus-community/prometheus --namespace monitoring --create-namespace
    EOT
  }
}

# Install Grafana in EKS
resource "null_resource" "install_grafana" {
  depends_on = [null_resource.install_prometheus]

  provisioner "local-exec" {
    command = <<EOT
      # Set up Kubeconfig
      aws eks update-kubeconfig --region us-east-1 --name my-eks-cluster

      # Add Grafana Helm repository
      helm repo add grafana https://grafana.github.io/helm-charts

      # Install Grafana
      helm install grafana grafana/grafana --namespace monitoring
    EOT
  }
}
