"""
Data Manager - Real-time Market Data Fetching and Management
Handles OHLCV data, tick data, and technical indicator calculation
"""

import MetaTrader5 as mt5
import pandas as pd
import numpy as np
from typing import Optional, Dict, List, Tuple
from datetime import datetime, timedelta
from loguru import logger
import ta


class DataManager:
    """
    Professional market data manager for MT5
    Fetches and processes real-time and historical market data
    """
    
    # MT5 timeframe mapping
    TIMEFRAMES = {
        "M1": mt5.TIMEFRAME_M1,
        "M5": mt5.TIMEFRAME_M5,
        "M15": mt5.TIMEFRAME_M15,
        "M30": mt5.TIMEFRAME_M30,
        "H1": mt5.TIMEFRAME_H1,
        "H4": mt5.TIMEFRAME_H4,
        "D1": mt5.TIMEFRAME_D1,
        "W1": mt5.TIMEFRAME_W1,
    }
    
    def __init__(self, mt5_connector):
        """
        Initialize data manager
        
        Args:
            mt5_connector: MT5Connector instance
        """
        self.connector = mt5_connector
        logger.info("DataManager initialized")
    
    def get_bars(
        self,
        symbol: str,
        timeframe: str,
        count: int = 500,
        start_pos: int = 0
    ) -> Optional[pd.DataFrame]:
        """
        Get OHLCV bars from MT5
        
        Args:
            symbol: Trading symbol
            timeframe: Timeframe (M1, M5, M15, M30, H1, H4, D1, W1)
            count: Number of bars to retrieve
            start_pos: Start position (0 = current)
        
        Returns:
            DataFrame with OHLCV data or None if error
        """
        if not self.connector.ensure_connection():
            logger.error("MT5 connection not available")
            return None
        
        if timeframe not in self.TIMEFRAMES:
            logger.error(f"Invalid timeframe: {timeframe}")
            return None
        
        try:
            # Get bars from MT5
            rates = mt5.copy_rates_from_pos(
                symbol,
                self.TIMEFRAMES[timeframe],
                start_pos,
                count
            )
            
            if rates is None or len(rates) == 0:
                logger.error(f"No data received for {symbol} {timeframe}")
                return None
            
            # Convert to DataFrame
            df = pd.DataFrame(rates)
            df['time'] = pd.to_datetime(df['time'], unit='s')
            df.set_index('time', inplace=True)
            
            # Rename columns
            df.rename(columns={
                'open': 'Open',
                'high': 'High',
                'low': 'Low',
                'close': 'Close',
                'tick_volume': 'Volume'
            }, inplace=True)
            
            df = df[['Open', 'High', 'Low', 'Close', 'Volume']]
            
            logger.debug(f"Retrieved {len(df)} bars for {symbol} {timeframe}")
            return df
            
        except Exception as e:
            logger.exception(f"Error getting bars for {symbol}: {e}")
            return None
    
    def get_bars_range(
        self,
        symbol: str,
        timeframe: str,
        date_from: datetime,
        date_to: datetime
    ) -> Optional[pd.DataFrame]:
        """
        Get OHLCV bars for specific date range
        
        Args:
            symbol: Trading symbol
            timeframe: Timeframe
            date_from: Start date
            date_to: End date
        
        Returns:
            DataFrame with OHLCV data or None
        """
        if not self.connector.ensure_connection():
            return None
        
        if timeframe not in self.TIMEFRAMES:
            logger.error(f"Invalid timeframe: {timeframe}")
            return None
        
        try:
            rates = mt5.copy_rates_range(
                symbol,
                self.TIMEFRAMES[timeframe],
                date_from,
                date_to
            )
            
            if rates is None or len(rates) == 0:
                logger.error(f"No data for {symbol} from {date_from} to {date_to}")
                return None
            
            df = pd.DataFrame(rates)
            df['time'] = pd.to_datetime(df['time'], unit='s')
            df.set_index('time', inplace=True)
            
            df.rename(columns={
                'open': 'Open',
                'high': 'High',
                'low': 'Low',
                'close': 'Close',
                'tick_volume': 'Volume'
            }, inplace=True)
            
            df = df[['Open', 'High', 'Low', 'Close', 'Volume']]
            
            logger.debug(f"Retrieved {len(df)} bars for {symbol} {timeframe}")
            return df
            
        except Exception as e:
            logger.exception(f"Error getting bars range: {e}")
            return None
    
    def get_current_price(self, symbol: str) -> Optional[Tuple[float, float]]:
        """
        Get current bid and ask price
        
        Args:
            symbol: Trading symbol
        
        Returns:
            Tuple of (bid, ask) or None
        """
        if not self.connector.ensure_connection():
            return None
        
        try:
            symbol_info = mt5.symbol_info_tick(symbol)
            if symbol_info is None:
                logger.error(f"Failed to get tick for {symbol}")
                return None
            
            return (symbol_info.bid, symbol_info.ask)
            
        except Exception as e:
            logger.error(f"Error getting current price for {symbol}: {e}")
            return None
    
    def calculate_rsi(self, df: pd.DataFrame, period: int = 14) -> pd.Series:
        """
        Calculate RSI indicator
        
        Args:
            df: DataFrame with OHLCV data
            period: RSI period
        
        Returns:
            Series with RSI values
        """
        try:
            rsi = ta.momentum.RSIIndicator(close=df['Close'], window=period)
            return rsi.rsi()
        except Exception as e:
            logger.error(f"Error calculating RSI: {e}")
            return pd.Series(dtype=float)
    
    def calculate_atr(self, df: pd.DataFrame, period: int = 14) -> pd.Series:
        """
        Calculate ATR (Average True Range)
        
        Args:
            df: DataFrame with OHLCV data
            period: ATR period
        
        Returns:
            Series with ATR values
        """
        try:
            atr = ta.volatility.AverageTrueRange(
                high=df['High'],
                low=df['Low'],
                close=df['Close'],
                window=period
            )
            return atr.average_true_range()
        except Exception as e:
            logger.error(f"Error calculating ATR: {e}")
            return pd.Series(dtype=float)
    
    def find_pivot_highs(
        self,
        df: pd.DataFrame,
        left_bars: int = 5,
        right_bars: int = 5
    ) -> List[Tuple[int, float]]:
        """
        Find pivot high points in price data
        
        Args:
            df: DataFrame with OHLCV data
            left_bars: Number of bars to the left
            right_bars: Number of bars to the right
        
        Returns:
            List of (index, price) tuples for pivot highs
        """
        pivots = []
        highs = df['High'].values
        
        for i in range(left_bars, len(highs) - right_bars):
            is_pivot = True
            pivot_high = highs[i]
            
            # Check left side
            for j in range(i - left_bars, i):
                if highs[j] >= pivot_high:
                    is_pivot = False
                    break
            
            if not is_pivot:
                continue
            
            # Check right side
            for j in range(i + 1, i + right_bars + 1):
                if highs[j] > pivot_high:
                    is_pivot = False
                    break
            
            if is_pivot:
                pivots.append((i, pivot_high))
        
        return pivots
    
    def find_pivot_lows(
        self,
        df: pd.DataFrame,
        left_bars: int = 5,
        right_bars: int = 5
    ) -> List[Tuple[int, float]]:
        """
        Find pivot low points in price data
        
        Args:
            df: DataFrame with OHLCV data
            left_bars: Number of bars to the left
            right_bars: Number of bars to the right
        
        Returns:
            List of (index, price) tuples for pivot lows
        """
        pivots = []
        lows = df['Low'].values
        
        for i in range(left_bars, len(lows) - right_bars):
            is_pivot = True
            pivot_low = lows[i]
            
            # Check left side
            for j in range(i - left_bars, i):
                if lows[j] <= pivot_low:
                    is_pivot = False
                    break
            
            if not is_pivot:
                continue
            
            # Check right side
            for j in range(i + 1, i + right_bars + 1):
                if lows[j] < pivot_low:
                    is_pivot = False
                    break
            
            if is_pivot:
                pivots.append((i, pivot_low))
        
        return pivots
    
    def get_market_data_with_indicators(
        self,
        symbol: str,
        timeframe: str,
        count: int = 500,
        rsi_period: int = 14,
        atr_period: int = 14
    ) -> Optional[pd.DataFrame]:
        """
        Get market data with pre-calculated indicators
        
        Args:
            symbol: Trading symbol
            timeframe: Timeframe
            count: Number of bars
            rsi_period: RSI period
            atr_period: ATR period
        
        Returns:
            DataFrame with OHLCV + indicators or None
        """
        df = self.get_bars(symbol, timeframe, count)
        if df is None or df.empty:
            return None
        
        try:
            # Calculate RSI
            df['RSI'] = self.calculate_rsi(df, rsi_period)
            
            # Calculate ATR
            df['ATR'] = self.calculate_atr(df, atr_period)
            
            # Remove NaN values from indicators
            df.dropna(inplace=True)
            
            logger.debug(f"Added indicators to {symbol} {timeframe} data")
            return df
            
        except Exception as e:
            logger.error(f"Error adding indicators: {e}")
            return df
    
    def validate_symbol(self, symbol: str) -> bool:
        """
        Validate if symbol is available for trading
        
        Args:
            symbol: Trading symbol
        
        Returns:
            bool: True if valid
        """
        symbol_info = self.connector.get_symbol_info(symbol)
        if symbol_info is None:
            logger.error(f"Symbol {symbol} is not available")
            return False
        
        logger.info(f"✅ Symbol {symbol} validated - Spread: {symbol_info['spread']} points")
        return True
    
    def get_symbol_point_value(self, symbol: str) -> Optional[float]:
        """
        Get the point value for a symbol
        
        Args:
            symbol: Trading symbol
        
        Returns:
            float: Point value or None
        """
        symbol_info = self.connector.get_symbol_info(symbol)
        if symbol_info is None:
            return None
        
        return symbol_info['point']
    
    def get_symbol_digits(self, symbol: str) -> Optional[int]:
        """
        Get decimal digits for symbol price
        
        Args:
            symbol: Trading symbol
        
        Returns:
            int: Number of decimal digits or None
        """
        symbol_info = self.connector.get_symbol_info(symbol)
        if symbol_info is None:
            return None
        
        return symbol_info['digits']
