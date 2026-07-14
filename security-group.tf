# Gravia Test Repo - security-group.tf (SECURE)
# All security groups now restrict inbound to necessary ports and trusted IPs.

variable "trusted_admin_cidr" {
  description = "CIDR block for admin access (SSH, RDP, etc.)"
  type        = string
  default     = "192.168.0.0/16"   # Example – change to your corporate network
}

variable "web_allowed_cidr" {
  description = "CIDR block for HTTP/HTTPS"
  type        = string
  default     = "0.0.0.0/0"   # Acceptable for public web
}

# Web security group – only HTTP/HTTPS
resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "Web server security group – allows HTTP/HTTPS from anywhere, SSH from trusted"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.web_allowed_cidr]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.web_allowed_cidr]
  }

  # SSH only from trusted CIDR
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.trusted_admin_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = "production"
  }
}

# SSH – dedicated SG, but we can reuse the web SG for SSH as above; we keep for clarity.
resource "aws_security_group" "ssh" {
  name        = "ssh-access"
  description = "SSH access – restricted"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.trusted_admin_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = "production"
  }
}

# RDP – only from trusted
resource "aws_security_group" "rdp" {
  name        = "rdp-access"
  description = "RDP access for Windows servers – restricted"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = [var.trusted_admin_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = "production"
  }
}

# MySQL – only from application security groups, not from internet
resource "aws_security_group" "mysql" {
  name        = "mysql-secure"
  description = "MySQL database – accessible only from app tier"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.web.id]   # Only web SG can connect
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = "production"
  }
}

# PostgreSQL – only from app tier
resource "aws_security_group" "postgres" {
  name        = "postgres-secure"
  description = "PostgreSQL – accessible only from app tier"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = "production"
  }
}

# Redis – only from app tier
resource "aws_security_group" "redis" {
  name        = "redis-secure"
  description = "Redis – only app tier"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = "production"
  }
}

# Elasticsearch – only from app tier
resource "aws_security_group" "elasticsearch" {
  name        = "elasticsearch-secure"
  description = "Elasticsearch – app tier only"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  ingress {
    from_port   = 9300
    to_port     = 9300
    protocol    = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = "production"
  }
}

# IPv6 – we don't open all; we restrict similarly
resource "aws_security_group" "all_ipv6" {
  name        = "ipv6-restricted"
  description = "IPv6 only for necessary ports"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    ipv6_cidr_blocks = ["::/0"]   # Public web IPv6
  }

  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    ipv6_cidr_blocks = ["::/0"]
  }

  # No wide-open for IPv6 – we restrict admin ports to specific ranges if needed

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Environment = "production"
  }
}

# Admin panel – only from trusted CIDR
resource "aws_security_group" "admin_panel" {
  name        = "admin-panel-secure"
  description = "Admin panel – restricted access"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.trusted_admin_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = "production"
  }
}
