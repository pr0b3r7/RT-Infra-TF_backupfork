# create payload redirector droplet
resource "digitalocean_droplet" "payload-rdr" {
  image  = "ubuntu-18-04-x64"
  name   = "payload-rdr"
  region = "nyc3"
  size   = "s-1vcpu-1gb"
  ssh_keys = ["${digitalocean_ssh_key.dossh.id}"]

  provisioner "remote-exec" {
    inline = [
        # environment
        "apt update",
        "apt-get -y install socat",
        "export DEBIAN_FRONTEND=noninteractive; apt-get -y install postfix",
        "echo ${var.domain-rdir} > /etc/mailname",
        "sed -i 's/myhostname = ${digitalocean_droplet.payload-rdr.name}/myhostname = ${var.domain-rdir}/' /etc/postfix/main.cf",
        "sed -i 's/127.0.0.0\\/8/${digitalocean_droplet.payload.ipv4_address}/' /etc/postfix/main.cf"


        # "echo \"@reboot root socat TCP4-LISTEN:80,fork TCP4:${digitalocean_droplet.payload.ipv4_address}:80\" >> /etc/cron.d/mdadm",
        # "echo \"@reboot root socat TCP4-LISTEN:443,fork TCP4:${digitalocean_droplet.payload.ipv4_address}:443\" >> /etc/cron.d/mdadm",
        
        # # http/s traffic redirectors
        # "socat TCP4-LISTEN:80,fork TCP4:${digitalocean_droplet.payload.ipv4_address}:80 &",
        # "socat TCP4-LISTEN:443,fork TCP4:${digitalocean_droplet.payload.ipv4_address}:443 &",
        # "shutdown -r"
    ]
  }

}