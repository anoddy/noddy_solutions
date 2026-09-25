# Noddy Solutions — FastAPI Website on AWS

This project hosts a simple FastAPI website for Noddy Solutions on AWS. I used Terraform to define the cloud setup and Docker to build the Lambda package on Windows.

## Architecture

Requests go from the visitor to CloudFront, then through API Gateway's HTTP API to Lambda when the requested content is not cached. Lambda runs FastAPI using the Mangum adapter.

- **CloudFront:** serves the website over HTTPS and caches suitable content closer to visitors.
- **API Gateway HTTP API:** sends backend requests to Lambda.
- **Lambda:** runs the Python application and scales with demand, within AWS quotas and configured limits.
- **IAM:** defines permissions for the application resources.
- **CloudWatch:** collects logs and metrics used to check the application.

The backend is deployed in **eu-central-1 (Frankfurt)**. The website uses the default CloudFront address, so this deployment does not use Route 53 or a separate ACM certificate. The Terraform code includes optional custom-domain and WAF support.

CloudFront adds a secret `x-origin-verify` header to requests sent to the backend. FastAPI checks its value and rejects requests without the correct value. Terraform generates this secret and passes it to both services. The API endpoint is still publicly reachable; the application performs the check.

WAF was included in the concept but disabled for this deployment by setting `enable_waf = false` in the local `terraform.tfvars`. I made this decision to avoid its ongoing charges for a student test deployment. WAF can be enabled later by changing that setting and applying the Terraform changes.

## Project files

| Path | Contents |
|------|----------|
| `app/main.py` | FastAPI application, page route, health endpoint and origin-header check |
| `app/templates/index.html` | Website template |
| `app/static/styles.css` | Website styles |
| `app/requirements.txt` | Python dependencies |
| `scripts/build_lambda.sh` | Builds `build/lambda.zip` with Python 3.12 Linux/arm64 dependencies |
| `terraform/` | Main Terraform configuration, variables, outputs and provider requirements |
| `terraform/modules/` | Lambda, API Gateway, CloudFront, optional certificate and DNS modules |
| `terraform/.terraform.lock.hcl` | Provider dependency lock file |

The local `terraform.tfvars`, Terraform state, saved plans, build files and virtual environment should be kept out of Git. Terraform state contains the generated origin secret, so keep the state files private and retain them to manage or remove the deployment.

## Prerequisites

The commands below use **Windows PowerShell**. Run commands one at a time and check that each finishes successfully.

- Terraform installed and available in the terminal.
- AWS CLI installed, with valid credentials for an account that can create the resources in this configuration.
- Docker Desktop installed and running with Linux containers.
- Python 3.12 installed if you want to run the website locally. Docker provides Python 3.12 for the packaging step.
- Git installed if cloning or updating the repository with Git.

Check the tools and AWS connection:

```powershell
terraform version
aws --version
docker info
aws sts get-caller-identity
```

Check that the AWS identity belongs to the account you intend to deploy into. If the credentials have expired, sign in again using your configured authentication method.

## Get the project

For a new copy:

```powershell
git clone https://github.com/anoddy/noddy_solutions.git
cd noddy_solutions
```

If you already have the project open in VS Code, use its existing folder. The **project root** is the folder containing `README.md`, `app`, `scripts` and `terraform`.

## Run locally (optional)

From the project root, create and activate a Python 3.12 virtual environment:

```powershell
py -3.12 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r app/requirements.txt uvicorn
python -m uvicorn app.main:app --reload
```

Open <http://127.0.0.1:8000> in your browser. Press **Ctrl+C** in the terminal to stop the local server.

If PowerShell blocks the activation script, use the environment's Python directly:

```powershell
.\.venv\Scripts\python.exe -m pip install -r app/requirements.txt uvicorn
.\.venv\Scripts\python.exe -m uvicorn app.main:app --reload
```

For local development, leave the `ORIGIN_VERIFY_SECRET` environment variable unset. Terraform configures it for the deployed Lambda function.

## Configure the deployment

For a new deployment, create a file called `terraform.tfvars` inside the `terraform` folder with these settings:

```hcl
project_name = "noddys-cloud"
aws_region   = "eu-central-1"
company_name = "Noddy Solutions"

enable_waf = false

domain_name               = ""
subject_alternative_names = []
hosted_zone_id            = ""
```

If you already have this file, check the relevant settings and keep any other settings needed for your existing deployment. The empty domain settings use the default CloudFront URL with HTTPS. Set `enable_waf = false` explicitly; do not rely on the variable's default value.

