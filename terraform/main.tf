provider "aws" {
  region  = "ap-south-1"
}

resource "aws_s3_bucket" "my_bucket" {
  bucket         = "frontend-deployment-bucket-mentorship"
  # force_destroy  = true
  # tags = {
  #   Name = "Pratham_mentorship"
  # }
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

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "404.html"
  }

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
      "s3:GetObject",
      "s3:ListBucket"
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

# # 1. Configure static website hosting
# resource "aws_s3_bucket_website_configuration" "frontend_site" {
#   bucket = "terraform-mentoring-bucket"

#   index_document {
#     suffix = "index.html"
#   }

#   error_document {
#     key = "index.html"
#   }
# }

# # 2. Disable Block Public Access settings
# resource "aws_s3_bucket_public_access_block" "frontend" {
#   bucket = "terraform-mentoring-bucket"

#   block_public_acls       = false
#   block_public_policy     = false
#   ignore_public_acls      = false
#   restrict_public_buckets = false
# }

# # 3. Public read access to objects
# resource "aws_s3_bucket_policy" "frontend" {
#   bucket = "terraform-mentoring-bucket"

#   depends_on = [aws_s3_bucket_public_access_block.frontend] # 👈 ensure order

#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Sid       = "PublicReadGetObject",
#         Effect    = "Allow",
#         Principal = "*",
#         Action    = "s3:GetObject",
#         Resource  = "arn:aws:s3:::terraform-mentoring-bucket/*"
#       }
#     ]
#   })
# }