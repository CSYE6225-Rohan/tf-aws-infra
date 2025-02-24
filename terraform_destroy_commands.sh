#!/bin/bash

terraform workspace select vpc-demo-us-east-1-1
terraform destroy -var-file=vpc-us-east-1-1.tfvars -auto-approve

terraform workspace select vpc-demo-us-east-1-2
terraform destroy -var-file=vpc-us-east-1-2.tfvars -auto-approve

terraform workspace select vpc-demo-us-west-2-1
terraform destroy -var-file=vpc-us-west-2-1.tfvars -auto-approve

terraform workspace select default

terraform workspace delete vpc-demo-us-east-1-1
terraform workspace delete vpc-demo-us-east-1-2
terraform workspace delete vpc-demo-us-west-2-1