Keep the Lambda runtime as `python3.12` and architecture as `arm64`, which match the build script. Do not put AWS access keys into this file or the application code.

## Build the Lambda package on Windows

Start Docker Desktop and wait for its engine to run. From the **project root**, run this command in PowerShell:

```powershell
docker run --rm --mount "type=bind,source=$($PWD.Path),target=/workspace" -w /workspace python:3.12-bookworm bash -c "apt-get update -qq && apt-get install -y -qq --no-install-recommends rsync zip >/dev/null && bash scripts/build_lambda.sh"
```

Docker downloads the image if it is not already available. The command runs `scripts/build_lambda.sh` inside a Linux container and creates **`build/lambda.zip`**. Wait for the build to finish successfully before deploying.

## Deploy with Terraform

From the project root, run:

```powershell
cd terraform
terraform init
terraform validate
terraform plan -out=tfplan
```

Review the plan, including the resources being created or changed. For this configuration, WAF, Route 53 records and a custom ACM certificate should not be created. AWS resources can incur charges while deployed.

Apply the reviewed plan and get the website address:

```powershell
terraform apply tfplan
terraform output website_url
```

Open the returned HTTPS address in your browser. CloudFront deployment can take several minutes.

## Verify the deployment

Run these commands in PowerShell from the **`terraform` folder** after deployment.

### 1. Check the backend through CloudFront

```powershell
$websiteUrl = terraform output -raw website_url
curl.exe -i "$websiteUrl/health"
```

Expected result: HTTP `200` with a response containing `"status":"ok"` and `"region":"eu-central-1"`. The `/health` route is not cached.

### 2. Check caching

Run both commands against the same URL:

```powershell
curl.exe -sS -D - -o NUL "$websiteUrl/"
curl.exe -sS -D - -o NUL "$websiteUrl/"
```

These send normal GET requests and display the response headers. Look for HTTP `200` and `X-Cache: Hit from cloudfront` on a repeated request. The first request may already be a hit if the page is cached. Otherwise, it may show a miss before a later request shows a hit.

### 3. Check direct backend access

```powershell
$apiEndpoint = terraform output -raw api_endpoint
curl.exe -i "$apiEndpoint/"
```

Expected result: HTTP `403 Forbidden`, because this request does not include the correct origin-verification header.

### 4. Check Lambda metrics

In the AWS Console, select **eu-central-1 (Frankfurt)** and open the project's Lambda function. Its name is available with:

```powershell
terraform output lambda_function_name
```

Use the function's monitoring view or CloudWatch to inspect **ConcurrentExecutions** with the Maximum statistic, **Invocations**, **Errors**, **Throttles** and **Duration**. Set the time range to include your test. Metrics can take a few minutes to appear.

For a concurrency test, send overlapping requests through CloudFront to `/health`, so the requests reach Lambda instead of being answered from the cache. Successful requests alone do not prove that concurrency increased; check the graph alongside response times and errors.

## Update the website

1. Edit and save the application, template or CSS files.
2. Run the Docker build command again from the project root.
3. From the `terraform` folder, run:

```powershell
terraform plan -out=tfplan
terraform apply tfplan
```

Review the plan before applying it. A changed Lambda package is deployed through Terraform, which publishes a new Lambda version and updates the `live` alias.

Check the website afterwards. CloudFront or the browser may still have an older response cached. For the HTML page, allow its five-minute cache lifetime to expire; static files can remain cached longer. If an immediate refresh is needed, run a CloudFront invalidation from the `terraform` folder:

```powershell
$distributionId = terraform output -raw cloudfront_distribution_id
aws cloudfront create-invalidation --distribution-id $distributionId --paths "/*"
```

Wait for the invalidation to complete and refresh the browser. Invalidations can incur charges beyond the applicable allowance.

## Limitations and optional features

- The backend is in one AWS region, so a complete regional outage remains a limitation.
- Normal website and load tests do not prove that the application survives an Availability Zone outage.
- Caching improves repeat requests but cannot remove every delay. Requests that reach Lambda can also experience cold starts.
- Scaling is subject to Lambda concurrency limits, API Gateway throttling and AWS account quotas.
- WAF is disabled for this deployment. The secret-header check does not replace WAF or user authentication.
- A custom domain can be configured with `domain_name`, `subject_alternative_names` and an existing Route 53 `hosted_zone_id`. This enables the optional certificate and DNS modules.

## Remove the deployment

When the deployment is no longer needed, run this from the **`terraform` folder** using the same AWS account, configuration and Terraform state:

```powershell
terraform destroy
```

Review the resources listed and confirm only when you are ready to take the website offline. Wait for the command to finish and check that the project resources have been removed.