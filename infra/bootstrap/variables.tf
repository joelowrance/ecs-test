variable "aws_region" {
  description = "AWS region for the state backend resources"
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for Terraform remote state storage"
  type        = string
  # Example: "mycompany-ecs-example-terraform-state"
}
