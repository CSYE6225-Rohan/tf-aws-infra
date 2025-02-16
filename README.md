# tf-aws-infra

Terraform script to set up AWS VPC for demo profile.

Following commands should be run
1. terraform init 
2. terraform fmt 
3. terraform plan -var-file=terraform-demo.tfvars   
4. terraform apply -var-file=terraform-demo.tfvars   
5. terraform destroy -var-file="terraform-demo.tfvars" -auto-approve

Also setting up github actions workflow

this should trigger following actions when pull request is raised to the main branch

1. terraform init 
2. terraform fmt 
3. terraform validate 
