output "public_ip" {
  description = "IP público da VM."
  value       = oci_core_instance.bot.public_ip
}

output "ssh_command" {
  value = "ssh ubuntu@${oci_core_instance.bot.public_ip}"
}

output "bootstrap_log_command" {
  description = "Acompanhe o cloud-init (leva alguns minutos)."
  value       = "ssh ubuntu@${oci_core_instance.bot.public_ip} 'sudo tail -f /var/log/zombizoid-bootstrap.log'"
}

output "push_config_command" {
  description = "Envia config.yaml (600) e reinicia o serviço."
  value       = "deploy/oracle/push-config.sh ubuntu@${oci_core_instance.bot.public_ip} ./config.yaml"
}

output "shape" {
  value = oci_core_instance.bot.shape
}

output "image_name" {
  value = data.oci_core_images.ubuntu.images[0].display_name
}
