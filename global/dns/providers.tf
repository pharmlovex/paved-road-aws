provider "aws" {
  region = "eu-west-2"

  default_tags {
    tags = {
      Project     = "paved-road-aws"
      Environment = "global"
      Stack       = "global/dns"
      ManagedBy   = "opentofu"
    }
  }
}