"""
Forex AlgoTrader - Configuration Settings
Professional trading robot settings with micro-account support
"""

import os
from typing import List, Optional
from pydantic_settings import BaseSettings
from pydantic import Field, validator


class Settings(BaseSettings):
    """Application settings loaded from environment variables"""
    
    # === MT5 Configuration ===
    mt5_login: int = Field(..., description="MT5 account number")
    mt5_password: str = Field(..., description="MT5 account password")
    mt5_server: str = Field(..., description="MT5 broker server")
    mt5_path: Optional[str] = Field(None, description="Path to MT5 terminal (Windows)")
    
    # === Trading Configuration ===
    account_size: float = Field(10.0, description="Account size in USD", ge=10.0)
    risk_per_trade: float = Field(2.0, description="Risk per trade (%)", ge=0.5, le=5.0)
    max_open_trades: int = Field(1, description="Maximum concurrent trades", ge=1, le=3)
    trading_symbols: List[str] = Field(
        default=["EURUSD", "GBPUSD", "XAUUSD"],
        description="Trading symbols"
    )
    
    # === Strategy Parameters - Aziz Xalikov v2.0 ===
    fractal_period: int = Field(5, description="Pivot lookback period", ge=2, le=10)
    max_bars_between: int = Field(30, description="Max bars between pivots", ge=5, le=100)
    max_channel_range: float = Field(0.0, description="Max channel width (0=unlimited)", ge=0.0)
    max_slope_atr: float = Field(0.15, description="Max channel slope (ATR)", ge=0.01, le=1.0)
    enforce_slope: bool = Field(True, description="Require reversal slope")
    
    rsi_length: int = Field(14, description="RSI period", ge=7, le=21)
    rsi_overbought: int = Field(70, description="RSI overbought level", ge=60, le=80)
    rsi_oversold: int = Field(30, description="RSI oversold level", ge=20, le=40)
    rsi_buffer: int = Field(5, description="RSI buffer zone", ge=0, le=10)
    
    sl_method: str = Field("Lookback", description="SL calculation method")
    sl_lookback: int = Field(20, description="SL lookback period", ge=5, le=100)
    sl_atr_mult: float = Field(1.5, description="SL ATR multiplier", ge=0.5, le=3.0)
    
    min_timeframe_minutes: int = Field(5, description="Minimum timeframe (minutes)", ge=1)
    
    # === API Configuration ===
    api_host: str = Field("0.0.0.0", description="API host")
    api_port: int = Field(8000, description="API port", ge=1000, le=65535)
    api_reload: bool = Field(False, description="Auto-reload on code changes")
    
    # === Database ===
    database_url: str = Field(
        "sqlite:///./backend/database/trades.db",
        description="Database connection URL"
    )
    
    # === Logging ===
    log_level: str = Field("INFO", description="Logging level")
    log_file: str = Field("./backend/logs/traderobot.log", description="Log file path")
    
    # === Telegram (Optional) ===
    telegram_bot_token: Optional[str] = Field(None, description="Telegram bot token")
    telegram_chat_id: Optional[str] = Field(None, description="Telegram chat ID")
    
    # === Safety Features ===
    demo_only: bool = Field(True, description="Demo account only mode")
    max_daily_loss: float = Field(10.0, description="Max daily loss (%)", ge=5.0, le=20.0)
    max_consecutive_losses: int = Field(3, description="Stop after X losses", ge=2, le=10)
    
    # Micro-account specific settings
    min_lot_size: float = Field(0.01, description="Minimum lot size", ge=0.01)
    max_lot_size: float = Field(0.1, description="Maximum lot size for micro accounts", ge=0.01, le=1.0)
    use_dynamic_lots: bool = Field(True, description="Calculate lot size dynamically")
    
    @validator("trading_symbols", pre=True)
    def parse_symbols(cls, v):
        """Parse comma-separated symbols from env var"""
        if isinstance(v, str):
            return [s.strip() for s in v.split(",")]
        return v
    
    @validator("sl_method")
    def validate_sl_method(cls, v):
        """Validate SL calculation method"""
        allowed = ["Kanal", "Lookback", "ATR"]
        if v not in allowed:
            raise ValueError(f"sl_method must be one of {allowed}")
        return v
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = False


# Global settings instance
settings: Optional[Settings] = None


def get_settings() -> Settings:
    """Get or create settings instance"""
    global settings
    if settings is None:
        settings = Settings()
    return settings


def load_settings() -> Settings:
    """Load settings from environment"""
    return Settings()
