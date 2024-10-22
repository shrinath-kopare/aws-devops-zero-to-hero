variable "vpc_cidr" {
  default = "10.0.0.0/16" #65k
}

variable "sub1_cidr" {
  default = "10.0.0.0/24" #256
}

variable "sub2_cidr" {
  default = "10.0.1.0/24" #256
}

variable "sub1_region" {
  default = "us-east-1a"
}

variable "sub2_region" {
  default = "us-east-1b"
}

variable "anywhere_ipv4_cidr" {
  default = "0.0.0.0/0"
}

variable "microinstance" {
  default = "t2.micro"
}

variable "microami" {
  default = "ami-0866a3c8686eaeeba"
}