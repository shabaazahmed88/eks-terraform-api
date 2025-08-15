resource "kubernetes_namespace" "api" {
  metadata { name = var.k8s_namespace }
}

resource "kubernetes_deployment_v1" "api" {
  metadata {
    name      = var.app_name
    namespace = var.k8s_namespace
    labels    = { app = var.app_name }
  }
  spec {
    replicas = var.replicas
    selector { match_labels = { app = var.app_name } }
    template {
      metadata { labels = { app = var.app_name } }
      spec {
        container {
          name  = "api"
          image = var.image_uri
          port { container_port = 8080 }
          liveness_probe {
            http_get { path = "/healthz" port = 8080 }
            initial_delay_seconds = 5
            period_seconds        = 10
          }
          readiness_probe {
            http_get { path = "/healthz" port = 8080 }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
          resources {
            requests = { cpu = "100m", memory = "128Mi" }
            limits   = { cpu = "500m", memory = "256Mi" }
          }
        }
      }
    }
  }

  depends_on = [helm_release.aws_load_balancer_controller]
}

resource "kubernetes_service_v1" "api" {
  metadata {
    name      = "${var.app_name}-svc"
    namespace = var.k8s_namespace
  }
  spec {
    selector = { app = var.app_name }
    port {
      name        = "http"
      port        = 80
      target_port = 8080
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "api_ing" {
  metadata {
    name      = "${var.app_name}-ing"
    namespace = var.k8s_namespace
    annotations = {
      "kubernetes.io/ingress.class"                 = "alb"
      "alb.ingress.kubernetes.io/scheme"            = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"       = "ip"
      "alb.ingress.kubernetes.io/listen-ports"      = var.acm_cert_arn != null ? "[{\"HTTPS\":443}]" : "[{\"HTTP\":80}]"
      "alb.ingress.kubernetes.io/healthcheck-path"  = "/healthz"
      "alb.ingress.kubernetes.io/certificate-arn"   = var.acm_cert_arn != null ? var.acm_cert_arn : ""
    }
  }
  spec {
    dynamic "rule" {
      for_each = var.dns_name != null ? [var.dns_name] : []
      content {
        host = rule.value
        http {
          path {
            path      = "/"
            path_type = "Prefix"
            backend {
              service { name = kubernetes_service_v1.api.metadata[0].name port { number = 80 } }
            }
          }
        }
      }
    }

    # If no host is provided, still create default backend to access via ALB DNS
    dynamic "default_backend" {
      for_each = var.dns_name == null ? [1] : []
      content {
        service { name = kubernetes_service_v1.api.metadata[0].name port { number = 80 } }
      }
    }
  }

  depends_on = [kubernetes_service_v1.api]
}
