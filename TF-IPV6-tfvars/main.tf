provider "aws" {
  region = var.region
}

# Expect to change these
variable "instance_count" {
}

variable "dns_host_base" {
}

variable "instance_type" {
}

variable "instance_role" {
}

variable "key_name" {
}

variable "ami_choice" {
}

variable "route53_zone_name" {
}

variable "tagbase" {
}

variable "charging_tag" {
}

variable "region" {
}

variable "vpc_cidr_block" {
}

variable "subnet_count" {
}

variable "subnet_map_public_ip" {
}

variable "availability_zones" {
  type    = list(string)
  default = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
}

variable "subnet_cidr_blocks" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

# Constants
variable "any_ipv4_address" {
  default = "0.0.0.0/0"
}

variable "any_ipv6_address" {
  default = "::/0"
}

variable "count_to_alpha_lower" {
  type    = list(string)
  default = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"]
}

variable "count_to_alpha_upper" {
  type    = list(string)
  default = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]
}

resource "aws_vpc" "Vpc" {
  cidr_block                       = var.vpc_cidr_block
  assign_generated_ipv6_cidr_block = true
  tags = {
    Name = "${var.tagbase} VPC"
    RG   = var.charging_tag
  }
}

resource "aws_subnet" "Subnet" {
  vpc_id          = aws_vpc.Vpc.id
  count           = var.subnet_count
  cidr_block      = cidrsubnet(aws_vpc.Vpc.cidr_block, 8, count.index + 1)
  ipv6_cidr_block = cidrsubnet(aws_vpc.Vpc.ipv6_cidr_block, 8, count.index + 1)

  #    cidr_block = "${element(var.subnet_cidr_blocks, count.index)}"
  availability_zone               = element(var.availability_zones, count.index)
  assign_ipv6_address_on_creation = true

  #    assign_ipv6_address_on_creation = "False"
  map_public_ip_on_launch = var.subnet_map_public_ip
  tags = {
    Name = "${var.tagbase} Subnet ${element(var.count_to_alpha_upper, count.index)}"
    RG   = var.charging_tag
  }
}

resource "aws_internet_gateway" "Igw" {
  vpc_id = aws_vpc.Vpc.id
  tags = {
    Name = "${var.tagbase} IGW"
    RG   = var.charging_tag
  }
}

resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.Vpc.id
  tags = {
    Name = "${var.tagbase} Route Table"
    RG   = var.charging_tag
  }
}

resource "aws_route" "default_ipv4" {
  route_table_id         = aws_route_table.route_table.id
  destination_cidr_block = var.any_ipv4_address
  gateway_id             = aws_internet_gateway.Igw.id
}

resource "aws_route" "default_ipv6" {
  route_table_id              = aws_route_table.route_table.id
  destination_ipv6_cidr_block = var.any_ipv6_address
  gateway_id                  = aws_internet_gateway.Igw.id
}

resource "aws_route_table_association" "RTAssoc" {
  count          = var.subnet_count
  subnet_id      = element(aws_subnet.Subnet.*.id, count.index)
  route_table_id = aws_route_table.route_table.id
}

resource "aws_network_acl" "NetworkACL" {
  vpc_id     = aws_vpc.Vpc.id
  subnet_ids = aws_subnet.Subnet.*.id
  tags = {
    Name = "${var.tagbase} Network ACL"
    RG   = var.charging_tag
  }
}

resource "aws_network_acl_rule" "rule_1" {
  network_acl_id = aws_network_acl.NetworkACL.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = var.any_ipv4_address
  from_port      = 0
  to_port        = 0
}

resource "aws_network_acl_rule" "rule_2" {
  network_acl_id = aws_network_acl.NetworkACL.id
  rule_number    = 100
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = var.any_ipv4_address
  from_port      = 0
  to_port        = 0
}

resource "aws_network_acl_rule" "rule_3" {
  network_acl_id  = aws_network_acl.NetworkACL.id
  rule_number     = 101
  egress          = true
  protocol        = "-1"
  rule_action     = "allow"
  ipv6_cidr_block = var.any_ipv6_address
  from_port       = 0
  to_port         = 0
}

