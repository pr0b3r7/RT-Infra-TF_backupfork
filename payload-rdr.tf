# create payload redirector droplet
resource "digitalocean_droplet" "payload-rdr" {
  image  = "ubuntu-18-04-x64"
  name   = "${var.domain-rdir}"
  region = "nyc3"
  size   = "s-1vcpu-1gb"
  ssh_keys = ["${digitalocean_ssh_key.dossh.id}"]

  provisioner "remote-exec" {
    inline = [
      # postfix
      "export DEBIAN_FRONTEND=noninteractive; apt update && apt-get -y -qq install socat postfix opendkim opendkim-tools certbot apache2",      
      "echo ${var.domain-rdir} > /etc/mailname",
      "echo ${digitalocean_droplet.payload-rdr.ipv4_address} ${var.domain-rdir} > /etc/hosts",
      "postconf -e myhostname=${var.domain-rdir}",
      "postconf -e milter_protocol=2",
      "postconf -e milter_default_action=accept",
      "postconf -e smtpd_milters=inet:localhost:12345",
      "postconf -e non_smtpd_milters=inet:localhost:12345",
      "postconf -e mydestination=\"${var.domain-rdir}, $myhostname, localhost.localdomain, localhost\"",
      "postconf -e mynetworks=\"127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128 ${digitalocean_droplet.payload.ipv4_address}\"",
      
      # letsencrypt key pair will need to be generated by running finalize.sh from the working directory of this project
      # "postconf -e smtpd_tls_cert_file=/etc/letsencrypt/live/${var.domain-rdir}/fullchain.pem",
      # "postconf -e smtpd_tls_key_file=/etc/letsencrypt/live/${var.domain-rdir}/privkey.pem",
      # "postconf -e smtpd_tls_security_level=may",
      # "postconf -e smtp_tls_security_level=encrypt",    	
      # "postconf -e smtpd_use_tls=no",    	

      # dkim
      "mkdir -p /etc/opendkim/keys/${var.domain-rdir}",
      "cd /etc/opendkim/keys/${var.domain-rdir}; opendkim-genkey -t -s mail -d ${var.domain-rdir} && tr -d \"\\n\\t\\\" \" < mail.txt | cut -d\"(\" -f2 | cut -d \")\" -f1 > /root/dkim.txt; sudo chown opendkim:opendkim mail.private",
      "echo mail._domainkey.${var.domain-rdir} ${var.domain-rdir}:mail:/etc/opendkim/keys/${var.domain-rdir}/mail.private > /etc/opendkim/KeyTable",
      "echo *@${var.domain-rdir} mail._domainkey.${var.domain-rdir} > /etc/opendkim/SigningTable",
      "echo \"SOCKET=\"inet:12345@localhost\"\" >> /etc/default/opendkim",
      "echo ${digitalocean_droplet.payload.ipv4_address} > /etc/opendkim/TrustedHosts",
      "echo *.${var.domain-rdir} >> /etc/opendkim/TrustedHosts",     
      "echo localhost >> /etc/opendkim/TrustedHosts",     
      "echo 127.0.0.1 >> /etc/opendkim/TrustedHosts",     
      
      # http relays
      "echo \"@reboot root socat TCP4-LISTEN:80,fork TCP4:${digitalocean_droplet.payload.ipv4_address}:80\" >> /etc/cron.d/mdadm",
      "echo \"@reboot root socat TCP4-LISTEN:443,fork TCP4:${digitalocean_droplet.payload.ipv4_address}:443\" >> /etc/cron.d/mdadm"
    ]
  }

  provisioner "file" {
    source = "./configs/header_checks"
    destination = "/etc/postfix/header_checks"
  }

  provisioner "file" {
    source = "./configs/master.cf"
    destination = "/etc/postfix/master.cf"
  }

  provisioner "file" {
    source = "./configs/opendkim.conf"
    destination = "/etc/opendkim.conf"
  }

  provisioner "local-exec" {
    command = "echo ssh -o StrictHostKeyChecking=no ${digitalocean_droplet.payload-rdr.ipv4_address} certbot certonly --standalone -d ${var.domain-rdir} --register-unsafely-without-email --agree-tos >> finalize.sh"
  }

  provisioner "local-exec" {
    command = "echo ssh -o StrictHostKeyChecking=no ${digitalocean_droplet.payload-rdr.ipv4_address} cat /root/dkim.txt >> finalize.sh"
  }

  provisioner "local-exec" {
    command = "echo rm finalize.sh >> finalize.sh; chmod +x finalize.sh"
  }

  provisioner "remote-exec" {
    inline = [
      # "postmap /etc/postfix/header_checks",
      # "postfix reload",
      # "service postfix restart; service opendkim restart"
      "shutdown -r"
    ]
  }
}
