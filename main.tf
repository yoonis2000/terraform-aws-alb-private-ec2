#VPC
resource "aws_vpc" "prod_vpc" {
  cidr_block = "10.10.0.0/16"

  tags = {
    Name = "prod-style-vpc-updated"
  }
}

#Subnets
resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.prod_vpc.id
  cidr_block        = "10.10.1.0/24"
  availability_zone = "eu-west-2a"

  tags = {
    Name = "prod-public-a"
  }
}
resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.prod_vpc.id
  cidr_block        = "10.10.3.0/24"
  availability_zone = "eu-west-2b"

  tags = {
    Name = "prod-public-b"
  }
}
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.prod_vpc.id
  cidr_block        = "10.10.2.0/24"
  availability_zone = "eu-west-2a"

  tags = {
    Name = "prod-private-a"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.prod_vpc.id
  cidr_block        = "10.10.4.0/24"
  availability_zone = "eu-west-2b"

  tags = {
    Name = "prod-private-b"
  }
}

#Internet Access
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.prod_vpc.id

  tags = {
    Name = "prod-igw"
  }
}
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.prod_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "prod-public-rt"
  }
}
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public_rt.id
}
resource "aws_route_table_association" "public_assoc_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public_rt.id
}

# NAT Gateway (for private subnet outbound internet access)

resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "prod-nat-eip"
  }
}

resource "aws_nat_gateway" "nat_a" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_a.id

  tags = {
    Name = "prod-nat-a"
  }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.prod_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_a.id
  }

  tags = {
    Name = "prod-private-rt"
  }
}

resource "aws_route_table_association" "private_assoc_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_assoc_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private_rt.id
}

#Security Group
resource "aws_security_group" "alb_sg" {
  name        = "prod-alb-sg"
  description = "Allow HTTP traffic"
  vpc_id      = aws_vpc.prod_vpc.id

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
  vpc_id      = aws_vpc.prod_vpc.id

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

#Application Load Balancer
resource "aws_lb" "alb" {
  name               = "prod-alb"
  load_balancer_type = "application"
  subnets = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]
  security_groups = [aws_security_group.alb_sg.id]

  tags = {
    Name = "prod-alb"
  }
}

#Target Group
resource "aws_lb_target_group" "tg" {
  name     = "prod-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.prod_vpc.id

  health_check {
    path = "/"
    port = "traffic-port"
  }

  tags = {
    Name = "prod-tg"
  }
}

#Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
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
  vpc_zone_identifier = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  launch_template {
    id      = aws_launch_template.lt.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.tg.arn]

  health_check_type         = "ELB"
  health_check_grace_period = 120

  tag {
    key                 = "Name"
    value               = "prod-asg-instance"
    propagate_at_launch = true
  }
}