terraform {
  backend "s3" {
    bucket = "teo-terra-state"
    key    = "stage/service/webserver-cluster/terraform.tfstate" 
    region = "eu-central-1"

    dynamodb_table = "terraform-up-and-running-locks"
    encrypt        = true
  }

}