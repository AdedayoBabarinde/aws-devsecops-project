variable "repository_name" {
  description = "ECR repository name"
  type        = string
}
variable "pull_principals" {
  description = "IAM principals allowed to pull images"
  type        = list(string)
  default     = ["*"]
}
variable "tags" {
  type    = map(string)
  default = {}
}
