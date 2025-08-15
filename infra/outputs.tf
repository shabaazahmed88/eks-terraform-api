output "cluster_name"       { value = aws_eks_cluster.this.name }
output "cluster_endpoint"   { value = aws_eks_cluster.this.endpoint }
output "namespace"          { value = var.k8s_namespace }
output "ingress_hostname"   { value = try(kubernetes_ingress_v1.api_ing.status[0].load_balancer[0].ingress[0].hostname, "") }
