variable "name" {
  type        = string
  description = "VPC name"
}

variable "cidr" {
  type        = string
  description = "VPC CIDR block"
}

variable "azs" {
  type        = list(string)
  description = "Availability Zones"
}
