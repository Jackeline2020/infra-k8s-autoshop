# Em um ambiente de produção real, teria uma VPC dedicada, com sub-redes públicas/privadas separadas
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}
