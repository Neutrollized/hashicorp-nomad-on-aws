###------------------------------
# VPC, Subnets & AZs
#--------------------------------
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_vpc
resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [aws_default_vpc.default.id]
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones.html
data "aws_availability_zones" "default" {
  state         = "available"
  exclude_names = ["ca-central-1d"]
}


###------------------------------
# SSH Firewall/SG
#--------------------------------
# security groups is a group of rules
resource "aws_security_group" "ssh" {
  name        = "Client SSH Access"
  vpc_id      = aws_default_vpc.default.id
  description = "SSH access"

  tags = merge(
    local.tags,
    tomap({
      "Name" = "Server SSH access",
    })
  )
}

# security group rules are rules in the group
resource "aws_security_group_rule" "allow_ssh" {
  type              = "ingress"
  description       = "SSH"
  security_group_id = aws_security_group.ssh.id
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "ssh_self" {
  type              = "ingress"
  description       = "SSH"
  security_group_id = aws_security_group.ssh.id
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  self              = "true"
}

resource "aws_security_group_rule" "internet" {
  type              = "egress"
  description       = "Internet access"
  security_group_id = aws_security_group.ssh.id
  from_port         = 0
  to_port           = 0
  protocol          = "all"
  cidr_blocks       = ["0.0.0.0/0"]
}


###------------------------------
# HTTP/HTTPS Firewall/SG
#--------------------------------
# security groups is a group of rules
resource "aws_security_group" "web" {
  name        = "Server ALB Access"
  vpc_id      = aws_default_vpc.default.id
  description = "Web access"

  tags = merge(
    local.tags,
    tomap({
      "Name" = "HTTP/HTTPS access",
    })
  )
}

# security group rules are rules in the group
resource "aws_security_group_rule" "allow_http" {
  type              = "ingress"
  description       = "HTTP"
  security_group_id = aws_security_group.web.id
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = var.allowed_ingress_cidr
}

resource "aws_security_group_rule" "allow_https" {
  type              = "ingress"
  description       = "HTTPS"
  security_group_id = aws_security_group.web.id
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.allowed_ingress_cidr
}

resource "aws_security_group_rule" "http_self" {
  type              = "ingress"
  description       = "HTTP"
  security_group_id = aws_security_group.web.id
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  self              = "true"
}

resource "aws_security_group_rule" "https_self" {
  type              = "ingress"
  description       = "HTTPS"
  security_group_id = aws_security_group.web.id
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  self              = "true"
}

resource "aws_security_group_rule" "egress_web" {
  type              = "egress"
  description       = "Internet access"
  security_group_id = aws_security_group.web.id
  from_port         = 0
  to_port           = 0
  protocol          = "all"
  cidr_blocks       = ["0.0.0.0/0"]
}


###------------------------------
# Consul Firewall/SG
# https://www.consul.io/docs/install/ports.html
#--------------------------------
resource "aws_security_group" "consul" {
  name        = "Consul server required ports"
  vpc_id      = aws_default_vpc.default.id
  description = "Security group for HashiCorp Consul"

  tags = merge(
    local.tags,
    tomap({
      "Name" = "Consul required ports",
    })
  )
}

resource "aws_security_group_rule" "consul_dns_tcp" {
  type              = "ingress"
  description       = "Consul DNS"
  security_group_id = aws_security_group.consul.id
  from_port         = 8600
  to_port           = 8600
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "consul_dns_udp" {
  type              = "ingress"
  description       = "Consul DNS"
  security_group_id = aws_security_group.consul.id
  from_port         = 8600
  to_port           = 8600
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "consul_http" {
  type              = "ingress"
  description       = "Consul Web UI"
  security_group_id = aws_security_group.consul.id
  from_port         = 8500
  to_port           = 8500
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "consul_lanserf_tcp" {
  type              = "ingress"
  description       = "Consul LAN Serf"
  security_group_id = aws_security_group.consul.id
  from_port         = 8301
  to_port           = 8301
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "consul_lanserf_udp" {
  type              = "ingress"
  description       = "Consul LAN Serf"
  security_group_id = aws_security_group.consul.id
  from_port         = 8301
  to_port           = 8301
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "consul_wanserf_tcp" {
  type              = "ingress"
  description       = "Consul Wan Serf"
  security_group_id = aws_security_group.consul.id
  from_port         = 8302
  to_port           = 8302
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "consul_wanserf_udp" {
  type              = "ingress"
  description       = "Consul Wan Serf"
  security_group_id = aws_security_group.consul.id
  from_port         = 8302
  to_port           = 8302
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "consul_rpc" {
  type              = "ingress"
  description       = "Consul RPC"
  security_group_id = aws_security_group.consul.id
  from_port         = 8300
  to_port           = 8300
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "consul_sidecar_proxy" {
  type              = "ingress"
  description       = "Consul Sidecar Proxy"
  security_group_id = aws_security_group.consul.id
  from_port         = 21000
  to_port           = 21255
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}


###------------------------------
# Nomad Firewall/SG
# https://nomadproject.io/guides/install/production/requirements/#ports-used
#--------------------------------
resource "aws_security_group" "nomad" {
  name        = "Nomad server required ports"
  vpc_id      = aws_default_vpc.default.id
  description = "Security group for HashiCorp Nomad"

  tags = merge(
    local.tags,
    tomap({
      "Name" = "Nomad required ports",
    })
  )
}

resource "aws_security_group_rule" "nomad_http" {
  type              = "ingress"
  description       = "Nomad Web UI"
  security_group_id = aws_security_group.nomad.id
  from_port         = 4646
  to_port           = 4646
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "nomad_wanserf_tcp" {
  type              = "ingress"
  description       = "Nomad Wan Serf"
  security_group_id = aws_security_group.nomad.id
  from_port         = 4648
  to_port           = 4648
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "nomad_wanserf_udp" {
  type              = "ingress"
  description       = "Nomad Wan Serf"
  security_group_id = aws_security_group.nomad.id
  from_port         = 4648
  to_port           = 4648
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "nomad_rpc" {
  type              = "ingress"
  description       = "Nomad RPC"
  security_group_id = aws_security_group.nomad.id
  from_port         = 4647
  to_port           = 4647
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}


###------------------------------
# Nomad Clients Firewall/SG
#--------------------------------
resource "aws_security_group" "nomad_client" {
  name        = "Nomad client required ports"
  vpc_id      = aws_default_vpc.default.id
  description = "Security group for HashiCorp Nomad"

  tags = merge(
    local.tags,
    tomap({
      "Name" = "Nomad client required ports",
    })
  )
}

resource "aws_security_group_rule" "nomad_job" {
  type              = "ingress"
  description       = "Nomad Jobs"
  security_group_id = aws_security_group.nomad_client.id
  from_port         = 20000
  to_port           = 32000
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "fabio_ui" {
  type              = "ingress"
  description       = "Fabio UI"
  security_group_id = aws_security_group.nomad_client.id
  from_port         = 9998
  to_port           = 9998
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "fabio_lb" {
  type              = "ingress"
  description       = "Fabio LB"
  security_group_id = aws_security_group.nomad_client.id
  from_port         = 9999
  to_port           = 9999
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}
