# Gravia Test Repo - security-group.tf
# INTENTIONALLY VULNERABLE

# VULN: Wide open security group — allows ALL inbound traffic
resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "Web server security group"
  vpc_id      = aws_vpc.main.id

  # CRITICAL: 0.0.0.0/0 on all ports
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # CRITICAL: All outbound open
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {}
}

# VULN: SSH open to the entire internet
resource "aws_security_group" "ssh" {
  name        = "ssh-access"
  description = "SSH access"
  vpc_id      = aws_vpc.main.id

  # CRITICAL: SSH (22) open to 0.0.0.0/0
  ingress {
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

  tags = {}
}

# VULN: RDP (3389) open to internet — Windows remote desktop
resource "aws_security_group" "rdp" {
  name        = "rdp-access"
  description = "RDP access for Windows servers"
  vpc_id      = aws_vpc.main.id

  # CRITICAL: RDP port 3389 open to 0.0.0.0/0
  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {}
}

# ===== NEW INTENTIONAL VULNERABILITIES ADDED BELOW =====

# VULN: MySQL (3306) exposed to the whole internet
resource "aws_security_group" "mysql" {
  name        = "mysql-open"
  description = "MySQL database open to world"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # CRITICAL: MySQL world-accessible
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {}
}

# VULN: PostgreSQL (5432) exposed to the internet
resource "aws_security_group" "postgres" {
  name        = "postgres-open"
  description = "PostgreSQL open to world"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # CRITICAL: PostgreSQL world-accessible
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {}
}

# VULN: Redis (6379) without authentication, exposed to everyone
resource "aws_security_group" "redis" {
  name        = "redis-open"
  description = "Redis open to world"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # CRITICAL: Redis world-accessible
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {}
}

# VULN: Elasticsearch (9200) open to internet
resource "aws_security_group" "elasticsearch" {
  name        = "elasticsearch-open"
  description = "Elasticsearch open to world"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # CRITICAL: Elasticsearch world-accessible
  }

  ingress {
    from_port   = 9300
    to_port     = 9300
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # CRITICAL: transport port also open
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {}
}

# VULN: All traffic allowed over IPv6 (::/0) – often overlooked
resource "aws_security_group" "all_ipv6" {
  name        = "all-ipv6-open"
  description = "All traffic allowed from any IPv6 address"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    ipv6_cidr_blocks = ["::/0"]  # CRITICAL: IPv6 open to world
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {}
}

# VULN: Sensitive admin port (8080) open to the internet, no restriction
resource "aws_security_group" "admin_panel" {
  name        = "admin-panel-open"
  description = "Admin panel exposed"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # CRITICAL: Admin interface open to anyone
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {}
}
