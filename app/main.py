"""
Noddy Solutions - company landing page.

A minimal FastAPI application that runs in two modes:
  * locally, served by uvicorn  (`uvicorn app.main:app --reload`)
  * on AWS Lambda behind API Gateway HTTP API, via the Mangum ASGI adapter
    (Lambda handler: `app.main.handler`)
"""

import os
from datetime import datetime, timezone
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from mangum import Mangum

BASE_DIR = Path(__file__).resolve().parent

# Shared secret injected by CloudFront as a custom origin header. When it is
# set, requests that bypass CloudFront (e.g. hitting the raw API Gateway URL)
# are rejected. Left empty for local development.
ORIGIN_VERIFY_SECRET = os.environ.get("ORIGIN_VERIFY_SECRET", "")
ORIGIN_VERIFY_HEADER = "x-origin-verify"

COMPANY = {
    "name": os.environ.get("COMPANY_NAME", "Noddy Solutions"),
    "tagline": "Cloud-native software, delivered at global scale.",
    "email": "hello@noddy-solutions.example",
}

SERVICES = [
    {"icon": "☁", "title": "Cloud Architecture",
     "text": "Resilient, multi-AZ designs on AWS that scale with your business."},
    {"icon": "⚡", "title": "Serverless Engineering",
     "text": "Event-driven backends with zero idle cost and instant elasticity."},
    {"icon": "🛡", "title": "Security & Compliance",
     "text": "Least-privilege IAM, edge protection and auditable infrastructure."},
    {"icon": "⚙", "title": "DevOps & IaC",
     "text": "Reproducible environments defined entirely in Terraform."},
]

app = FastAPI(title=COMPANY["name"], docs_url=None, redoc_url=None)
app.mount("/static", StaticFiles(directory=BASE_DIR / "static"), name="static")
templates = Jinja2Templates(directory=BASE_DIR / "templates")


@app.middleware("http")
async def verify_origin(request: Request, call_next):
    """Only accept traffic that has passed through CloudFront."""
    if ORIGIN_VERIFY_SECRET and request.headers.get(ORIGIN_VERIFY_HEADER) != ORIGIN_VERIFY_SECRET:
        return JSONResponse({"detail": "Forbidden"}, status_code=403)
    return await call_next(request)


@app.get("/", response_class=HTMLResponse)
async def landing(request: Request):
    """Render the single-page company landing site."""
    response = templates.TemplateResponse(
        request,
        "index.html",
        {"company": COMPANY, "services": SERVICES, "year": datetime.now(timezone.utc).year},
    )
    # Allow CloudFront to cache the page briefly at the edge.
    response.headers["Cache-Control"] = "public, max-age=300"
    return response


@app.get("/health")
async def health():
    """Lightweight liveness probe (never cached)."""
    return JSONResponse(
        {"status": "ok", "region": os.environ.get("AWS_REGION", "local")},
        headers={"Cache-Control": "no-store"},
    )


# AWS Lambda entry point. Lifespan events are disabled because Lambda
# execution environments have no long-lived startup/shutdown cycle.
handler = Mangum(app, lifespan="off")
