provider "aws" {
  region = "eu-west-2"

  default_tags {
    tags = {
      Project     = "paved-road"
      ManagedBy   = "opentofu"
      Stack       = "envs/dev"
      Environment = "dev"
    }
  }
}