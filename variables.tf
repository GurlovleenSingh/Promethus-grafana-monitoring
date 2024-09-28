variable "region" {
  description = "AWS region to deploy EKS cluster"
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "The name of the EKS cluster"
  default     = "my-eks-cluster"
}

variable "desired_capacity" {
  description = "The desired number of worker nodes"
  default     = 2
}

variable "max_capacity" {
  description = "The maximum number of worker nodes"
  default     = 3
}

variable "min_capacity" {
  description = "The minimum number of worker nodes"
  default     = 1
}

variable "instance_type" {
  description = "EC2 instance type for the worker nodes"
  default     = "t3.medium"
}

variable "key_name" {
  description = "Name of the SSH key pair for accessing worker nodes"
  default     = "my-eks-key"
}
