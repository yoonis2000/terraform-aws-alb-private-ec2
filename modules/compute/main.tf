#IAM
resource "aws_iam_role" "ec2_role" {
  name = "prod-ec2-role-${random_id.suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "prod-ec2-profile-${random_id.suffix.hex}"
  role = aws_iam_role.ec2_role.name
}

resource "random_id" "suffix" {
  byte_length = 3
}

#User Data Script
locals {
  user_data = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y nginx
    systemctl enable nginx
    systemctl start nginx

    # Fetch instance-id using IMDSv2 (token required)
    TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
    INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id)

    cat > /usr/share/nginx/html/index.html <<HTML
    <h1>Hello from private EC2</h1>
    <p>Instance ID: $INSTANCE_ID</p>
    HTML
  EOF
}

#Launch Template
resource "aws_launch_template" "lt" {
  name_prefix   = "prod-lt-"
  image_id      = data.aws_ami.al2023.id
  instance_type = "t2.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  vpc_security_group_ids = [var.ec2_sg_id]

  user_data = base64encode(local.user_data)

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "prod-private-ec2"
    }
  }
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

#ASG
resource "aws_autoscaling_group" "asg" {
  name                = "prod-asg"
  desired_capacity    = 2
  min_size            = 2
  max_size            = 3
  vpc_zone_identifier = var.private_subnet_ids

  launch_template {
    id      = aws_launch_template.lt.id
    version = "$Latest"
  }

  target_group_arns = [var.target_group_arns[0]]

  health_check_type         = "ELB"
  health_check_grace_period = 120

  tag {
    key                 = "Name"
    value               = "prod-asg-instance"
    propagate_at_launch = true
  }
}