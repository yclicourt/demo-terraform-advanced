resource "aws_security_group" "server" {
  name        = "server_net_ue_reg"
  description = "Allow inbound traffic"
  vpc_id      = module.network.vpc_id

  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "tag_server"
  }
}
resource "aws_security_group" "web_server_private" {
  name        = "web_server_private"
  description = "Allow inbound traffic"
  vpc_id      = module.network.vpc_id

  ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "tag_server"
  }
}

resource "tls_private_key" "server" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "server" {
  key_name   = "server_key"
  public_key = tls_private_key.server.public_key_openssh
}

resource "aws_instance" "web_srv" {
  count                  = var.server_count
  ami                    = "ami-456871456"
  key_name               = aws_key_pair.server.key_name
  instance_type          = var.server_type
  subnet_id              = module.network.public_subnets[count.index]
  vpc_security_group_ids = [aws_security_group.server.id]


  associate_public_ip_address = var.include_ipv4
  tags = {
    Name = "tag_web_public-${count.index}"
  }
}
resource "aws_instance" "web_srv_private" {
  count         = var.private_server_count
  ami           = "ami-456871456"
  key_name      = aws_key_pair.server.key_name
  instance_type = var.server_type
  subnet_id     = module.network.private_subnets[count.index]
  vpc_security_group_ids = [
    aws_security_group.server.id,
    aws_security_group.web_server_private.id
  ]
  /* user_data = <<-EOF
               #!/bin/bash
               sudo apt-get update
               sudo apt-get install -y nginx
               sudo systemctl start nginx
               sudo systemctl enable nginx
               EOF */

  tags = {
    Name = "tag_web_private-${count.index}"
  }
}


resource "aws_lb" "lb_server_app" {
  name               = "${local.lb_name}-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_server_private.id]
  subnets            = module.network.public_subnets

  enable_deletion_protection = false


  tags = {
    Environment = "${local.lb_name}-tf"
  }
}

resource "aws_lb_target_group" "lb_tg_server" {
  name     = "${local.lb_name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.network.vpc_id
}


resource "aws_lb_listener" "lb_server_listener" {
  load_balancer_arn = aws_lb.lb_server_app.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_tg_server.arn
  }
}

resource "aws_lb_listener_rule" "lb_list_rule" {
  listener_arn = aws_lb_listener.lb_server_listener.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_tg_server.arn
  }

  condition {
    path_pattern {
      values = ["/"]
    }
  }

}

resource "aws_lb_target_group_attachment" "lb_tg_attach" {
  count            = var.private_server_count
  target_group_arn = aws_lb_target_group.lb_tg_server.arn
  target_id        = aws_instance.web_srv_private[count.index].id
  port             = 80
}
