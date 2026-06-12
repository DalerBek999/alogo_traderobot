"""
Position Sizer - Dynamic Lot Size Calculator for Micro Accounts
Optimized for $10-$15 accounts with proper risk management
"""

from typing import Optional, Dict
from loguru import logger
import math


class PositionSizer:
    """
    Professional position sizing for micro accounts
    Calculates optimal lot size based on account size, risk percentage, and stop loss
    """
    
    def __init__(
        self,
        account_size: float,
        risk_per_trade: float = 2.0,
        min_lot_size: float = 0.01,
        max_lot_size: float = 0.1,
        use_dynamic_lots: bool = True
    ):
        """
        Initialize Position Sizer
        
        Args:
            account_size: Account balance in USD
            risk_per_trade: Risk percentage per trade (1-5%)
            min_lot_size: Minimum lot size (typically 0.01 for micro accounts)
            max_lot_size: Maximum lot size (safety cap for micro accounts)
            use_dynamic_lots: Calculate dynamic lot size based on account
        """
        self.account_size = account_size
        self.risk_per_trade = risk_per_trade
        self.min_lot_size = min_lot_size
        self.max_lot_size = max_lot_size
        self.use_dynamic_lots = use_dynamic_lots
        
        logger.info(f"PositionSizer initialized: Account=${account_size:.2f}, "
                   f"Risk={risk_per_trade}%, Min Lot={min_lot_size}, Max Lot={max_lot_size}")
    
    def calculate_risk_amount(self) -> float:
        """
        Calculate dollar amount to risk per trade
        
        Returns:
            float: Risk amount in USD
        """
        risk_amount = self.account_size * (self.risk_per_trade / 100.0)
        logger.debug(f"Risk amount: ${risk_amount:.2f} ({self.risk_per_trade}% of ${self.account_size:.2f})")
        return risk_amount
    
    def calculate_lot_size(
        self,
        symbol: str,
        entry_price: float,
        stop_loss: float,
        symbol_info: Dict
    ) -> float:
        """
        Calculate optimal lot size for trade
        
        Args:
            symbol: Trading symbol
            entry_price: Entry price
            stop_loss: Stop loss price
            symbol_info: Symbol information from MT5 (point, digits, contract_size)
        
        Returns:
            float: Lot size (rounded to valid step)
        """
        try:
            # Calculate stop loss distance in price
            sl_distance = abs(entry_price - stop_loss)
            
            if sl_distance == 0:
                logger.error("Stop loss distance is zero!")
                return self.min_lot_size
            
            # Get symbol parameters
            point = symbol_info.get('point', 0.00001)
            digits = symbol_info.get('digits', 5)
            contract_size = symbol_info.get('trade_contract_size', 100000)
            volume_step = symbol_info.get('volume_step', 0.01)
            
            # Calculate pip value (for forex pairs)
            # For XAUUSD (gold), 1 pip = $0.01 per 0.01 lot
            # For forex pairs, 1 pip = contract_size * point value
            
            # Risk amount in account currency
            risk_amount = self.calculate_risk_amount()
            
            # Calculate lot size based on risk
            # Formula: Lot Size = Risk Amount / (SL Distance in Pips × Pip Value)
            sl_pips = sl_distance / point
            
            # For standard forex calculation
            # Pip value per 1 lot = contract_size * point
            pip_value_per_lot = contract_size * point
            
            # Lot size = Risk Amount / (SL in pips × pip value per lot)
            if not self.use_dynamic_lots:
                lot_size = self.min_lot_size
            else:
                lot_size = risk_amount / (sl_pips * pip_value_per_lot)
            
            # Round to volume step
            lot_size = self._round_to_step(lot_size, volume_step)
            
            # Apply min/max limits
            lot_size = max(self.min_lot_size, min(lot_size, self.max_lot_size))
            
            # Calculate expected risk with this lot size
            expected_risk = sl_pips * pip_value_per_lot * lot_size
            risk_percentage = (expected_risk / self.account_size) * 100
            
            logger.info(f"📊 Position Size Calculation:")
            logger.info(f"   Symbol: {symbol}")
            logger.info(f"   Entry: {entry_price:.{digits}f}, SL: {stop_loss:.{digits}f}")
            logger.info(f"   SL Distance: {sl_distance:.{digits}f} ({sl_pips:.1f} pips)")
            logger.info(f"   Lot Size: {lot_size:.2f}")
            logger.info(f"   Expected Risk: ${expected_risk:.2f} ({risk_percentage:.2f}%)")
            
            return lot_size
            
        except Exception as e:
            logger.exception(f"Error calculating lot size: {e}")
            return self.min_lot_size
    
    def _round_to_step(self, value: float, step: float) -> float:
        """
        Round value to nearest valid step
        
        Args:
            value: Value to round
            step: Step size
        
        Returns:
            float: Rounded value
        """
        return round(value / step) * step
    
    def calculate_position_value(
        self,
        lot_size: float,
        entry_price: float,
        contract_size: float = 100000
    ) -> float:
        """
        Calculate total position value in USD
        
        Args:
            lot_size: Lot size
            entry_price: Entry price
            contract_size: Contract size (100,000 for standard lot)
        
        Returns:
            float: Position value in USD
        """
        position_value = lot_size * contract_size * entry_price
        return position_value
    
    def calculate_required_margin(
        self,
        lot_size: float,
        entry_price: float,
        leverage: int = 100,
        contract_size: float = 100000
    ) -> float:
        """
        Calculate required margin for position
        
        Args:
            lot_size: Lot size
            entry_price: Entry price
            leverage: Account leverage
            contract_size: Contract size
        
        Returns:
            float: Required margin in USD
        """
        position_value = self.calculate_position_value(lot_size, entry_price, contract_size)
        required_margin = position_value / leverage
        
        logger.debug(f"Required margin: ${required_margin:.2f} "
                    f"(Position: ${position_value:.2f}, Leverage: 1:{leverage})")
        
        return required_margin
    
    def validate_position_size(
        self,
        lot_size: float,
        entry_price: float,
        account_equity: float,
        leverage: int = 100,
        contract_size: float = 100000
    ) -> tuple[bool, str]:
        """
        Validate if position size is safe for account
        
        Args:
            lot_size: Proposed lot size
            entry_price: Entry price
            account_equity: Current account equity
            leverage: Account leverage
            contract_size: Contract size
        
        Returns:
            tuple: (is_valid, reason)
        """
        # Check minimum lot size
        if lot_size < self.min_lot_size:
            return False, f"Lot size {lot_size:.2f} below minimum {self.min_lot_size:.2f}"
        
        # Check maximum lot size
        if lot_size > self.max_lot_size:
            return False, f"Lot size {lot_size:.2f} exceeds maximum {self.max_lot_size:.2f}"
        
        # Check required margin
        required_margin = self.calculate_required_margin(
            lot_size, entry_price, leverage, contract_size
        )
        
        # Margin should not exceed 50% of equity for safety
        max_safe_margin = account_equity * 0.5
        
        if required_margin > max_safe_margin:
            return False, (f"Required margin ${required_margin:.2f} exceeds "
                          f"safe limit ${max_safe_margin:.2f} (50% of equity)")
        
        # Check if account can afford the margin
        if required_margin > account_equity:
            return False, (f"Insufficient margin: Required ${required_margin:.2f}, "
                          f"Available ${account_equity:.2f}")
        
        return True, "Position size is valid"
    
    def get_max_safe_lot_size(
        self,
        entry_price: float,
        account_equity: float,
        leverage: int = 100,
        contract_size: float = 100000
    ) -> float:
        """
        Calculate maximum safe lot size based on available margin
        
        Args:
            entry_price: Entry price
            account_equity: Current account equity
            leverage: Account leverage
            contract_size: Contract size
        
        Returns:
            float: Maximum safe lot size
        """
        # Use 50% of equity as maximum margin
        max_margin = account_equity * 0.5
        
        # Calculate max lot size
        # Margin = (Lot Size × Contract Size × Price) / Leverage
        # Lot Size = (Margin × Leverage) / (Contract Size × Price)
        max_lot_size = (max_margin * leverage) / (contract_size * entry_price)
        
        # Round to step and apply limits
        max_lot_size = self._round_to_step(max_lot_size, 0.01)
        max_lot_size = min(max_lot_size, self.max_lot_size)
        
        logger.debug(f"Max safe lot size: {max_lot_size:.2f} "
                    f"(Max margin: ${max_margin:.2f}, Leverage: 1:{leverage})")
        
        return max_lot_size
    
    def update_account_size(self, new_balance: float):
        """
        Update account size (after profit/loss)
        
        Args:
            new_balance: New account balance
        """
        old_balance = self.account_size
        self.account_size = new_balance
        
        logger.info(f"Account size updated: ${old_balance:.2f} → ${new_balance:.2f} "
                   f"({((new_balance - old_balance) / old_balance * 100):+.2f}%)")
