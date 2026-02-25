module "vpc" {
  source = "./modules/vpc"

  name           = "prod"
  vpc_cidr       = "10.10.0.0/16"
  az_a           = "eu-west-2a"
  az_b           = "eu-west-2b"
  public_a_cidr  = "10.10.1.0/24"
  public_b_cidr  = "10.10.3.0/24"
  private_a_cidr = "10.10.2.0/24"
  private_b_cidr = "10.10.4.0/24"
}

module "alb" {
  source = "./modules/alb"

  name              = "prod"
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  alb_sg_id         = aws_security_group.alb_sg.id

  target_port       = 80
  health_check_path = "/"
}

#Security Group
resource "aws_security_group" "alb_sg" {
  name        = "prod-alb-sg"
  description = "Allow HTTP traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "prod-alb-sg"
  }
}

resource "aws_security_group" "ec2_sg" {
  name        = "prod-ec2-sg"
  description = "Allow HTTP only from ALB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "prod-ec2-sg"
  }
}

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

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

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
  vpc_zone_identifier = module.vpc.private_subnet_ids

  launch_template {
    id      = aws_launch_template.lt.id
    version = "$Latest"
  }

  target_group_arns = [module.alb.target_group_arn]

  health_check_type         = "ELB"
  health_check_grace_period = 120

  tag {
    key                 = "Name"
    value               = "prod-asg-instance"
    propagate_at_launch = true
  }
}