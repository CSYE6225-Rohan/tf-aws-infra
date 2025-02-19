#!/bin/bash

#Creting workspaces for vpcs
terraform init

terraform fmt -check -recursive

terraform validate

terraform workspace new vpc-demo-us-east-1-1
terraform apply -var-file=vpc-us-east-1-1.tfvars -auto-approve

terraform workspace new vpc-demo-us-east-1-2
terraform apply -var-file=vpc-us-east-1-2.tfvars -auto-approve

terraform workspace new vpc-demo-us-west-2-1
terraform apply -var-file=vpc-us-west-2-1.tfvars -auto-approve
