terraform {
  backend "s3" {
    bucket         = "abdiy-tfstate-eu-west-2-001"
    key            = "prod-alb-private-ec2/terraform.tfstate"
    region         = "eu-west-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}