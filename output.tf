output "consul_url" {
  value = "http://${aws_lb.consul_server.dns_name}"
}

output "nomad_url" {
  value = "http://${aws_lb.nomad_server.dns_name}"
}
