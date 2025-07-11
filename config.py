"""Application configuration module"""

import os
from typing import Optional


class Settings:
    """Application settings configuration"""
    
    # Application settings
    APP_NAME: str = os.getenv("APP_NAME", "wudi")
    APP_VERSION: str = os.getenv("APP_VERSION", "0.1.0")
    DEBUG: bool = os.getenv("DEBUG", "false").lower() == "true"
    
    # Server settings
    HOST: str = os.getenv("HOST", "0.0.0.0")
    PORT: int = int(os.getenv("PORT", "8000"))
    RELOAD: bool = os.getenv("RELOAD", "false").lower() == "true"
    
    # Security settings
    SECRET_KEY: Optional[str] = os.getenv("SECRET_KEY")
    ALLOWED_HOSTS: list[str] = os.getenv("ALLOWED_HOSTS", "*").split(",")
    
    # Logging settings
    LOG_LEVEL: str = os.getenv("LOG_LEVEL", "INFO")
    
    # Template settings
    TEMPLATES_DIR: str = os.getenv("TEMPLATES_DIR", "templates")
    
    # Health check settings
    HEALTH_CHECK_ENABLED: bool = os.getenv("HEALTH_CHECK_ENABLED", "true").lower() == "true"
    
    # Git information
    GIT_COMMIT: str = os.getenv("GIT_COMMIT", "unknown")
    
    def __repr__(self) -> str:
        return f"<Settings app_name={self.APP_NAME} version={self.APP_VERSION}>"


# Global settings instance
settings = Settings()