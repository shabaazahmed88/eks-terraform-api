variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "cluster_name" {
  type    = string
  default = "imago-c3"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "node_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 4
}

variable "node_desired_size" {
  type    = number
  default = 2
}

# App specifics
variable "k8s_namespace" {
  type    = string
  default = "imago-api"
}

variable "app_name" {
  type    = string
  default = "imago-api"
}

variable "image_uri" {
  type = string # e.g. 123.dkr.ecr.eu-central-1.amazonaws.com/imago-api:v1
}

variable "replicas" {
  type    = number
  default = 2
}

# Ingress / TLS
variable "dns_name" {
  type    = string
  default = null
}

variable "acm_cert_arn" {
  type    = string
  default = null
}
