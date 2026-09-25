# Noddy Solutions — Serverless FastAPI Landing Page on AWS

```
Visitor ─► Route 53 ─► CloudFront (+ WAF) ─► API Gateway HTTP API ─► Lambda (FastAPI + Mangum)
```

| Path | Contents |
|------|----------|
| `app/` | FastAPI application (`main.py`), Jinja2 landing page, CSS |
| `scripts/build_lambda.sh` | Builds `build/lambda.zip` with Linux/arm64 wheels |
| `terraform/` | Root module (`main.tf`, `variables.tf`, `outputs.tf`, `terraform.tfvars`, `versions.tf`) |
| `terraform/modules/` | `lambda`, `api_gateway`, `cdn` (CloudFront + WAF), `certificate` (ACM), `dns` (Route 53) |
| `docs/` | `Abstract.docx`, `Technical_Report.docx` (+ PDF previews) |

## Run locally

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r app/requirements.txt uvicorn
uvicorn app.main:app --reload     # http://127.0.0.1:8000
```

> Use Python 3.12 or 3.13 locally. Mangum 0.19 calls `asyncio.get_event_loop()`, which
> fails on Python 3.14 when no loop exists. The Lambda runtime is pinned to 3.12.

## Deploy

```bash
./scripts/build_lambda.sh                 # -> build/lambda.zip
cd terraform
terraform init
terraform plan -out=tfplan
terraform apply tfplan
terraform output website_url
```

For a custom domain, set `domain_name`, `subject_alternative_names` and `hosted_zone_id`
in `terraform.tfvars`. Without them, the site is served on the `*.cloudfront.net` domain.

To update, rebuild the zip and run `terraform apply` again (this publishes a new Lambda version and moves the `live` alias).
To remove everything: `terraform destroy`.
