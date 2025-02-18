# tf-aws-infra

Terraform script to set up AWS VPC for demo profile.

Following commands should be run
1. terraform init 
2. terraform fmt 
3. terraform plan -var-file=[name].tfvars   
4. terraform apply -var-file=[name].tfvars -auto-approve
5. terraform destroy -var-file=[name] -auto-approve

One workspace of terraform can create one VPC. 

Also, script for creating multiple VPCs along with thier workspaces is present in terraform_commands.sh

Also setting up github actions workflow

this should trigger following actions when pull request is raised to the main branch

1. terraform init 
2. terraform fmt 
3. terraform validate 
