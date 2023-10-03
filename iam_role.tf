data "aws_iam_policy_document" "auto_discovery_cluster_assume_role_policy_doc" {
  statement {
    effect = "Allow"

    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# https://www.consul.io/docs/agent/cloud-auto-join#amazon-ec2
data "aws_iam_policy_document" "auto_discover_cluster_policy_doc" {
  statement {
    effect = "Allow"

    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeTags",
      "autoscaling:DescribeAutoScalingGroups",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role" "auto_discover_cluster" {
  name               = "auto-discover-cluster"
  assume_role_policy = data.aws_iam_policy_document.auto_discovery_cluster_assume_role_policy_doc.json
}

# instance role profile to be assigned to EC2 instances
resource "aws_iam_instance_profile" "auto_discover_cluster" {
  name = "auto_discover_cluster"
  role = aws_iam_role.auto_discover_cluster.id
}

resource "aws_iam_role_policy" "auto_discover_cluster" {
  name   = "auto-discover-cluster"
  role   = aws_iam_role.auto_discover_cluster.name
  policy = data.aws_iam_policy_document.auto_discover_cluster_policy_doc.json
}
