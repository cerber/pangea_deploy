variable "auth_url" {}
variable "tenant_name" {}
variable "user_name" {}
variable "password" {}

variable "base_hostname" {
  default = "ambari"
}

variable "domain" {
  default = "pangea.local"
}

variable "image" {
  default = "CentOS-7"
}

variable "flavor" {
  default = "SO3-XLarge"
}

variable "key_file_path" {
  default = "~/.ssh/id_rsa"
}

variable "ssh_user" {
  default = "cloud-user"
}

variable "external_gateway" {
  default = "2b197be5-c9cc-4b53-99f2-00e4921bd86d"
}

variable "pool" {
  default = "public-floating-601"
}

variable "masters_count" {
  default = "3"
  description = "The number of Ambari masters to launch."
}

variable "agents_count" {
  default = "8"
  description = "The number of Ambari agents to launch."
}
