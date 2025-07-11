import logging

from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates

from config import settings

# Configure logging
logging.basicConfig(
    level=getattr(logging, settings.LOG_LEVEL),
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)

# Initialize FastAPI app with configuration
app = FastAPI(
    title=settings.APP_NAME, version=settings.APP_VERSION, debug=settings.DEBUG
)

templates = Jinja2Templates(directory=settings.TEMPLATES_DIR)


@app.get(
    "/",
    response_class=HTMLResponse,
)
def index(request: Request):
    return templates.TemplateResponse(
        "index.html",
        {"request": request, "title": "首页", "message": "欢迎访问 FastAPI 网站!"},
    )


@app.get("/health")
def health_check():
    """Health check endpoint for container monitoring"""
    if not settings.HEALTH_CHECK_ENABLED:
        return {"status": "disabled"}

    return {
        "status": "healthy",
        "service": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "git_commit": settings.GIT_COMMIT,
    }


##########
if __name__ == "__main__":
    import uvicorn

    logger.info(f"Starting {settings.APP_NAME} v{settings.APP_VERSION}")
    logger.info(f"Git commit: {settings.GIT_COMMIT}")

    uvicorn.run(
        "main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.RELOAD,
        log_level=settings.LOG_LEVEL.lower(),
    )
