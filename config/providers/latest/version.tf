terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    local = {
      source = "hashicorp/local"
    }
    azuread = {
      source = "hashicorp/azuread"
    }
    vault = {
      source = "hashicorp/vault"
    }
    http = {
      source = "hashicorp/http"
    }
    tls = {
      source = "hashicorp/tls"
    }
    null = {
      source = "hashicorp/null"
    }
    gitlab = {
      source = "gitlabhq/gitlab"
    }

    ldap = {
      source = "l-with/ldap"
    }
  }
}
