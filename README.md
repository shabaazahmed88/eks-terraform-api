# EKS + Terraform + ALB Ingress – Demo API

This is a **working scaffold** to deploy a Dockerized API on **Amazon EKS** using **Terraform**, exposed via **AWS ALB Ingress** with optional **ACM TLS**.

## Prerequisites
- AWS account & credentials (`aws configure`)
- Tools: `terraform` >= 1.6, `kubectl`, `docker`
- (Optional) **ACM cert** for your domain in the same region as the EKS cluster
- (Optional) Route53 hosted zone if you want a pretty DNS name

## 1) Build & Push Image to ECR
```bash
export AWS_REGION=ap-south-1
export APP_NAME=imago-api
export ECR_REPO=$APP_NAME
export CLUSTER_NAME=imago-c3

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws ecr create-repository --repository-name $ECR_REPO --region $AWS_REGION || true

aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

docker build -t ${APP_NAME}:v1 ./api
docker tag ${APP_NAME}:v1 ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:v1
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:v1

export IMAGE_URI=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:v1
```

## 2) (Optional) TLS & DNS
- If you have a domain, request/validate an **ACM cert** for `api.yourdomain.com` (same region).
- Set:
```bash
export DNS_NAME=api.yourdomain.com
export ACM_CERT_ARN=arn:aws:acm:...:certificate/xxxxxxxx
```
- If you **don’t** have a domain/cert, you can skip these; the Ingress will use **HTTP** and you can access via the ALB hostname.

## 3) Apply Terraform (create EKS, install ALB controller, deploy app)
From `infra/`:
```bash
cd infra

terraform init

terraform apply -auto-approve   -var "region=$AWS_REGION"   -var "cluster_name=$CLUSTER_NAME"   -var "image_uri=$IMAGE_URI"   -var "dns_name=${DNS_NAME:-null}"   -var "acm_cert_arn=${ACM_CERT_ARN:-null}"
```

## 4) Test
```bash
aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION
kubectl get nodes -o wide
kubectl -n imago-api get deploy,svc,ing -o wide

# Get ALB hostname:
ALB=$(kubectl -n imago-api get ing imago-api-ing -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "ALB: http(s)://$ALB"
curl -ski http://$ALB/healthz     # if no ACM
curl -ski https://${DNS_NAME}/healthz  # if using ACM + DNS
```

## 5) Cleanup
```bash
cd infra
terraform destroy -auto-approve   -var "region=$AWS_REGION"   -var "cluster_name=$CLUSTER_NAME"   -var "image_uri=$IMAGE_URI"   -var "dns_name=${DNS_NAME:-null}"   -var "acm_cert_arn=${ACM_CERT_ARN:-null}"

# Optionally delete ECR repo
aws ecr delete-repository --repository-name $ECR_REPO --force --region $AWS_REGION
```

## Notes
- This template uses **IRSA** for the AWS Load Balancer Controller.
- In production, consider a dedicated VPC module, private-only nodes with NAT, and ESO for secrets.
