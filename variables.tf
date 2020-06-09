variable "name" {
  default = "Demo.com"
}

variable "env" {
  default = "production"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "region" {
  default = "eu-central-1"
}

variable "azs" {
  default = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  type    = list(string)
}





