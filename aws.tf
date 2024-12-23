resource "aws_launch_template" "pds" {
  name = "pds-launch-template"

  capacity_reservation_specification {
    capacity_reservation_preference = "open"
  }

  cpu_options {
    core_count       = 2
    threads_per_core = 1
  }

  ebs_optimized = true
  instance_type = "t4g.small"

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "test"
    }
  }

  user_data = base64encode(templatefile("${path.module}/launch.sh", {
    pds_hostname : var.pds_hostname,
    pds_admin_email : var.pds_admin_email,
  }))
}

resource "aws_key_pair" "my_key_pair" {
  key_name   = var.key_pair_name
  public_key = var.public_key
}

data "aws_ami" "ubuntu22" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "pds" {
  availability_zone = var.zone
  key_name          = aws_key_pair.my_key_pair.key_name
  launch_template {
    version = "$Latest"
    id      = aws_launch_template.pds.id
  }
  instance_type               = "t4g.small"
  subnet_id                   = aws_subnet.pds_subnet.id
  vpc_security_group_ids      = [aws_security_group.pds_sg.id]
  associate_public_ip_address = true
  ami                         = data.aws_ami.ubuntu22.id

  ebs_block_device {
    device_name = "/dev/xvda"
    volume_size = 22
    volume_type = "gp3"
  }

  cpu_options {
    core_count       = 2
    threads_per_core = 1
  }

  tags = {
    Name = "pds-instance"
    PDS  = var.pds_hostname
  }
  lifecycle {
    ignore_changes = [
      # Ignore changes to tags, e.g. because a management agent
      # updates these based on some ruleset managed elsewhere.
      tags,
      user_data,
    ]
  }
}
