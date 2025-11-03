provider "aws" {
  region = "ap-south-1"
}

resource "aws_s3_bucket" "my_bucket" {
  bucket = "terraform-mentoring-bucket"

  lifecycle {
    prevent_destroy = true
    ignore_changes  = all
  }
}

resource "aws_s3_bucket_ownership_controls" "bucket_owner" {
  bucket = aws_s3_bucket.my_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket = aws_s3_bucket.my_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.my_bucket.id

  index_document { suffix = "index.html" }
  error_document { key = "404.html" }

  routing_rule {
    condition {
      http_error_code_returned_equals = "404"
    }
    redirect {
      replace_key_with   = "index.html"
      http_redirect_code = "302"
    }
  }
}

resource "aws_s3_bucket_cors_configuration" "cors" {
  bucket = aws_s3_bucket.my_bucket.id
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

data "aws_iam_policy_document" "public_read" {
  statement {
    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:DeleteObject"
    ]

    resources = [
      aws_s3_bucket.my_bucket.arn,
      "${aws_s3_bucket.my_bucket.arn}/*"
    ]
  }
}

resource "aws_s3_bucket_policy" "public_read" {
  bucket = aws_s3_bucket.my_bucket.id
  policy = data.aws_iam_policy_document.public_read.json

  depends_on = [
    aws_s3_bucket_public_access_block.public_access
  ]
}

locals {
  mime_types = {
    "html"  = "text/html",
    "css"   = "text/css",
    "js"    = "application/javascript",
    "json"  = "application/json",
    "png"   = "image/png",
    "jpg"   = "image/jpeg",
    "jpeg"  = "image/jpeg",
    "svg"   = "image/svg+xml",
    "ico"   = "image/x-icon",
    "txt"   = "text/plain",
    "woff"  = "font/woff",
    "woff2" = "font/woff2",
    "map"   = "application/json",
    "ttf"   = "font/ttf",
    "eot"   = "application/vnd.ms-fontobject"
  }
}

resource "aws_s3_object" "static_files" {
  for_each = fileset("${path.module}/../frontend/out", "**/*.*")

  bucket       = aws_s3_bucket.my_bucket.id
  key          = each.value
  source       = "${path.module}/../frontend/out/${each.value}"
  content_type = lookup(local.mime_types, split(".", each.value)[length(split(".", each.value)) - 1], "application/octet-stream")
  etag         = filemd5("${path.module}/../frontend/out/${each.value}")
  acl          = "public-read"

  cache_control = contains([".html"], ".${split(".", each.value)[length(split(".", each.value)) - 1]}") ? "no-cache" : "max-age=31536000"
}

output "website_url" {
  value = "http://${aws_s3_bucket_website_configuration.website.website_endpoint}"
}


terraform {
  backend "s3" {
    bucket         = "mentorship-tf-state-bucket"
    key            = "feedback-app/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-locks"
  }
}

########################################################
# RDS Setup
########################################################
# data "aws_vpc" "default" {
#   default = true
# }

# data "aws_subnets" "default" {
#   filter {
#     name   = "vpc-id"
#     values = [data.aws_vpc.default.id]
#   }

# }

# # Generate password
# resource "random_password" "db_password" {
#   length  = 20
#   special = true
# }

# # Store in Secrets Manager
# resource "aws_secretsmanager_secret" "db_creds" {
#   name        = "feedback-app/db-credentials"
#   description = "DB credentials for feedback app RDS"
# }

# resource "aws_secretsmanager_secret_version" "db_credentials" {
#   secret_id     = aws_secretsmanager_secret.db_creds.id
#   secret_string = jsonencode({
#     username = "feedback_admin"
#     password = "SuperSecret123!"
#     dbname   = "feedbackdb"
#     host     = aws_db_instance.postgres.address
#     port     = aws_db_instance.postgres.port
#   })
# }

# # Subnet group for RDS
# resource "aws_db_subnet_group" "pg_subnet" {
#   name       = "feedback-db-subnet-group"
#   subnet_ids = data.aws_subnets.default.ids
# }

# # Security group for RDS
# resource "aws_security_group" "rds_sg" {
#   name   = "feedback-rds-sg"
#   vpc_id = data.aws_vpc.default.id

#   ingress {
#     from_port   = 5432
#     to_port     = 5432
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"] # ⚠️ For dev only — restrict in prod
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }


# # PostgreSQL DB
# resource "aws_db_instance" "postgres" {
#   identifier              = "feedback-postgres-db"
#   allocated_storage       = 20
#   engine                  = "postgres"
#   engine_version          = "16.4"
#   instance_class          = "db.t4g.micro"
#   db_name                 = "feedbackdb"
#   username                = "feedback_admin"
#   password                = random_password.db_password.result
#   port                    = 5432
#   publicly_accessible     = true
#   skip_final_snapshot     = true
#   db_subnet_group_name    = aws_db_subnet_group.pg_subnet.name
#   vpc_security_group_ids  = [aws_security_group.rds_sg.id]

#   backup_retention_period = 7
#   deletion_protection     = false
# }

# ########################################################
# # Outputs
# ########################################################
# output "rds_endpoint" {
#   value = aws_db_instance.postgres.endpoint
# }

# output "db_password" {
#   sensitive = true
#   value     = random_password.db_password.result
  
# }
# output "rds_url" {
#   sensitive = true
#   value = "postgresql://feedback_admin:${random_password.db_password.result}@${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/feedbackdb"
# }

# output "db_credentials_secret_arn" {
#   value = aws_secretsmanager_secret.db_creds.arn
# }


resource "aws_vpc" "feedback_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "feedback-vpc"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.feedback_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-south-1a"
  tags = { Name = "feedback-public-subnet" }
}
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.feedback_vpc.id
  cidr_block        = "10.0.10.0/24"   # changed to avoid conflict
  availability_zone = "ap-south-1a"
  tags = {
    Name = "private-subnet-1a"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.feedback_vpc.id
  cidr_block        = "10.0.11.0/24"   # changed to avoid conflict
  availability_zone = "ap-south-1b"
  tags = {
    Name = "private-subnet-1b"
  }
}


resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.feedback_vpc.id
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.feedback_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_security_group" "rds_sg" {
  name   = "feedback-rds-sg"
  vpc_id = aws_vpc.feedback_vpc.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["106.201.147.144/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "feedback-rds-sg" }
}
resource "aws_db_subnet_group" "pg_subnet" {
  name       = "feedback-db-subnet-group2"
  subnet_ids = [
    aws_subnet.private_subnet_1.id,
    aws_subnet.private_subnet_2.id
  ]
  tags = { Name = "feedback-db-subnet-group2" }
}

# PostgreSQL DB
resource "aws_db_instance" "postgres" {
  identifier              = "feedback-postgres-db"
  allocated_storage       = 20
  engine                  = "postgres"
  engine_version          = "16.10"
  instance_class          = "db.t4g.micro"
  db_name                 = "feedbackdb"
  username                = "feedback_admin"
  password                = "SuperSecret123"
  port                    = 5432

  db_subnet_group_name    = aws_db_subnet_group.pg_subnet.name
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]

  publicly_accessible     = true
  skip_final_snapshot     = true

  backup_retention_period = 7
  deletion_protection     = false


  tags = { Name = "feedback-postgres-db" }
}

output "rds_endpoint" {
  value = aws_db_instance.postgres.endpoint
}

output "rds_url" {
  sensitive = true
  value     = "postgresql://feedback_admin:SuperSecret123@${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/feedbackdb"
}

output "db_password" {
  sensitive = true
  value     = "SuperSecret123"
}
