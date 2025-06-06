# Create the hosted zone for the domain
resource "aws_route53_zone" "main" {
  name = var.domain_name
  
  tags = {
    Name = "${var.project_name}-zone-${var.environment}"
  }
}

# Create a record for the main domain pointing to the ALB
resource "aws_route53_record" "main" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

# Create a record for the API subdomain
resource "aws_route53_record" "api" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "api.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

# Create a record for the Metabase subdomain
resource "aws_route53_record" "metabase" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "bi.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

# Output the NS records to be added to the domain registrar
output "nameservers" {
  description = "Nameservers for the Route53 zone - add these to your domain registrar"
  value       = aws_route53_zone.main.name_servers
}