terraform {
    required_providers {
      aws = {
        source = "hashicorp/aws"
        version = "~> 4.0.0"
      }
    }
    backend "s3" {
        bucket = "my-terraform-state-bucket-app-plony-2"
        key = "terraform.tfstate"
        region = "us-west-2"
        dynamodb_table = "terraform-locks"
        encrypt        = true  # Enable server-side encryption for state file     
    }
}