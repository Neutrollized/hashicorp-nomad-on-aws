locals {
  tags = tomap({
    "cloud" = "aws",
    "env"   = var.environment,
  })
}


###--------------------------------------------
# AMIs
#----------------------------------------------
data "aws_ami" "consul_server" {
  most_recent = true
  owners      = var.owner

  filter {
    name   = "name"
    values = ["consul-${var.consul_version}-arm64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_ami" "nomad_server" {
  most_recent = true
  owners      = var.owner

  filter {
    name   = "name"
    values = ["nomad-${var.nomad_version}-arm64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_ami" "nomad_client" {
  most_recent = true
  owners      = var.owner

  filter {
    name   = "name"
    values = ["nomad-${var.nomad_version}-amd64-client-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


###--------------------------------------------
# Consul
#----------------------------------------------
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template
resource "aws_launch_template" "consul_server" {
  name          = "consul-server-lt"
  image_id      = data.aws_ami.consul_server.id
  ebs_optimized = true
  instance_type = var.consul_instance_type

  key_name = var.ssh_keypair_name

  iam_instance_profile {
    name = aws_iam_instance_profile.auto_discover_cluster.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ssh.id, aws_security_group.consul.id]
  }

  tag_specifications {
    resource_type = "instance"

    tags = merge(
      local.tags,
      tomap({
        "Name" = "consul-${var.environment}-server",
        "role" = "consul-${var.environment}-server",
      })
    )
  }

  user_data = base64encode(
    <<EOF
#!/bin/bash
IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)

sed -i -e 's/{DATACENTER}/${var.consul_dc}/g' /etc/consul.d/server.hcl
sed -i -e 's/{SERVER_COUNT}/${var.consul_server_count}/g' /etc/consul.d/server.hcl
sed -i -e "s/{PRIVATE_IPV4}/$${IP}/g" /etc/consul.d/server.hcl

sed -i -e 's/{DATACENTER}/${var.consul_dc}/g' /etc/consul.d/consul.hcl
sed -i -e "s/{PRIVATE_IPV4}/$${IP}/g" /etc/consul.d/consul.hcl
sed -i -e 's/{GOSSIP_KEY}/${var.consul_gossip_key}/g' /etc/consul.d/consul.hcl
sed -i -e 's/{CONSUL_SERVER_TAG}/consul-${var.environment}-server/g' /etc/consul.d/consul.hcl

systemctl enable consul

systemctl start consul
EOF
  )

}


# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group
resource "aws_autoscaling_group" "consul_server" {
  name               = "consul-${var.environment}-server"
  availability_zones = data.aws_availability_zones.default.names

  desired_capacity = var.consul_server_count
  min_size         = var.consul_server_count
  max_size         = var.consul_server_count

  launch_template {
    id = aws_launch_template.consul_server.id
  }
}


#----------------------
# Consul LB
#----------------------
resource "aws_lb" "consul_server" {
  name                       = "consul-server-${var.environment}-l7"
  internal                   = false
  subnets                    = data.aws_subnets.default.ids
  security_groups            = [aws_security_group.web.id]
  enable_deletion_protection = false
  ip_address_type            = "ipv4"

  tags = local.tags
}

resource "aws_lb_listener" "consul_server_http" {
  load_balancer_arn = aws_lb.consul_server.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.consul_server.arn
    type             = "forward"
  }
}

resource "aws_lb_target_group" "consul_server" {
  name     = "consul-server-${var.environment}-lb-targets"
  port     = "8500"
  protocol = "HTTP"
  vpc_id   = aws_default_vpc.default.id

  health_check {
    interval            = 20
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = "5"
    healthy_threshold   = "5"
    unhealthy_threshold = "2"
    matcher             = "200,301"
  }

  tags = local.tags
}

resource "aws_autoscaling_attachment" "consul_server" {
  autoscaling_group_name = aws_autoscaling_group.consul_server.id
  lb_target_group_arn    = aws_lb_target_group.consul_server.arn
}


###--------------------------------------------
# Nomad
#----------------------------------------------
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template
resource "aws_launch_template" "nomad_server" {
  name          = "nomad-server-lt"
  image_id      = data.aws_ami.nomad_server.id
  ebs_optimized = true
  instance_type = var.nomad_instance_type

  key_name = var.ssh_keypair_name

  iam_instance_profile {
    name = aws_iam_instance_profile.auto_discover_cluster.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ssh.id, aws_security_group.consul.id, aws_security_group.nomad.id]
  }

  tag_specifications {
    resource_type = "instance"

    tags = merge(
      local.tags,
      tomap({
        "Name" = "nomad-${var.environment}-server",
        "role" = "nomad-${var.environment}-server",
      })
    )
  }

  user_data = base64encode(
    <<EOF
#!/bin/bash
IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)

sed -i -e 's/{DATACENTER}/${var.consul_dc}/g' /etc/consul.d/consul.hcl
sed -i -e "s/{PRIVATE_IPV4}/$${IP}/g" /etc/consul.d/consul.hcl
sed -i -e 's/{GOSSIP_KEY}/${var.consul_gossip_key}/g' /etc/consul.d/consul.hcl
sed -i -e 's/{CONSUL_SERVER_TAG}/consul-${var.environment}-server/g' /etc/consul.d/consul.hcl

sed -i -e 's/{DATACENTER}/${var.nomad_dc}/g' /etc/nomad.d/server.hcl
sed -i -e 's/{REGION}/${var.region}/g' /etc/nomad.d/server.hcl
sed -i -e "s/{PRIVATE_IPV4}/$${IP}/g" /etc/nomad.d/server.hcl
sed -i -e 's/{SERVER_COUNT}/${var.nomad_server_count}/g' /etc/nomad.d/server.hcl
sed -i -e 's/{GOSSIP_KEY}/${var.nomad_gossip_key}/g' /etc/nomad.d/server.hcl

systemctl enable consul
systemctl enable nomad

systemctl start consul
systemctl start nomad
EOF
  )

  depends_on = [
    aws_autoscaling_group.consul_server
  ]
}


# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group
resource "aws_autoscaling_group" "nomad_server" {
  name               = "nomad-${var.environment}-server"
  availability_zones = data.aws_availability_zones.default.names

  desired_capacity = var.nomad_server_count
  min_size         = var.nomad_server_count
  max_size         = var.nomad_server_count

  launch_template {
    id = aws_launch_template.nomad_server.id
  }
}


#----------------------
# Nomad LB
#----------------------
resource "aws_lb" "nomad_server" {
  name                       = "nomad-server-${var.environment}-l7"
  internal                   = false
  subnets                    = data.aws_subnets.default.ids
  security_groups            = [aws_security_group.web.id]
  enable_deletion_protection = false
  ip_address_type            = "ipv4"

  tags = local.tags
}

resource "aws_lb_listener" "nomad_server_http" {
  load_balancer_arn = aws_lb.nomad_server.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.nomad_server.arn
    type             = "forward"
  }
}

resource "aws_lb_listener" "nomad_server_https" {
  load_balancer_arn = aws_lb.nomad_server.arn
  port              = "443"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.nomad_server.arn
    type             = "forward"
  }
}

resource "aws_lb_target_group" "nomad_server" {
  name     = "nomad-server-${var.environment}-lb-targets"
  port     = "4646"
  protocol = "HTTP"
  vpc_id   = aws_default_vpc.default.id

  health_check {
    interval            = 20
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = "5"
    healthy_threshold   = "5"
    unhealthy_threshold = "2"
    matcher             = "200,301"
  }

  tags = local.tags
}

resource "aws_autoscaling_attachment" "nomad_server" {
  autoscaling_group_name = aws_autoscaling_group.nomad_server.id
  lb_target_group_arn    = aws_lb_target_group.nomad_server.arn
}


###--------------------------------------------
# Nomad Client
#----------------------------------------------
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template
resource "aws_launch_template" "nomad_client" {
  name          = "nomad-client-lt"
  image_id      = data.aws_ami.nomad_client.id
  ebs_optimized = true
  instance_type = var.nomad_client_instance_type

  key_name = var.ssh_keypair_name

  iam_instance_profile {
    name = aws_iam_instance_profile.auto_discover_cluster.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ssh.id, aws_security_group.consul.id, aws_security_group.nomad.id, aws_security_group.nomad_client.id]
  }

  tag_specifications {
    resource_type = "instance"

    tags = merge(
      local.tags,
      tomap({
        "Name" = "nomad-${var.environment}-client",
        "role" = "nomad-${var.environment}-client",
      })
    )
  }

  user_data = base64encode(
    <<EOF
#!/bin/bash
IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)

sed -i -e 's/{DATACENTER}/${var.consul_dc}/g' /etc/consul.d/consul.hcl
sed -i -e "s/{PRIVATE_IPV4}/$${IP}/g" /etc/consul.d/consul.hcl
sed -i -e 's/{GOSSIP_KEY}/${var.consul_gossip_key}/g' /etc/consul.d/consul.hcl
sed -i -e 's/{CONSUL_SERVER_TAG}/consul-${var.environment}-server/g' /etc/consul.d/consul.hcl

sed -i -e 's/{DATACENTER}/${var.nomad_dc}/g' /etc/nomad.d/client.hcl
sed -i -e 's/{REGION}/${var.region}/g' /etc/nomad.d/client.hcl
sed -i -e "s/{PRIVATE_IPV4}/$${IP}/g" /etc/nomad.d/client.hcl

systemctl enable consul
systemctl enable nomad

systemctl start consul
systemctl start nomad
EOF
  )

  depends_on = [
    aws_autoscaling_group.nomad_server
  ]
}


# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group
resource "aws_autoscaling_group" "nomad_client" {
  name               = "nomad-${var.environment}-client"
  availability_zones = data.aws_availability_zones.default.names

  desired_capacity = var.nomad_client_desired
  min_size         = var.nomad_client_min
  max_size         = var.nomad_client_max

  launch_template {
    id = aws_launch_template.nomad_client.id
  }
}
