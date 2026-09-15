# Em um ambiente de produção real, teria uma VPC dedicada, com sub-redes públicas/privadas separadas
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  # A VPC padrão dessa conta tem sub-rede em us-east-1e, mas o EKS não aceita
  # control plane nessa AZ nessa conta (UnsupportedAvailabilityZoneException).
  # Filtra só as AZs que a própria AWS listou como suportadas no erro.
  filter {
    name   = "availability-zone"
    values = ["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d", "us-east-1f"]
  }
}
