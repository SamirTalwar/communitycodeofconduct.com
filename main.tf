terraform {
  backend "s3" {
    region = "eu-west-1"
    bucket = "infrastructure.noodlesandwich.com"
    key    = "terraform/state/communitycodeofconduct.com"
  }
}

locals {
  domain = "communitycodeofconduct.com"

  languages = [
    "en",
    "de",
    "es",
    "fi",
    "it",
    "jp",
    "pl",
    "tr",
  ]

  default_language = local.languages[0]

  distribution_domains = concat(
    [local.domain],
    formatlist("%s.%s", local.languages, local.domain),
  )

  distribution_prefixes = formatlist("/%s", concat([local.default_language], local.languages))
}

provider "aws" {
  region = "eu-west-1"
}

provider "cloudflare" {}

resource "aws_s3_bucket" "site" {
  bucket = local.domain
}

resource "aws_s3_bucket_object" "index_html" {
  count = length(local.languages)

  bucket       = aws_s3_bucket.site.bucket
  key          = "${local.languages[count.index]}/index.html"
  source       = "public/index-${local.languages[count.index]}.html"
  etag         = filemd5(format("public/index-%s.html", local.languages[count.index]))
  acl          = "public-read"
  content_type = "text/html; charset=utf-8"
}

resource "aws_s3_bucket_object" "favicon_ico" {
  count = length(local.languages)

  bucket       = aws_s3_bucket.site.bucket
  key          = "${local.languages[count.index]}/favicon.ico"
  source       = "public/favicon.ico"
  acl          = "public-read"
  content_type = "image/x-icon"
}

resource "aws_cloudfront_distribution" "site_distribution" {
  count = length(local.languages)

  enabled             = true
  default_root_object = "index.html"
  aliases = compact(
    [
      local.languages[count.index] == local.default_language ? local.domain : "",
      local.languages[count.index] == local.default_language ? format("www.%s", local.domain) : "",
      format("%s.%s", local.languages[count.index], local.domain),
    ],
  )

  origin {
    domain_name = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id   = "S3-${local.domain}"
    origin_path = "/${local.languages[count.index]}"
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${local.domain}"

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "cloudflare_zone" "site" {
  zone = local.domain
}

resource "cloudflare_record" "root" {
  zone_id = cloudflare_zone.site.id
  name    = "@"
  type    = "CNAME"
  value   = aws_cloudfront_distribution.site_distribution[0].domain_name
  proxied = true
}

resource "cloudflare_record" "www" {
  zone_id = cloudflare_zone.site.id
  name    = "www"
  type    = "CNAME"
  value   = local.domain
  proxied = true
}

resource "cloudflare_record" "language" {
  count = length(local.languages)

  zone_id = cloudflare_zone.site.id
  name    = local.languages[count.index]
  type    = "CNAME"
  value   = local.domain
  proxied = true
}

resource "cloudflare_page_rule" "always_use_https" {
  zone_id  = cloudflare_zone.site.id
  target   = "http://*${local.domain}/*"
  priority = 1

  actions {
    always_use_https = true
  }
}

resource "cloudflare_page_rule" "redirect_www" {
  zone_id  = cloudflare_zone.site.id
  target   = "www.${local.domain}/*"
  priority = 2

  actions {
    forwarding_url {
      url         = "https://${local.domain}/$1"
      status_code = 301
    }
  }
}
