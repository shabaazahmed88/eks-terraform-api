# OIDC for IRSA
resource "aws_iam_openid_connect_provider" "eks" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list = ["sts.amazonaws.com"]
  # AWS root CA thumbprint for OIDC (subject to change by AWS over time)
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da0acd60d33"]
}

data "aws_iam_policy_document" "alb_sa_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }
    condition {
      test     = "StringEquals"
      variable = replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "") ~ ":sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "aws_iam_role" "alb" {
  name               = "${var.cluster_name}-alb-controller"
  assume_role_policy = data.aws_iam_policy_document.alb_sa_assume.json
}

data "http" "alb_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "alb" {
  name   = "${var.cluster_name}-alb-controller"
  policy = data.http.alb_policy.response_body
}

resource "aws_iam_role_policy_attachment" "alb_attach" {
  role       = aws_iam_role.alb.name
  policy_arn = aws_iam_policy.alb.arn
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.7.2"

  set { name = "clusterName" value = aws_eks_cluster.this.name }
  set { name = "region"      value = var.region }
  set { name = "serviceAccount.create" value = "true" }
  set { name = "serviceAccount.name"   value = "aws-load-balancer-controller" }
  set {
    name  = "serviceAccount.annotations.eks\.amazonaws\.com/role-arn"
    value = aws_iam_role.alb.arn
  }

  depends_on = [aws_eks_node_group.this]
}
