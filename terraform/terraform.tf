terraform {
  required_version = "~> 1.10"

  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.8"
    }

    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.56"
    }

    datadog = {
      source  = "DataDog/datadog"
      version = "~> 4.16"
    }

    local = {
      source  = "hashicorp/local"
      version = "~> 2.9"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.9"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.3"
    }
  }
}
