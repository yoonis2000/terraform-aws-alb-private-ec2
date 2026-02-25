# VPC moves
moved {
  from = aws_vpc.prod_vpc
  to   = module.vpc.aws_vpc.prod_vpc
}

moved {
  from = aws_subnet.public_a
  to   = module.vpc.aws_subnet.public_a
}

moved {
  from = aws_subnet.public_b
  to   = module.vpc.aws_subnet.public_b
}

moved {
  from = aws_subnet.private_a
  to   = module.vpc.aws_subnet.private_a
}

moved {
  from = aws_subnet.private_b
  to   = module.vpc.aws_subnet.private_b
}

moved {
  from = aws_internet_gateway.igw
  to   = module.vpc.aws_internet_gateway.igw
}

moved {
  from = aws_eip.nat_eip
  to   = module.vpc.aws_eip.nat_eip
}

moved {
  from = aws_nat_gateway.nat_a
  to   = module.vpc.aws_nat_gateway.nat_a
}

moved {
  from = aws_route_table.public_rt
  to   = module.vpc.aws_route_table.public_rt
}

moved {
  from = aws_route_table.private_rt
  to   = module.vpc.aws_route_table.private_rt
}

moved {
  from = aws_route_table_association.public_assoc
  to   = module.vpc.aws_route_table_association.public_assoc
}

moved {
  from = aws_route_table_association.public_assoc_b
  to   = module.vpc.aws_route_table_association.public_assoc_b
}

moved {
  from = aws_route_table_association.private_assoc_a
  to   = module.vpc.aws_route_table_association.private_assoc_a
}

moved {
  from = aws_route_table_association.private_assoc_b
  to   = module.vpc.aws_route_table_association.private_assoc_b
}

# ALB moves
moved {
  from = aws_lb.alb
  to   = module.alb.aws_lb.this
}

moved {
  from = aws_lb_target_group.tg
  to   = module.alb.aws_lb_target_group.this
}

moved {
  from = aws_lb_listener.http
  to   = module.alb.aws_lb_listener.http
}

# Compute moves
moved {
  from = aws_iam_role.ec2_role
  to   = module.compute.aws_iam_role.ec2_role
}

moved {
  from = aws_iam_role_policy_attachment.ssm_core
  to   = module.compute.aws_iam_role_policy_attachment.ssm_core
}

moved {
  from = aws_iam_instance_profile.ec2_profile
  to   = module.compute.aws_iam_instance_profile.ec2_profile
}

moved {
  from = aws_launch_template.lt
  to   = module.compute.aws_launch_template.lt
}

moved {
  from = aws_autoscaling_group.asg
  to   = module.compute.aws_autoscaling_group.asg
}

moved {
  from = random_id.suffix
  to   = module.compute.random_id.suffix
}