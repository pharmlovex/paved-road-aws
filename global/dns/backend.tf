terraform {
  backend "s3" {
    bucket       = "paved-road-tfstate-311419364249"
    key          = "global/dns/terraform.tfstate"
    region       = "eu-west-2"
    use_lockfile = true
    encrypt      = true
  }

  encryption {
    key_provider "aws_kms" "state" {
      kms_key_id = "alias/paved-road-tfstate"
      region     = "eu-west-2"
      key_spec   = "AES_256"
    }

    method "aes_gcm" "state" {
      keys = key_provider.aws_kms.state
    }

    state {
      method   = method.aes_gcm.state
      enforced = true
    }

    plan {
      method   = method.aes_gcm.state
      enforced = true
    }
  }
}