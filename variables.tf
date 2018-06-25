variable "server_port" {
  description = "The port the server will use for HTTP requests"
  default = 8080
}
variable "AWS_ACCESS_KEY_ID" {
  default = "AKIAJFHQ5Z5U2AWXMUHQ"
}
variable "AWS_SECRET_ACCESS_KEY" {
  default = "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"
}
variable "aws_ami" {
  default = "ami-f3143e18"
}
data "aws_availability_zones" "all" {}
