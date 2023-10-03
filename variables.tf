#---------
# main
#---------
variable "owner" {
  type        = list(string)
  description = "Owner ID of the AWS account. Used for accessing the proper custom AMIs, etc."
  default = [
    "666800276840",
  ]
}

variable "environment" {
  description = "The environment that these resources are for (lab, qa, prod, etc.)"
}

# network variables
variable "region" {
  description = "The AWS region that the VPC will be created in."
  default     = "ca-central-1"
}


#---------------------------
# security & firewall
#---------------------------
variable "ssh_keypair_name" {
  type        = string
  description = "Name of the SSH keypair to be used"
}

variable "allowed_ingress_cidr" {
  type        = list(string)
  description = "The list of CIDR blocks/IPs that will be allowed ingress.  Default to any IP, but can and should be locked down with VPN/company external IP"

  default = [
    "0.0.0.0/0",
  ]
}


#-----------
# consul 
#-----------
variable "consul_version" {}

variable "consul_dc" {
  description = "Name of Consul datacenter"
  type        = string
}

variable "consul_server_count" {
  description = "The number of Consul servers to provision"
  default     = 3

  validation {
    condition     = contains([1, 3, 5], var.consul_server_count)
    error_message = "The number of Consul servers should be 1, 3, or 5."
  }
}

variable "consul_gossip_key" {
  type        = string
  description = "Gossip encryption key.  This is used for all servers running Consul (server & agent)"
}

variable "consul_instance_type" {
  description = "The instance type to use for the Consul hosts. Use m5a.large or better for prod"
  default     = "t4g.medium"
}

#-----------
# nomad
#-----------
variable "nomad_version" {}


variable "nomad_dc" {
  description = "Name of Nomad datacenter"
  type        = string
}

variable "nomad_server_count" {
  description = "The number of Nomad servers to provision"
  default     = 3

  validation {
    condition     = contains([1, 3, 5], var.nomad_server_count)
    error_message = "The number of Nomad servers should be 1, 3, or 5."
  }
}

variable "nomad_gossip_key" {
  type        = string
  description = "Gossip encryption key.  This is used for all servers running Consul (server & agent)"
}

variable "nomad_instance_type" {
  description = "The instance type to use for the Nomad hosts. Use m5a.large or better for prod"
  default     = "t4g.medium"
}

variable "nomad_client_instance_type" {
  description = "The instance type to use for the Nomad clients. Use m5a.large or better for prod"
  default     = "t3a.medium"
}

variable "nomad_client_desired" {
  description = "The desired number of Nomad clients to provision"
  default     = 3
}

variable "nomad_client_min" {
  description = "The min number of Nomad clients to provision"
  default     = 1
}

variable "nomad_client_max" {
  description = "The max number of Nomad clients to provision"
  default     = 5
}
