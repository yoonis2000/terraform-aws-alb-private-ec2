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

module "compute" {
  source = "./modules/compute"

  private_subnet_ids = module.vpc.private_subnet_ids
  ec2_sg_id          = aws_security_group.ec2_sg.id
  target_group_arns  = [module.alb.target_group_arn]
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

