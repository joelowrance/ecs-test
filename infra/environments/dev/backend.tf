terraform {
  backend "s3" {
    # Run infra/bootstrap first to create this bucket and table.
    # Replace <YOUR_STATE_BUCKET> with the output from bootstrap.
    bucket         = "<YOUR_STATE_BUCKET>"
    key            = "ecs-example/dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
}
