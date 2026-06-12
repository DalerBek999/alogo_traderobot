"""
Risk Manager - Comprehensive Risk Control System
Safety features: daily loss limit, consecutive loss protection, drawdown monitoring
"""

from typing import Optional, Dict, List
from datetime import datetime, date
from dataclasses import dataclass, field
from loguru import logger


@dataclass
class TradeRecord:
    """Record of a completed trade"""
    trade_id: int
    symbol: str
    trade_type: str  # "BUY" or "SELL"
    entry_price: float
    exit_price: float
    lot_size: float
    profit_loss: float
    result: str  # "WIN" or "LOSS"
    close_reason: str  # "TP1", "TP2", "SL", "MANUAL"
    open_time: datetime
    close_time: datetime
    risk_reward: float = 0.0


@dataclass
class RiskStatus:
    """Current risk status of trading account"""
    trading_allowed: bool = True
    reason: str = ""
    daily_pnl: float = 0.0
    daily_loss_pct: float = 0.0
    consecutive_losses: int = 0
    total_trades_today: int = 0
    max_trades_reached: bool = False
    daily_loss_limit_reached: bool = False
    consecutive_loss_limit_reached: bool = False


class RiskManager:
    """
    Professional risk management system for micro accounts
    Protects capital with multiple safety mechanisms
    """
    
    def __init__(
        self,
        account_size: float,
        max_daily_loss_pct: float = 10.0,
        max_consecutive_losses: int = 3,
        max_trades_per_day: int = 5,
        max_open_trades: int = 1,
        demo_only: bool = True
    ):
        """
        Initialize Risk Manager
        
        Args:
            account_size: Initial account balance
            max_daily_loss_pct: Maximum daily loss percentage (stop trading)
            max_consecutive_losses: Stop after X consecutive losses
            max_trades_per_day: Maximum number of trades per day
            max_open_trades: Maximum concurrent open positions
            demo_only: Only allow demo account trading
        """
        self.initial_account_size = account_size
        self.current_account_size = account_size
        self.max_daily_loss_pct = max_daily_loss_pct
        self.max_consecutive_losses = max_consecutive_losses
        self.max_trades_per_day = max_trades_per_day
        self.max_open_trades = max_open_trades
        self.demo_only = demo_only
        
        # Trade tracking
        self.trade_history: List[TradeRecord] = []
        self.consecutive_losses = 0
        self.consecutive_wins = 0
        
        # Daily tracking
        self.current_date = date.today()
        self.daily_pnl = 0.0
        self.daily_trades = 0
        
        # Statistics
        self.total_trades = 0
        self.total_wins = 0
        self.total_losses = 0
        self.total_pnl = 0.0
        
        # Risk status
        self._trading_allowed = True
        self._stop_reason = ""
        
        logger.info(f"RiskManager initialized: Account=${account_size:.2f}, "
                   f"Max Daily Loss={max_daily_loss_pct}%, "
                   f"Max Consecutive Losses={max_consecutive_losses}, "
                   f"Demo Only={demo_only}")
    
    def _reset_daily_stats(self):
        """Reset daily statistics at start of new day"""
        if date.today() != self.current_date:
            logger.info(f"📅 New trading day - Resetting daily stats")
            logger.info(f"   Yesterday's P&L: ${self.daily_pnl:.2f}")
            logger.info(f"   Yesterday's Trades: {self.daily_trades}")
            
            self.current_date = date.today()
            self.daily_pnl = 0.0
            self.daily_trades = 0
            self._trading_allowed = True
            self._stop_reason = ""
    
    def check_trading_allowed(
        self,
        account_info: Dict,
        open_positions_count: int = 0
    ) -> RiskStatus:
        """
        Check if trading is allowed based on risk rules
        
        Args:
            account_info: Current account information from MT5
            open_positions_count: Number of currently open positions
        
        Returns:
            RiskStatus: Trading status and risk metrics
        """
        self._reset_daily_stats()
        
        status = RiskStatus()
        
        # Update current account size
        if account_info:
            self.current_account_size = account_info.get('balance', self.current_account_size)
        
        # 1. Check Demo Account Only mode
        if self.demo_only and account_info:
            if account_info.get('trade_mode') != 'DEMO':
                status.trading_allowed = False
                status.reason = "❌ REAL ACCOUNT DETECTED - Demo Only mode is enabled!"
                logger.error(status.reason)
                return status
        
        # 2. Check Daily Loss Limit
        daily_loss_pct = abs(self.daily_pnl / self.initial_account_size * 100)
        status.daily_loss_pct = daily_loss_pct
        
        if self.daily_pnl < 0 and daily_loss_pct >= self.max_daily_loss_pct:
            status.trading_allowed = False
            status.daily_loss_limit_reached = True
            status.reason = (f"❌ Daily loss limit reached: {daily_loss_pct:.2f}% "
                           f"(Max: {self.max_daily_loss_pct}%)")
            self._trading_allowed = False
            self._stop_reason = status.reason
            logger.error(status.reason)
            return status
        
        # 3. Check Consecutive Losses
        status.consecutive_losses = self.consecutive_losses
        
        if self.consecutive_losses >= self.max_consecutive_losses:
            status.trading_allowed = False
            status.consecutive_loss_limit_reached = True
            status.reason = (f"❌ Consecutive loss limit reached: {self.consecutive_losses} losses "
                           f"(Max: {self.max_consecutive_losses})")
            self._trading_allowed = False
            self._stop_reason = status.reason
            logger.error(status.reason)
            return status
        
        # 4. Check Daily Trade Limit
        status.total_trades_today = self.daily_trades
        
        if self.daily_trades >= self.max_trades_per_day:
            status.trading_allowed = False
            status.max_trades_reached = True
            status.reason = (f"❌ Daily trade limit reached: {self.daily_trades} "
                           f"(Max: {self.max_trades_per_day})")
            logger.warning(status.reason)
            return status
        
        # 5. Check Maximum Open Positions
        if open_positions_count >= self.max_open_trades:
            status.trading_allowed = False
            status.reason = (f"⚠️ Max open positions reached: {open_positions_count} "
                           f"(Max: {self.max_open_trades})")
            logger.warning(status.reason)
            return status
        
        # All checks passed
        status.trading_allowed = True
        status.daily_pnl = self.daily_pnl
        status.reason = "✅ Trading allowed - All risk checks passed"
        
        return status
    
    def record_trade(
        self,
        trade_id: int,
        symbol: str,
        trade_type: str,
        entry_price: float,
        exit_price: float,
        lot_size: float,
        profit_loss: float,
        close_reason: str,
        open_time: datetime,
        close_time: datetime
    ) -> TradeRecord:
        """
        Record completed trade and update statistics
        
        Args:
            trade_id: Unique trade ID
            symbol: Trading symbol
            trade_type: "BUY" or "SELL"
            entry_price: Entry price
            exit_price: Exit price
            lot_size: Lot size
            profit_loss: Profit/Loss in USD
            close_reason: "TP1", "TP2", "SL", "MANUAL"
            open_time: Trade open time
            close_time: Trade close time
        
        Returns:
            TradeRecord: Recorded trade
        """
        # Determine result
        result = "WIN" if profit_loss > 0 else "LOSS"
        
        # Calculate risk/reward ratio
        risk_reward = 0.0
        if close_reason in ["TP1", "TP2"]:
            if close_reason == "TP1":
                risk_reward = 1.0
            else:
                risk_reward = 2.0
        elif close_reason == "SL":
            risk_reward = -1.0
        
        # Create trade record
        trade = TradeRecord(
            trade_id=trade_id,
            symbol=symbol,
            trade_type=trade_type,
            entry_price=entry_price,
            exit_price=exit_price,
            lot_size=lot_size,
            profit_loss=profit_loss,
            result=result,
            close_reason=close_reason,
            open_time=open_time,
            close_time=close_time,
            risk_reward=risk_reward
        )
        
        # Update statistics
        self.trade_history.append(trade)
        self.total_trades += 1
        self.daily_trades += 1
        self.total_pnl += profit_loss
        self.daily_pnl += profit_loss
        
        if result == "WIN":
            self.total_wins += 1
            self.consecutive_wins += 1
            self.consecutive_losses = 0
            logger.success(f"✅ WIN Trade #{trade_id}: {symbol} {trade_type} "
                          f"P&L: ${profit_loss:.2f} ({close_reason})")
        else:
            self.total_losses += 1
            self.consecutive_losses += 1
            self.consecutive_wins = 0
            logger.warning(f"❌ LOSS Trade #{trade_id}: {symbol} {trade_type} "
                          f"P&L: ${profit_loss:.2f} ({close_reason})")
        
        # Log statistics
        self._log_statistics()
        
        return trade
    
    def _log_statistics(self):
        """Log current trading statistics"""
        win_rate = (self.total_wins / self.total_trades * 100) if self.total_trades > 0 else 0
        
        logger.info(f"📊 Trading Statistics:")
        logger.info(f"   Total Trades: {self.total_trades} (W:{self.total_wins}, L:{self.total_losses})")
        logger.info(f"   Win Rate: {win_rate:.1f}%")
        logger.info(f"   Total P&L: ${self.total_pnl:.2f}")
        logger.info(f"   Daily P&L: ${self.daily_pnl:.2f}")
        logger.info(f"   Consecutive: W:{self.consecutive_wins}, L:{self.consecutive_losses}")
    
    def get_statistics(self) -> Dict:
        """
        Get comprehensive trading statistics
        
        Returns:
            dict: Trading statistics
        """
        win_rate = (self.total_wins / self.total_trades * 100) if self.total_trades > 0 else 0
        avg_win = sum(t.profit_loss for t in self.trade_history if t.result == "WIN") / self.total_wins if self.total_wins > 0 else 0
        avg_loss = sum(t.profit_loss for t in self.trade_history if t.result == "LOSS") / self.total_losses if self.total_losses > 0 else 0
        profit_factor = abs(avg_win * self.total_wins / (avg_loss * self.total_losses)) if self.total_losses > 0 and avg_loss != 0 else 0
        
        return {
            "total_trades": self.total_trades,
            "wins": self.total_wins,
            "losses": self.total_losses,
            "win_rate": win_rate,
            "total_pnl": self.total_pnl,
            "daily_pnl": self.daily_pnl,
            "daily_trades": self.daily_trades,
            "consecutive_wins": self.consecutive_wins,
            "consecutive_losses": self.consecutive_losses,
            "average_win": avg_win,
            "average_loss": avg_loss,
            "profit_factor": profit_factor,
            "account_growth": ((self.current_account_size - self.initial_account_size) / self.initial_account_size * 100),
            "max_daily_loss_pct": self.max_daily_loss_pct,
            "max_consecutive_losses": self.max_consecutive_losses,
            "trading_allowed": self._trading_allowed,
            "stop_reason": self._stop_reason
        }
    
    def get_recent_trades(self, count: int = 10) -> List[TradeRecord]:
        """
        Get recent trade history
        
        Args:
            count: Number of recent trades to return
        
        Returns:
            list: Recent trades
        """
        return self.trade_history[-count:]
    
    def calculate_max_drawdown(self) -> float:
        """
        Calculate maximum drawdown percentage
        
        Returns:
            float: Max drawdown percentage
        """
        if not self.trade_history:
            return 0.0
        
        peak = self.initial_account_size
        max_dd = 0.0
        current_balance = self.initial_account_size
        
        for trade in self.trade_history:
            current_balance += trade.profit_loss
            if current_balance > peak:
                peak = current_balance
            dd = ((peak - current_balance) / peak) * 100
            if dd > max_dd:
                max_dd = dd
        
        return max_dd
    
    def reset_consecutive_losses(self):
        """Manually reset consecutive loss counter (use with caution)"""
        logger.warning(f"⚠️ Manually resetting consecutive losses from {self.consecutive_losses} to 0")
        self.consecutive_losses = 0
        self._trading_allowed = True
        self._stop_reason = ""
    
    def emergency_stop(self, reason: str):
        """
        Emergency stop - disable all trading
        
        Args:
            reason: Reason for emergency stop
        """
        self._trading_allowed = False
        self._stop_reason = f"🚨 EMERGENCY STOP: {reason}"
        logger.critical(self._stop_reason)
