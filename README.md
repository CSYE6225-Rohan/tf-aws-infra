# tf-aws-infra

Terraform script to set up AWS VPC for demo profile.

Following commands should be run
terraform init 
terraform fmt 
terraform apply -var-file=terraform-demo.tfvars   

Also setting up github actions workflow

this should trigger following actions when pull request is raised

terraform init 
terraform fmt 
terraform validate should run
