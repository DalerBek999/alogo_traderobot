"""
MT5 Connector - Professional MetaTrader 5 Connection Manager
Handles connection, authentication, and error recovery
"""

import MetaTrader5 as mt5
from typing import Optional, Dict, List, Tuple
from datetime import datetime
import time
from loguru import logger


class MT5Connector:
    """
    Professional MT5 connection manager with automatic reconnection
    and comprehensive error handling for production trading
    """
    
    def __init__(
        self,
        login: int,
        password: str,
        server: str,
        path: Optional[str] = None,
        timeout: int = 60000
    ):
        """
        Initialize MT5 connector
        
        Args:
            login: MT5 account number
            password: MT5 account password
            server: Broker server name
            path: Path to MT5 terminal (Windows only)
            timeout: Connection timeout in milliseconds
        """
        self.login = login
        self.password = password
        self.server = server
        self.path = path
        self.timeout = timeout
        self.is_connected = False
        self._connection_attempts = 0
        self._max_reconnect_attempts = 5
        
        logger.info(f"MT5Connector initialized for account {login} on {server}")
    
    def connect(self) -> bool:
        """
        Establish connection to MT5 terminal
        
        Returns:
            bool: True if connection successful, False otherwise
        """
        try:
            # Initialize MT5 connection
            if self.path:
                if not mt5.initialize(path=self.path, timeout=self.timeout):
                    logger.error(f"MT5 initialize failed: {mt5.last_error()}")
                    return False
            else:
                if not mt5.initialize(timeout=self.timeout):
                    logger.error(f"MT5 initialize failed: {mt5.last_error()}")
                    return False
            
            logger.info("MT5 terminal initialized successfully")
            
            # Login to trading account
            if not mt5.login(login=self.login, password=self.password, server=self.server):
                error = mt5.last_error()
                logger.error(f"MT5 login failed: {error}")
                mt5.shutdown()
                return False
            
            self.is_connected = True
            self._connection_attempts = 0
            
            # Log account info
            account_info = mt5.account_info()
            if account_info:
                logger.success(f"✅ Connected to MT5 account {self.login}")
                logger.info(f"Account balance: ${account_info.balance:.2f}")
                logger.info(f"Account equity: ${account_info.equity:.2f}")
                logger.info(f"Account type: {'DEMO' if account_info.trade_mode == 0 else 'REAL'}")
            
            return True
            
        except Exception as e:
            logger.exception(f"MT5 connection error: {e}")
            self.is_connected = False
            return False
    
    def disconnect(self) -> None:
        """Safely disconnect from MT5"""
        try:
            if self.is_connected:
                mt5.shutdown()
                self.is_connected = False
                logger.info("MT5 connection closed")
        except Exception as e:
            logger.error(f"Error during MT5 disconnect: {e}")
    
    def reconnect(self) -> bool:
        """
        Attempt to reconnect to MT5
        
        Returns:
            bool: True if reconnection successful
        """
        if self._connection_attempts >= self._max_reconnect_attempts:
            logger.error(f"Max reconnection attempts ({self._max_reconnect_attempts}) reached")
            return False
        
        self._connection_attempts += 1
        logger.warning(f"Attempting to reconnect... (Attempt {self._connection_attempts})")
        
        self.disconnect()
        time.sleep(2 ** self._connection_attempts)  # Exponential backoff
        
        return self.connect()
    
    def ensure_connection(self) -> bool:
        """
        Ensure MT5 connection is active, reconnect if necessary
        
        Returns:
            bool: True if connected
        """
        if not self.is_connected:
            return self.reconnect()
        
        # Test connection with a ping
        try:
            account_info = mt5.account_info()
            if account_info is None:
                logger.warning("MT5 connection lost, reconnecting...")
                return self.reconnect()
            return True
        except Exception as e:
            logger.error(f"Connection check failed: {e}")
            return self.reconnect()
    
    def get_account_info(self) -> Optional[Dict]:
        """
        Get current account information
        
        Returns:
            dict: Account information or None if error
        """
        if not self.ensure_connection():
            return None
        
        try:
            account_info = mt5.account_info()
            if account_info is None:
                return None
            
            return {
                "login": account_info.login,
                "balance": account_info.balance,
                "equity": account_info.equity,
                "margin": account_info.margin,
                "margin_free": account_info.margin_free,
                "margin_level": account_info.margin_level,
                "profit": account_info.profit,
                "leverage": account_info.leverage,
                "trade_mode": "DEMO" if account_info.trade_mode == 0 else "REAL",
                "currency": account_info.currency,
            }
        except Exception as e:
            logger.error(f"Error getting account info: {e}")
            return None
    
    def get_symbol_info(self, symbol: str) -> Optional[Dict]:
        """
        Get symbol information
        
        Args:
            symbol: Trading symbol (e.g., EURUSD)
        
        Returns:
            dict: Symbol information or None if error
        """
        if not self.ensure_connection():
            return None
        
        try:
            symbol_info = mt5.symbol_info(symbol)
            if symbol_info is None:
                logger.error(f"Symbol {symbol} not found")
                return None
            
            # Enable symbol in MarketWatch if not visible
            if not symbol_info.visible:
                if not mt5.symbol_select(symbol, True):
                    logger.error(f"Failed to enable symbol {symbol}")
                    return None
            
            return {
                "symbol": symbol_info.name,
                "bid": symbol_info.bid,
                "ask": symbol_info.ask,
                "spread": symbol_info.spread,
                "digits": symbol_info.digits,
                "point": symbol_info.point,
                "trade_contract_size": symbol_info.trade_contract_size,
                "volume_min": symbol_info.volume_min,
                "volume_max": symbol_info.volume_max,
                "volume_step": symbol_info.volume_step,
                "currency_base": symbol_info.currency_base,
                "currency_profit": symbol_info.currency_profit,
            }
        except Exception as e:
            logger.error(f"Error getting symbol info for {symbol}: {e}")
            return None
    
    def get_terminal_info(self) -> Optional[Dict]:
        """
        Get MT5 terminal information
        
        Returns:
            dict: Terminal info or None
        """
        if not self.ensure_connection():
            return None
        
        try:
            terminal_info = mt5.terminal_info()
            if terminal_info is None:
                return None
            
            return {
                "connected": terminal_info.connected,
                "trade_allowed": terminal_info.trade_allowed,
                "tradeapi_disabled": terminal_info.tradeapi_disabled,
                "balance": terminal_info.balance,
                "equity": terminal_info.equity,
                "profit": terminal_info.profit,
                "company": terminal_info.company,
                "name": terminal_info.name,
            }
        except Exception as e:
            logger.error(f"Error getting terminal info: {e}")
            return None
    
    def check_trading_allowed(self) -> bool:
        """
        Check if trading is allowed
        
        Returns:
            bool: True if trading is allowed
        """
        terminal_info = self.get_terminal_info()
        if terminal_info is None:
            return False
        
        if not terminal_info["connected"]:
            logger.error("MT5 terminal not connected to trade server")
            return False
        
        if not terminal_info["trade_allowed"]:
            logger.error("Trading is not allowed in terminal")
            return False
        
        if terminal_info["tradeapi_disabled"]:
            logger.error("Trade API is disabled")
            return False
        
        return True
    
    def get_open_positions(self, symbol: Optional[str] = None) -> List[Dict]:
        """
        Get all open positions
        
        Args:
            symbol: Filter by symbol (optional)
        
        Returns:
            list: List of open positions
        """
        if not self.ensure_connection():
            return []
        
        try:
            if symbol:
                positions = mt5.positions_get(symbol=symbol)
            else:
                positions = mt5.positions_get()
            
            if positions is None:
                return []
            
            return [
                {
                    "ticket": pos.ticket,
                    "symbol": pos.symbol,
                    "type": "BUY" if pos.type == 0 else "SELL",
                    "volume": pos.volume,
                    "price_open": pos.price_open,
                    "price_current": pos.price_current,
                    "sl": pos.sl,
                    "tp": pos.tp,
                    "profit": pos.profit,
                    "swap": pos.swap,
                    "comment": pos.comment,
                    "time": datetime.fromtimestamp(pos.time),
                }
                for pos in positions
            ]
        except Exception as e:
            logger.error(f"Error getting positions: {e}")
            return []
    
    def get_orders(self, symbol: Optional[str] = None) -> List[Dict]:
        """
        Get pending orders
        
        Args:
            symbol: Filter by symbol (optional)
        
        Returns:
            list: List of pending orders
        """
        if not self.ensure_connection():
            return []
        
        try:
            if symbol:
                orders = mt5.orders_get(symbol=symbol)
            else:
                orders = mt5.orders_get()
            
            if orders is None:
                return []
            
            return [
                {
                    "ticket": order.ticket,
                    "symbol": order.symbol,
                    "type": order.type,
                    "volume": order.volume,
                    "price_open": order.price_open,
                    "sl": order.sl,
                    "tp": order.tp,
                    "time_setup": datetime.fromtimestamp(order.time_setup),
                    "comment": order.comment,
                }
                for order in orders
            ]
        except Exception as e:
            logger.error(f"Error getting orders: {e}")
            return []
    
    def __enter__(self):
        """Context manager entry"""
        self.connect()
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit"""
        self.disconnect()
    
    def __del__(self):
        """Destructor - ensure clean disconnect"""
        try:
            self.disconnect()
        except:
            pass