resource "aws_network_acl_rule" "rule_4" {
  network_acl_id  = aws_network_acl.NetworkACL.id
  rule_number     = 101
  egress          = false
  protocol        = "-1"
  rule_action     = "allow"
  ipv6_cidr_block = var.any_ipv6_address
  from_port       = 0
  to_port         = 0
}

resource "aws_security_group" "InstanceSecurityGroup" {
  name        = "${var.tagbase} Security Group"
  description = "TF-Allow ports for Splunk"
  vpc_id      = aws_vpc.Vpc.id

  #    vpc_id = "${var.vpc_id}"
  tags = {
    Name = "${var.tagbase} SG"
    RG   = var.charging_tag
  }
}

resource "aws_security_group_rule" "allow-egress-ipv4" {
  type              = "egress"
  description       = "TF-Allow All Egress"
  security_group_id = aws_security_group.InstanceSecurityGroup.id

  to_port     = 65535
  protocol    = "-1"
  from_port   = 0
  cidr_blocks = [var.any_ipv4_address]
}

resource "aws_security_group_rule" "allow-ssh-ipv4" {
  type              = "ingress"
  description       = "TF-Allow ssh from anywhere"
  security_group_id = aws_security_group.InstanceSecurityGroup.id

  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = [var.any_ipv4_address]
}

resource "aws_security_group_rule" "allow-egress-ipv6" {
  type              = "egress"
  description       = "TF-Allow All Egress"
  security_group_id = aws_security_group.InstanceSecurityGroup.id

  to_port          = 65535
  protocol         = "-1"
  from_port        = 0
  ipv6_cidr_blocks = [var.any_ipv6_address]
}

resource "aws_security_group_rule" "allow-ssh-ipv6" {
  type              = "ingress"
  description       = "TF-Allow ssh from anywhere"
  security_group_id = aws_security_group.InstanceSecurityGroup.id

  from_port        = 22
  to_port          = 22
  protocol         = "tcp"
  ipv6_cidr_blocks = [var.any_ipv6_address]
}

resource "aws_instance" "EC2Instance" {
  count         = var.instance_count
  ami           = var.ami_choice
  instance_type = var.instance_type
  vpc_security_group_ids = [
    aws_security_group.InstanceSecurityGroup.id,
  ]
  subnet_id            = element(aws_subnet.Subnet.*.id, count.index)
  ipv6_address_count   = 1
  key_name             = var.key_name
  iam_instance_profile = var.instance_role

  #  user_data = "${file("${path.module}/files/splunk-install.sh")}"
  #  user_data = "${data.template_file.user_data.rendered}"
  #  user_data = "${element(data.template_file.user_data.*.rendered, count.index)}"
  root_block_device {
    volume_size = 15
  }

  tags = {
    Name = "${var.tagbase} ${element(var.count_to_alpha_upper, count.index)}"
    RG   = var.charging_tag
  }
}

data "aws_route53_zone" "route53_zone" {
  name = var.route53_zone_name
}

# resource "aws_route53_record" "instance" {
#   zone_id = "${data.aws_route53_zone.route53_zone.zone_id}"
#   count = "${var.instance_count}"
#   name    = "${var.dns_host_base}-${element(var.count_to_alpha_lower, count.index)}"
#   type    = "A"
#   ttl     = "300"
#   records = ["${element(aws_instance.EC2Instance.*.public_ip, count.index)}"]
# }
# resource "aws_route53_record" "instance-AAAA" {
#   zone_id = "${data.aws_route53_zone.route53_zone.zone_id}"
#   count = "${var.instance_count}"
#   name    = "${var.dns_host_base}-${element(var.count_to_alpha_lower, count.index)}"
#   type    = "AAAA"
#   ttl     = "300"
#   records = ["${element(aws_instance.EC2Instance.*.ipv6_addresses.0, count.index)}"]
# }
