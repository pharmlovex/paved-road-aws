provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "paved-road"
      ManagedBy = "opentofu"
      Stack     = "bootstrap"
    }
  }
}