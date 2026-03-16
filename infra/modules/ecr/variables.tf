variable "repository_name" {
  description = "Name of the ECR repository"
  type        = string
}

variable "max_tagged_images" {
  description = "Maximum number of tagged images to retain (older images are expired)"
  type        = number
  default     = 10
}
