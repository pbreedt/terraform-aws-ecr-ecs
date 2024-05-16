# terraform-aws-ecr-ecs

## Overview:
A reference IaC (Infrastrcture-as-Code) implementation of AWS infrastucture (using ECR & ECS) with Terraform.  
Reference guide: https://earthly.dev/blog/deploy-dockcontainers-to-awsecs-using-terraform/

## Usage:
```sh
 $  export TF_VAR_aws_access_key=XXX
 $  export TF_VAR_aws_secret=XXX
 $  terraform init
 $  terraform plan
 $  terraform apply
```

## Comments:
Used the image created from project https://github.com/pbreedt/test-vue-ci-cd  
ECR appears to host a single Docker image per repo (multiple versions possible, but same image)  
For ECS to get image, image must be be tagged as 'latest'  
docker tag test-vue:1.0.0 312970875324.dkr.ecr.us-east-2.amazonaws.com/aws-docker-repo:latest  
docker push 312970875324.dkr.ecr.us-east-2.amazonaws.com/aws-docker-repo:latest  
Version can also be pushed, resulting on two tags on same image, but latest is the one being used:  
docker tag test-vue:1.0.0 312970875324.dkr.ecr.us-east-2.amazonaws.com/aws-docker-repo:1.0.0  
docker push 312970875324.dkr.ecr.us-east-2.amazonaws.com/aws-docker-repo:1.0.0  

## Docker swarm implementation
Nice example using Docker swarm:  
https://github.com/Praqma/terraform-aws-docker  
(Seems like it might require some minor changes, could be a little outdated)  
