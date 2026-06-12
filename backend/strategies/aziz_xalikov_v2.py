"""
Aziz Xalikov Strategy v2.0 - Parallel Channel Breakout with RSI Divergence
Professional implementation of the TradingView Pine Script strategy
Author: Takrorlanmas Robotlar
"""

import pandas as pd
import numpy as np
from typing import Optional, Dict, List, Tuple
from dataclasses import dataclass
from datetime import datetime
from loguru import logger


@dataclass
class ChannelInfo:
    """Information about detected parallel channel"""
    channel_type: str  # "bullish" or "bearish"
    pivot1_idx: int
    pivot1_price: float
    pivot2_idx: int
    pivot2_price: float
    slope: float
    extreme_idx: int  # Min low (bullish) or Max high (bearish)
    extreme_price: float
    confirmed_bar: int
    rsi_at_extreme: float
    has_divergence: bool
    is_valid: bool


@dataclass
class TradeSignal:
    """Trade signal with all necessary information"""
    signal_type: str  # "BUY" or "SELL"
    symbol: str
    entry_price: float
    stop_loss: float
    take_profit_1: float
    take_profit_2: float
    risk_amount: float
    channel_info: ChannelInfo
    timestamp: datetime
    reason: str  # Signal generation reason


class AzizXalikovStrategyV2:
    """
    Aziz Xalikov v2.0 Strategy - Parallel Channel Breakout
    
    Strategy Logic:
    1. Detect pivot highs/lows using fractal analysis
    2. Form parallel channels from consecutive pivots
    3. Confirm with RSI oversold/overbought or divergence
    4. Generate BUY signal on bullish channel breakout (upward)
    5. Generate SELL signal on bearish channel breakout (downward)
    6. Entry: Current bar open (immediate execution)
    7. SL: Channel-based, Lookback, or ATR method
    8. TP: 1R and 2R targets
    """
    
    def __init__(
        self,
        fractal_period: int = 5,
        max_bars_between: int = 30,
        max_channel_range: float = 0.0,
        max_slope_atr: float = 0.15,
        enforce_slope: bool = True,
        rsi_length: int = 14,
        rsi_overbought: int = 70,
        rsi_oversold: int = 30,
        rsi_buffer: int = 5,
        sl_method: str = "Lookback",
        sl_lookback: int = 20,
        sl_atr_mult: float = 1.5,
        min_timeframe_minutes: int = 5
    ):
        """
        Initialize Aziz Xalikov Strategy v2.0
        
        Args:
            fractal_period: Pivot lookback period (left and right bars)
            max_bars_between: Maximum bars between consecutive pivots
            max_channel_range: Max channel height (0 = unlimited)
            max_slope_atr: Maximum channel slope in ATR units
            enforce_slope: Require reversal slope (bullish down, bearish up)
            rsi_length: RSI period
            rsi_overbought: RSI overbought level
            rsi_oversold: RSI oversold level
            rsi_buffer: RSI buffer zone
            sl_method: Stop loss method ("Kanal", "Lookback", "ATR")
            sl_lookback: Lookback period for SL calculation
            sl_atr_mult: ATR multiplier for SL
            min_timeframe_minutes: Minimum timeframe filter
        """
        self.fractal_period = fractal_period
        self.max_bars_between = max_bars_between
        self.max_channel_range = max_channel_range
        self.max_slope_atr = max_slope_atr
        self.enforce_slope = enforce_slope
        
        self.rsi_length = rsi_length
        self.rsi_overbought = rsi_overbought
        self.rsi_oversold = rsi_oversold
        self.rsi_buffer = rsi_buffer
        
        self.sl_method = sl_method
        self.sl_lookback = sl_lookback
        self.sl_atr_mult = sl_atr_mult
        
        self.min_timeframe_minutes = min_timeframe_minutes
        
        # State tracking
        self.active_bull_channel: Optional[ChannelInfo] = None
        self.active_bear_channel: Optional[ChannelInfo] = None
        
        logger.info(f"Aziz Xalikov v2.0 Strategy initialized: "
                   f"Fractal={fractal_period}, RSI={rsi_length}, SL={sl_method}")
    
    def find_pivot_highs(self, df: pd.DataFrame) -> List[Tuple[int, float, float]]:
        """
        Find pivot high points with RSI values
        
        Args:
            df: DataFrame with OHLCV and RSI data
        
        Returns:
            List of (index, price, rsi_value) tuples
        """
        pivots = []
        highs = df['High'].values
        rsi_values = df['RSI'].values
        
        for i in range(self.fractal_period, len(highs) - self.fractal_period):
            is_pivot = True
            pivot_high = highs[i]
            
            # Check left side
            for j in range(i - self.fractal_period, i):
                if highs[j] >= pivot_high:
                    is_pivot = False
                    break
            
            if not is_pivot:
                continue
            
            # Check right side
            for j in range(i + 1, i + self.fractal_period + 1):
                if highs[j] > pivot_high:
                    is_pivot = False
                    break
            
            if is_pivot:
                pivots.append((i, pivot_high, rsi_values[i]))
        
        return pivots
    
    def find_pivot_lows(self, df: pd.DataFrame) -> List[Tuple[int, float, float]]:
        """
        Find pivot low points with RSI values
        
        Args:
            df: DataFrame with OHLCV and RSI data
        
        Returns:
            List of (index, price, rsi_value) tuples
        """
        pivots = []
        lows = df['Low'].values
        rsi_values = df['RSI'].values
        
        for i in range(self.fractal_period, len(lows) - self.fractal_period):
            is_pivot = True
            pivot_low = lows[i]
            
            # Check left side
            for j in range(i - self.fractal_period, i):
                if lows[j] <= pivot_low:
                    is_pivot = False
                    break
            
            if not is_pivot:
                continue
            
            # Check right side
            for j in range(i + 1, i + self.fractal_period + 1):
                if lows[j] < pivot_low:
                    is_pivot = False
                    break
            
            if is_pivot:
                pivots.append((i, pivot_low, rsi_values[i]))
        
        return pivots
    
    def detect_bullish_divergence(
        self,
        lp1_idx: int, lp1_price: float, lp1_rsi: float,
        lp2_idx: int, lp2_price: float, lp2_rsi: float
    ) -> bool:
        """
        Detect bullish divergence (price lower low, RSI higher low)
        
        Args:
            lp1_idx, lp1_price, lp1_rsi: First pivot low data
            lp2_idx, lp2_price, lp2_rsi: Second pivot low data
        
        Returns:
            bool: True if bullish divergence detected
        """
        # Price makes lower low, RSI makes higher low
        has_divergence = (lp2_price < lp1_price) and (lp2_rsi > lp1_rsi)
        
        if has_divergence:
            logger.info(f"✅ Bullish Divergence: Price {lp1_price:.5f} → {lp2_price:.5f}, "
                       f"RSI {lp1_rsi:.2f} → {lp2_rsi:.2f}")
        
        return has_divergence
    
    def detect_bearish_divergence(
        self,
        hp1_idx: int, hp1_price: float, hp1_rsi: float,
        hp2_idx: int, hp2_price: float, hp2_rsi: float
    ) -> bool:
        """
        Detect bearish divergence (price higher high, RSI lower high)
        
        Args:
            hp1_idx, hp1_price, hp1_rsi: First pivot high data
            hp2_idx, hp2_price, hp2_rsi: Second pivot high data
        
        Returns:
            bool: True if bearish divergence detected
        """
        # Price makes higher high, RSI makes lower high
        has_divergence = (hp2_price > hp1_price) and (hp2_rsi < hp1_rsi)
        
        if has_divergence:
            logger.info(f"✅ Bearish Divergence: Price {hp1_price:.5f} → {hp2_price:.5f}, "
                       f"RSI {hp1_rsi:.2f} → {hp2_rsi:.2f}")
        
        return has_divergence
    
    def detect_bullish_channel(
        self,
        df: pd.DataFrame,
        pivot_highs: List[Tuple[int, float, float]]
    ) -> Optional[ChannelInfo]:
        """
        Detect bullish parallel channel from pivot highs
        
        Args:
            df: DataFrame with OHLCV and indicators
            pivot_highs: List of pivot highs with RSI
        
        Returns:
            ChannelInfo or None
        """
        if len(pivot_highs) < 2:
            return None
        
        # Get last two pivot highs
        hp1_idx, hp1_price, hp1_rsi = pivot_highs[-2]
        hp2_idx, hp2_price, hp2_rsi = pivot_highs[-1]
        
        # Check bars between pivots
        if hp2_idx - hp1_idx > self.max_bars_between:
            return None
        
        # Calculate slope
        slope = (hp2_price - hp1_price) / (hp2_idx - hp1_idx)
        atr_value = df['ATR'].iloc[hp2_idx]
        slope_atr = abs(slope) / atr_value if atr_value > 0 else 999
        
        # Check slope conditions
        if self.enforce_slope and slope > 0:
            return None  # Must be falling or horizontal
        
        if slope_atr > self.max_slope_atr:
            return None
        
        # Check channel range
        if self.max_channel_range > 0 and abs(hp2_price - hp1_price) > self.max_channel_range:
            return None
        
        # Find minimum low in channel
        min_low = None
        min_low_idx = None
        min_low_rsi = None
        
        for i in range(hp1_idx, hp2_idx + 1):
            if min_low is None or df['Low'].iloc[i] < min_low:
                min_low = df['Low'].iloc[i]
                min_low_idx = i
                min_low_rsi = df['RSI'].iloc[i]
        
        if min_low is None:
            return None
        
        # Check RSI condition
        is_oversold = min_low_rsi <= (self.rsi_oversold + self.rsi_buffer)
        has_divergence = self.detect_bullish_divergence(
            hp1_idx, hp1_price, hp1_rsi,
            hp2_idx, hp2_price, hp2_rsi
        )
        
        rsi_ok = is_oversold or has_divergence
        
        if not rsi_ok:
            return None
        
        logger.info(f"📊 Bullish Channel Detected: Slope={slope:.6f}, "
                   f"RSI@Low={min_low_rsi:.2f}, Divergence={has_divergence}")
        
        return ChannelInfo(
            channel_type="bullish",
            pivot1_idx=hp1_idx,
            pivot1_price=hp1_price,
            pivot2_idx=hp2_idx,
            pivot2_price=hp2_price,
            slope=slope,
            extreme_idx=min_low_idx,
            extreme_price=min_low,
            confirmed_bar=hp2_idx,
            rsi_at_extreme=min_low_rsi,
            has_divergence=has_divergence,
            is_valid=True
        )
    
    def detect_bearish_channel(
        self,
        df: pd.DataFrame,
        pivot_lows: List[Tuple[int, float, float]]
    ) -> Optional[ChannelInfo]:
        """
        Detect bearish parallel channel from pivot lows
        
        Args:
            df: DataFrame with OHLCV and indicators
            pivot_lows: List of pivot lows with RSI
        
        Returns:
            ChannelInfo or None
        """
        if len(pivot_lows) < 2:
            return None
        
        # Get last two pivot lows
        lp1_idx, lp1_price, lp1_rsi = pivot_lows[-2]
        lp2_idx, lp2_price, lp2_rsi = pivot_lows[-1]
        
        # Check bars between pivots
        if lp2_idx - lp1_idx > self.max_bars_between:
            return None
        
        # Calculate slope
        slope = (lp2_price - lp1_price) / (lp2_idx - lp1_idx)
        atr_value = df['ATR'].iloc[lp2_idx]
        slope_atr = abs(slope) / atr_value if atr_value > 0 else 999
        
        # Check slope conditions
        if self.enforce_slope and slope < 0:
            return None  # Must be rising or horizontal
        
        if slope_atr > self.max_slope_atr:
            return None
        
        # Check channel range
        if self.max_channel_range > 0 and abs(lp2_price - lp1_price) > self.max_channel_range:
            return None
        
        # Find maximum high in channel
        max_high = None
        max_high_idx = None
        max_high_rsi = None
        
        for i in range(lp1_idx, lp2_idx + 1):
            if max_high is None or df['High'].iloc[i] > max_high:
                max_high = df['High'].iloc[i]
                max_high_idx = i
                max_high_rsi = df['RSI'].iloc[i]
        
        if max_high is None:
            return None
        
        # Check RSI condition
        is_overbought = max_high_rsi >= (self.rsi_overbought - self.rsi_buffer)
        has_divergence = self.detect_bearish_divergence(
            lp1_idx, lp1_price, lp1_rsi,
            lp2_idx, lp2_price, lp2_rsi
        )
        
        rsi_ok = is_overbought or has_divergence
        
        if not rsi_ok:
            return None
        
        logger.info(f"📊 Bearish Channel Detected: Slope={slope:.6f}, "
                   f"RSI@High={max_high_rsi:.2f}, Divergence={has_divergence}")
        
        return ChannelInfo(
            channel_type="bearish",
            pivot1_idx=lp1_idx,
            pivot1_price=lp1_price,
            pivot2_idx=lp2_idx,
            pivot2_price=lp2_price,
            slope=slope,
            extreme_idx=max_high_idx,
            extreme_price=max_high,
            confirmed_bar=lp2_idx,
            rsi_at_extreme=max_high_rsi,
            has_divergence=has_divergence,
            is_valid=True
        )
    
    def calculate_stop_loss(
        self,
        df: pd.DataFrame,
        signal_type: str,
        entry_price: float,
        channel_info: Optional[ChannelInfo] = None
    ) -> float:
        """
        Calculate stop loss based on configured method
        
        Args:
            df: DataFrame with OHLCV data
            signal_type: "BUY" or "SELL"
            entry_price: Entry price
            channel_info: Channel information (for Kanal method)
        
        Returns:
            float: Stop loss price
        """
        if self.sl_method == "Kanal" and channel_info:
            # Use channel extreme as SL
            return channel_info.extreme_price
        
        elif self.sl_method == "Lookback":
            # Use lookback min/max
            lookback_data = df.tail(self.sl_lookback)
            if signal_type == "BUY":
                return lookback_data['Low'].min()
            else:
                return lookback_data['High'].max()
        
        else:  # ATR method
            atr_value = df['ATR'].iloc[-1]
            if signal_type == "BUY":
                return entry_price - (atr_value * self.sl_atr_mult)
            else:
                return entry_price + (atr_value * self.sl_atr_mult)
    
    def check_buy_signal(
        self,
        df: pd.DataFrame,
        symbol: str
    ) -> Optional[TradeSignal]:
        """
        Check for BUY signal (bullish channel breakout)
        
        Args:
            df: DataFrame with OHLCV and indicators
            symbol: Trading symbol
        
        Returns:
            TradeSignal or None
        """
        if self.active_bull_channel is None or not self.active_bull_channel.is_valid:
            return None
        
        current_idx = len(df) - 1
        prev_idx = current_idx - 1
        
        # Calculate channel top line values
        channel = self.active_bull_channel
        bars_from_pivot2 = current_idx - channel.pivot2_idx
        bars_from_pivot2_prev = prev_idx - channel.pivot2_idx
        
        channel_val_current = channel.pivot2_price + (channel.slope * bars_from_pivot2)
        channel_val_prev = channel.pivot2_price + (channel.slope * bars_from_pivot2_prev)
        
        close_current = df['Close'].iloc[-1]
        close_prev = df['Close'].iloc[-2]
        
        # Breakout condition: Previous bar closed above channel, current bar opening confirms
        breakout = (close_prev > channel_val_prev) and (close_current > channel_val_current)
        
        if not breakout:
            return None
        
        # Generate BUY signal
        entry_price = df['Open'].iloc[-1]  # Entry at current bar open
        stop_loss = self.calculate_stop_loss(df, "BUY", entry_price, channel)
        
        risk = entry_price - stop_loss
        if risk <= 0:
            logger.warning("Invalid risk calculation for BUY signal")
            return None
        
        take_profit_1 = entry_price + risk
        take_profit_2 = entry_price + (2.0 * risk)
        
        # Invalidate channel after signal
        self.active_bull_channel.is_valid = False
        
        reason = f"Bullish channel breakout - RSI@Low: {channel.rsi_at_extreme:.2f}"
        if channel.has_divergence:
            reason += " + Bullish Divergence"
        
        logger.success(f"🚀 BUY SIGNAL: {symbol} @ {entry_price:.5f}, SL: {stop_loss:.5f}, "
                      f"TP1: {take_profit_1:.5f}, TP2: {take_profit_2:.5f}")
        
        return TradeSignal(
            signal_type="BUY",
            symbol=symbol,
            entry_price=entry_price,
            stop_loss=stop_loss,
            take_profit_1=take_profit_1,
            take_profit_2=take_profit_2,
            risk_amount=risk,
            channel_info=channel,
            timestamp=datetime.now(),
            reason=reason
        )
    
    def check_sell_signal(
        self,
        df: pd.DataFrame,
        symbol: str
    ) -> Optional[TradeSignal]:
        """
        Check for SELL signal (bearish channel breakout)
        
        Args:
            df: DataFrame with OHLCV and indicators
            symbol: Trading symbol
        
        Returns:
            TradeSignal or None
        """
        if self.active_bear_channel is None or not self.active_bear_channel.is_valid:
            return None
        
        current_idx = len(df) - 1
        prev_idx = current_idx - 1
        
        # Calculate channel bottom line values
        channel = self.active_bear_channel
        bars_from_pivot2 = current_idx - channel.pivot2_idx
        bars_from_pivot2_prev = prev_idx - channel.pivot2_idx
        
        channel_val_current = channel.pivot2_price + (channel.slope * bars_from_pivot2)
        channel_val_prev = channel.pivot2_price + (channel.slope * bars_from_pivot2_prev)
        
        close_current = df['Close'].iloc[-1]
        close_prev = df['Close'].iloc[-2]
        
        # Breakout condition: Previous bar closed below channel
        breakout = (close_prev < channel_val_prev) and (close_current < channel_val_current)
        
        if not breakout:
            return None
        
        # Generate SELL signal
        entry_price = df['Open'].iloc[-1]  # Entry at current bar open
        stop_loss = self.calculate_stop_loss(df, "SELL", entry_price, channel)
        
        risk = stop_loss - entry_price
        if risk <= 0:
            logger.warning("Invalid risk calculation for SELL signal")
            return None
        
        take_profit_1 = entry_price - risk
        take_profit_2 = entry_price - (2.0 * risk)
        
        # Invalidate channel after signal
        self.active_bear_channel.is_valid = False
        
        reason = f"Bearish channel breakout - RSI@High: {channel.rsi_at_extreme:.2f}"
        if channel.has_divergence:
            reason += " + Bearish Divergence"
        
        logger.success(f"🚀 SELL SIGNAL: {symbol} @ {entry_price:.5f}, SL: {stop_loss:.5f}, "
                      f"TP1: {take_profit_1:.5f}, TP2: {take_profit_2:.5f}")
        
        return TradeSignal(
            signal_type="SELL",
            symbol=symbol,
            entry_price=entry_price,
            stop_loss=stop_loss,
            take_profit_1=take_profit_1,
            take_profit_2=take_profit_2,
            risk_amount=risk,
            channel_info=channel,
            timestamp=datetime.now(),
            reason=reason
        )
    
    def analyze(self, df: pd.DataFrame, symbol: str) -> Optional[TradeSignal]:
        """
        Main analysis function - detect channels and check for signals
        
        Args:
            df: DataFrame with OHLCV data and indicators (RSI, ATR)
            symbol: Trading symbol
        
        Returns:
            TradeSignal or None
        """
        if df is None or len(df) < 100:
            logger.warning(f"Insufficient data for {symbol}")
            return None
        
        # Find pivots
        pivot_highs = self.find_pivot_highs(df)
        pivot_lows = self.find_pivot_lows(df)
        
        # Detect channels if not already active
        if self.active_bull_channel is None or not self.active_bull_channel.is_valid:
            self.active_bull_channel = self.detect_bullish_channel(df, pivot_highs)
        
        if self.active_bear_channel is None or not self.active_bear_channel.is_valid:
            self.active_bear_channel = self.detect_bearish_channel(df, pivot_lows)
        
        # Check for signals
        buy_signal = self.check_buy_signal(df, symbol)
        if buy_signal:
            return buy_signal
        
        sell_signal = self.check_sell_signal(df, symbol)
        if sell_signal:
            return sell_signal
        
        return None
    
    def get_strategy_status(self) -> Dict:
        """
        Get current strategy status
        
        Returns:
            dict: Strategy status information
        """
        return {
            "bull_channel_active": self.active_bull_channel is not None and self.active_bull_channel.is_valid,
            "bear_channel_active": self.active_bear_channel is not None and self.active_bear_channel.is_valid,
            "bull_channel_info": self.active_bull_channel.__dict__ if self.active_bull_channel else None,
            "bear_channel_info": self.active_bear_channel.__dict__ if self.active_bear_channel else None,
        }
