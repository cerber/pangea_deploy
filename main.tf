provider "openstack" {
  auth_url  = "${ var.auth_url }"
  tenant_name = "${ var.tenant_name }"
  user_name  = "${ var.user_name }"
  password  = "${ var.password }"
}

resource "openstack_compute_keypair_v2" "pangea" {
  name = "pangea_keypair"
  region = "us-virginia-1"
  public_key = "${ file("${var.key_file_path}.pub") }"
}

resource "openstack_compute_servergroup_v2" "pangea" {
  name = "pangea"
  region = "${ openstack_compute_keypair_v2.pangea.region }"
  policies = ["anti-affinity"]
}

resource "openstack_networking_network_v2" "pangea" {
  name = "pangea"
  region = "${ openstack_compute_keypair_v2.pangea.region }"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "pangea" {
  name = "pangea"
  region = "${ openstack_compute_keypair_v2.pangea.region }"
  network_id = "${ openstack_networking_network_v2.pangea.id }"
  cidr = "10.0.0.0/24"
  ip_version = 4
  dns_nameservers = ["8.8.8.8","8.8.4.4"]
}

resource "openstack_networking_router_v2" "pangea" {
  name = "pangea"
  region = "${ openstack_compute_keypair_v2.pangea.region }"
  admin_state_up = "true"
  external_gateway = "${ var.external_gateway }"
}

resource "openstack_networking_router_interface_v2" "pangea" {
  region = "${ openstack_compute_keypair_v2.pangea.region }"
  router_id = "${ openstack_networking_router_v2.pangea.id }"
  subnet_id = "${ openstack_networking_subnet_v2.pangea.id }"
}

resource "openstack_compute_secgroup_v2" "pangea" {
  name = "pangea"
  description = "Security group for the pangea instances"
  region = "${ openstack_compute_keypair_v2.pangea.region }"

  rule {
    from_port = 22
    to_port = 22
    ip_protocol = "tcp"
    cidr = "0.0.0.0/0"
  }

  rule {
    from_port = 8080
    to_port = 8080
    ip_protocol = "tcp"
    cidr = "0.0.0.0/0"
  }

  rule {
    from_port = 1
    to_port = 65535
    ip_protocol = "tcp"
    cidr = "${ openstack_networking_subnet_v2.pangea.cidr }"
  }

  rule {
    from_port = 1
    to_port = 65535
    ip_protocol = "udp"
    cidr = "${ openstack_networking_subnet_v2.pangea.cidr }"
  }

  rule {
    from_port = -1
    to_port = -1
    ip_protocol = "icmp"
    cidr = "0.0.0.0/0"
  }
}

resource "openstack_networking_floatingip_v2" "floatip_1" {
  region = "${ openstack_compute_keypair_v2.pangea.region }"
  pool = "${ var.pool }"
}

resource "openstack_compute_floatingip_v2" "pangea-ambari" {
  region = "${ openstack_compute_keypair_v2.pangea.region }"
  pool = "${ var.pool }"
}

resource "template_file" "pangea-ambari" {
  template = "${file("templates/pangea-ambari.yaml")}"

  vars {
    domain = "${ var.domain }"
    hostname = "pangea-ambari"
  }
}

resource "template_file" "pangea-master" {
  template = "${file("templates/pangea-agent.yaml")}"
  count = "${ var.masters_count }"

  vars {
    domain = "${ var.domain }"
    hostname = "master-${ format("%02d", count.index+1) }"
    ambari_server = "${openstack_compute_instance_v2.pangea-ambari.network.0.fixed_ip_v4}"
  }
}

resource "template_file" "pangea-agent" {
  template = "${file("templates/pangea-agent.yaml")}"
  count = "${ var.agents_count }"

  vars {
    domain = "${ var.domain }"
    hostname = "agent-${ format("%02d", count.index+1) }"
    ambari_server = "${openstack_compute_instance_v2.pangea-ambari.network.0.fixed_ip_v4}"
  }
}

resource "openstack_compute_instance_v2" "pangea-ambari" {
  name = "pangea-ambari"
  region = "${ openstack_compute_keypair_v2.pangea.region }"
  image_name = "${ var.image }"
  flavor_name = "${ var.flavor }"
  key_pair = "${ openstack_compute_keypair_v2.pangea.name }"
  security_groups = [ "${ openstack_compute_secgroup_v2.pangea.name }" ]
  floating_ip = "${ openstack_compute_floatingip_v2.pangea-ambari.address }"
  network {
    uuid = "${ openstack_networking_network_v2.pangea.id }"
  }
  scheduler_hints = {
    group = "${ openstack_compute_servergroup_v2.pangea.id }"
  }
  metadata = {
    role = "ambari-server"
    ssh_user = "${ var.ssh_user }"
  }

  connection {
    user = "${ var.ssh_user }"
    key_file = "${ var.key_file_path }"
    timeout = "1m"
  }

  user_data = "${ template_file.pangea-ambari.rendered }"
}

resource "openstack_compute_instance_v2" "pangea-master" {
  name = "master-${ format("%02d", count.index+1) }"
  count = "${ var.masters_count }"
  region = "${ openstack_compute_keypair_v2.pangea.region }"
  image_name = "${ var.image }"
  flavor_name = "${ var.flavor }"
  key_pair = "${ openstack_compute_keypair_v2.pangea.name }"
  security_groups = [ "${ openstack_compute_secgroup_v2.pangea.name }" ]
//  floating_ip = "${ openstack_compute_floatingip_v2.pangea-ambari.address }"
  network {
    uuid = "${ openstack_networking_network_v2.pangea.id }"
  }
  scheduler_hints = {
    group = "${ openstack_compute_servergroup_v2.pangea.id }"
  }
  metadata = {
    role = "ambari-server"
    ssh_user = "${ var.ssh_user }"
  }

  connection {
    user = "${ var.ssh_user }"
    key_file = "${ var.key_file_path }"
    timeout = "1m"
  }

  user_data = "${ element(template_file.pangea-master.*.rendered, count.index) }"
}

resource "openstack_compute_instance_v2" "pangea-agent" {
  name = "agent-${ format("%02d", count.index+1) }"
  count = "${ var.agents_count }"
  region = "${ openstack_compute_keypair_v2.pangea.region }"
  image_name = "${ var.image }"
  flavor_name = "${ var.flavor }"
  key_pair = "${ openstack_compute_keypair_v2.pangea.name }"
  security_groups = [ "${ openstack_compute_secgroup_v2.pangea.name }" ]
//  floating_ip = "${ openstack_compute_floatingip_v2.pangea-ambari.address }"
  network {
    uuid = "${ openstack_networking_network_v2.pangea.id }"
  }
  scheduler_hints = {
    group = "${ openstack_compute_servergroup_v2.pangea.id }"
  }
  metadata = {
    role = "ambari-server"
    ssh_user = "${ var.ssh_user }"
  }

  connection {
    user = "${ var.ssh_user }"
    key_file = "${ var.key_file_path }"
    timeout = "1m"
  }

  user_data = "${ element(template_file.pangea-agent.*.rendered, count.index) }"
}



//  provisioner "file" {
//    source = "${path.module}/scripts/consul/consul.service"
//    destination = "/tmp/consul.service"
//  }

//  provisioner "remote-exec" {
//    inline = [
//      # "echo ${ var.agents } > /tmp/consul-server-count",
//      # "echo ${ count.index } > /tmp/consul-server-index",
//      # "echo ${ openstack_compute_instance_v2.pangea_ambari.network.0.fixed_ip_v4 } > /tmp/consul-server-addr",
//    ]
//  }

