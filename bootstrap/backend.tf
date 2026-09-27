terraform {
  backend "s3" {
    bucket       = "paved-road-tfstate-311419364249"
    key          = "bootstrap/terraform.tfstate"
    region       = "eu-west-2"
    use_lockfile = true
    encrypt      = true
  }
}