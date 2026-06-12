"""
Trade Executor - Professional Trade Execution Engine
Handles order placement, modification, and closing with comprehensive error handling
"""

import MetaTrader5 as mt5
from typing import Optional, Dict, Tuple
from datetime import datetime
from loguru import logger
import time


class TradeExecutor:
    """
    Professional trade execution engine for MT5
    Handles all trading operations with error recovery and retry logic
    """
    
    # MT5 Order Types
    ORDER_TYPE_BUY = mt5.ORDER_TYPE_BUY
    ORDER_TYPE_SELL = mt5.ORDER_TYPE_SELL
    
    # MT5 Trade Actions
    TRADE_ACTION_DEAL = mt5.TRADE_ACTION_DEAL
    
    # Order Filling Types
    ORDER_FILLING_FOK = mt5.ORDER_FILLING_FOK  # Fill or Kill
    ORDER_FILLING_IOC = mt5.ORDER_FILLING_IOC  # Immediate or Cancel
    ORDER_FILLING_RETURN = mt5.ORDER_FILLING_RETURN  # Return order
    
    def __init__(self, mt5_connector, magic_number: int = 234000):
        """
        Initialize Trade Executor
        
        Args:
            mt5_connector: MT5Connector instance
            magic_number: Magic number for identifying bot trades
        """
        self.connector = mt5_connector
        self.magic_number = magic_number
        
        logger.info(f"TradeExecutor initialized with magic number: {magic_number}")
    
    def _prepare_order_request(
        self,
        symbol: str,
        order_type: int,
        volume: float,
        price: float,
        sl: float,
        tp: float,
        deviation: int = 20,
        comment: str = "AlgoTrader"
    ) -> Dict:
        """
        Prepare order request dictionary
        
        Args:
            symbol: Trading symbol
            order_type: ORDER_TYPE_BUY or ORDER_TYPE_SELL
            volume: Lot size
            price: Entry price
            sl: Stop loss price
            tp: Take profit price
            deviation: Maximum price deviation in points
            comment: Order comment
        
        Returns:
            dict: Order request
        """
        # Get symbol info to determine filling type
        symbol_info = mt5.symbol_info(symbol)
        if symbol_info is None:
            logger.error(f"Failed to get symbol info for {symbol}")
            return {}
        
        # Determine filling type based on symbol
        filling_type = symbol_info.filling_mode
        if filling_type == 1:
            filling = self.ORDER_FILLING_FOK
        elif filling_type == 2:
            filling = self.ORDER_FILLING_IOC
        else:
            filling = self.ORDER_FILLING_RETURN
        
        # Round prices to symbol digits
        digits = symbol_info.digits
        price = round(price, digits)
        sl = round(sl, digits)
        tp = round(tp, digits)
        
        # Create order request
        request = {
            "action": self.TRADE_ACTION_DEAL,
            "symbol": symbol,
            "volume": volume,
            "type": order_type,
            "price": price,
            "sl": sl,
            "tp": tp,
            "deviation": deviation,
            "magic": self.magic_number,
            "comment": comment,
            "type_time": mt5.ORDER_TIME_GTC,
            "type_filling": filling,
        }
        
        return request
    
    def open_position(
        self,
        symbol: str,
        signal_type: str,
        volume: float,
        price: Optional[float] = None,
        sl: Optional[float] = None,
        tp: Optional[float] = None,
        comment: str = "AlgoTrader",
        max_retries: int = 3
    ) -> Optional[Dict]:
        """
        Open a new position with retry logic
        
        Args:
            symbol: Trading symbol
            signal_type: "BUY" or "SELL"
            volume: Lot size
            price: Entry price (None = market price)
            sl: Stop loss price
            tp: Take profit price
            comment: Order comment
            max_retries: Maximum retry attempts
        
        Returns:
            dict: Trade result or None if failed
        """
        if not self.connector.ensure_connection():
            logger.error("MT5 connection not available")
            return None
        
        # Check if trading is allowed
        if not self.connector.check_trading_allowed():
            logger.error("Trading is not allowed")
            return None
        
        # Validate symbol
        symbol_info = mt5.symbol_info(symbol)
        if symbol_info is None:
            logger.error(f"Symbol {symbol} not found")
            return None
        
        # Get current price if not specified
        if price is None:
            tick = mt5.symbol_info_tick(symbol)
            if tick is None:
                logger.error(f"Failed to get tick for {symbol}")
                return None
            
            if signal_type == "BUY":
                price = tick.ask
            else:
                price = tick.bid
        
        # Determine order type
        order_type = self.ORDER_TYPE_BUY if signal_type == "BUY" else self.ORDER_TYPE_SELL
        
        # Round volume to valid step
        volume_step = symbol_info.volume_step
        volume = round(volume / volume_step) * volume_step
        volume = max(symbol_info.volume_min, min(volume, symbol_info.volume_max))
        
        # Prepare order request
        request = self._prepare_order_request(
            symbol=symbol,
            order_type=order_type,
            volume=volume,
            price=price,
            sl=sl if sl else 0.0,
            tp=tp if tp else 0.0,
            comment=comment
        )
        
        if not request:
            return None
        
        # Execute order with retry logic
        for attempt in range(1, max_retries + 1):
            logger.info(f"📤 Opening {signal_type} position: {symbol} "
                       f"Volume: {volume} Price: {price:.5f} "
                       f"SL: {sl:.5f if sl else 'None'} "
                       f"TP: {tp:.5f if tp else 'None'} "
                       f"(Attempt {attempt}/{max_retries})")
            
            result = mt5.order_send(request)
            
            if result is None:
                logger.error(f"Order send failed: No result returned")
                if attempt < max_retries:
                    time.sleep(1)
                    continue
                return None
            
            # Check result
            if result.retcode == mt5.TRADE_RETCODE_DONE:
                logger.success(f"✅ Position opened successfully!")
                logger.info(f"   Order: #{result.order}, Deal: #{result.deal}")
                logger.info(f"   Volume: {result.volume}, Price: {result.price:.5f}")
                
                return {
                    "success": True,
                    "order": result.order,
                    "deal": result.deal,
                    "volume": result.volume,
                    "price": result.price,
                    "comment": result.comment,
                    "request": request,
                    "result": result._asdict()
                }
            
            else:
                error_code = result.retcode
                error_desc = self._get_error_description(error_code)
                logger.error(f"❌ Order failed: {error_desc} (Code: {error_code})")
                
                # Check if error is retryable
                if self._is_retryable_error(error_code) and attempt < max_retries:
                    logger.warning(f"Retrying in 1 second...")
                    time.sleep(1)
                    
                    # Update price for market orders
                    tick = mt5.symbol_info_tick(symbol)
                    if tick:
                        request['price'] = tick.ask if signal_type == "BUY" else tick.bid
                    continue
                else:
                    return {
                        "success": False,
                        "error_code": error_code,
                        "error_description": error_desc,
                        "request": request,
                        "result": result._asdict() if result else None
                    }
        
        return None
    
    def close_position(
        self,
        position_ticket: int,
        comment: str = "Close by AlgoTrader",
        max_retries: int = 3
    ) -> Optional[Dict]:
        """
        Close an open position
        
        Args:
            position_ticket: Position ticket number
            comment: Close comment
            max_retries: Maximum retry attempts
        
        Returns:
            dict: Close result or None
        """
        if not self.connector.ensure_connection():
            return None
        
        # Get position info
        position = mt5.positions_get(ticket=position_ticket)
        if position is None or len(position) == 0:
            logger.error(f"Position #{position_ticket} not found")
            return None
        
        position = position[0]
        
        # Prepare close request (opposite order)
        symbol = position.symbol
        volume = position.volume
        position_type = position.type
        
        # Get current price
        tick = mt5.symbol_info_tick(symbol)
        if tick is None:
            logger.error(f"Failed to get tick for {symbol}")
            return None
        
        # Opposite order type
        if position_type == mt5.POSITION_TYPE_BUY:
            order_type = self.ORDER_TYPE_SELL
            price = tick.bid
        else:
            order_type = self.ORDER_TYPE_BUY
            price = tick.ask
        
        # Prepare close request
        request = self._prepare_order_request(
            symbol=symbol,
            order_type=order_type,
            volume=volume,
            price=price,
            sl=0.0,
            tp=0.0,
            comment=comment
        )
        
        request['position'] = position_ticket  # Link to position
        
        # Execute close with retry
        for attempt in range(1, max_retries + 1):
            logger.info(f"📤 Closing position #{position_ticket}: {symbol} "
                       f"Volume: {volume} Price: {price:.5f} "
                       f"(Attempt {attempt}/{max_retries})")
            
            result = mt5.order_send(request)
            
            if result is None:
                logger.error("Close failed: No result")
                if attempt < max_retries:
                    time.sleep(1)
                    continue
                return None
            
            if result.retcode == mt5.TRADE_RETCODE_DONE:
                logger.success(f"✅ Position closed successfully!")
                logger.info(f"   Deal: #{result.deal}, Price: {result.price:.5f}")
                
                return {
                    "success": True,
                    "deal": result.deal,
                    "volume": result.volume,
                    "price": result.price,
                    "request": request,
                    "result": result._asdict()
                }
            else:
                error_code = result.retcode
                error_desc = self._get_error_description(error_code)
                logger.error(f"❌ Close failed: {error_desc} (Code: {error_code})")
                
                if self._is_retryable_error(error_code) and attempt < max_retries:
                    time.sleep(1)
                    # Update price
                    tick = mt5.symbol_info_tick(symbol)
                    if tick:
                        request['price'] = tick.bid if position_type == mt5.POSITION_TYPE_BUY else tick.ask
                    continue
                else:
                    return {
                        "success": False,
                        "error_code": error_code,
                        "error_description": error_desc
                    }
        
        return None
    
    def modify_position(
        self,
        position_ticket: int,
        sl: Optional[float] = None,
        tp: Optional[float] = None,
        max_retries: int = 3
    ) -> Optional[Dict]:
        """
        Modify position SL/TP
        
        Args:
            position_ticket: Position ticket
            sl: New stop loss (None = no change)
            tp: New take profit (None = no change)
            max_retries: Maximum retries
        
        Returns:
            dict: Modification result
        """
        if not self.connector.ensure_connection():
            return None
        
        # Get position
        position = mt5.positions_get(ticket=position_ticket)
        if position is None or len(position) == 0:
            logger.error(f"Position #{position_ticket} not found")
            return None
        
        position = position[0]
        symbol = position.symbol
        
        # Get symbol info for rounding
        symbol_info = mt5.symbol_info(symbol)
        if symbol_info is None:
            return None
        
        digits = symbol_info.digits
        
        # Use current values if not specified
        new_sl = round(sl, digits) if sl is not None else position.sl
        new_tp = round(tp, digits) if tp is not None else position.tp
        
        # Prepare modification request
        request = {
            "action": mt5.TRADE_ACTION_SLTP,
            "position": position_ticket,
            "symbol": symbol,
            "sl": new_sl,
            "tp": new_tp,
            "magic": self.magic_number,
        }
        
        # Execute modification
        for attempt in range(1, max_retries + 1):
            logger.info(f"📝 Modifying position #{position_ticket}: "
                       f"SL: {new_sl:.5f}, TP: {new_tp:.5f} "
                       f"(Attempt {attempt}/{max_retries})")
            
            result = mt5.order_send(request)
            
            if result is None:
                if attempt < max_retries:
                    time.sleep(1)
                    continue
                return None
            
            if result.retcode == mt5.TRADE_RETCODE_DONE:
                logger.success(f"✅ Position modified successfully!")
                return {
                    "success": True,
                    "order": result.order,
                    "result": result._asdict()
                }
            else:
                error_code = result.retcode
                error_desc = self._get_error_description(error_code)
                logger.error(f"❌ Modification failed: {error_desc}")
                
                if self._is_retryable_error(error_code) and attempt < max_retries:
                    time.sleep(1)
                    continue
                else:
                    return {"success": False, "error_code": error_code, "error_description": error_desc}
        
        return None
    
    def close_all_positions(self, symbol: Optional[str] = None) -> Dict:
        """
        Close all open positions (optionally filter by symbol)
        
        Args:
            symbol: Symbol filter (None = all symbols)
        
        Returns:
            dict: Summary of closed positions
        """
        if not self.connector.ensure_connection():
            return {"success": False, "closed": 0}
        
        positions = self.connector.get_open_positions(symbol)
        
        if not positions:
            logger.info("No open positions to close")
            return {"success": True, "closed": 0}
        
        closed_count = 0
        failed_count = 0
        
        for pos in positions:
            result = self.close_position(pos['ticket'])
            if result and result.get('success'):
                closed_count += 1
            else:
                failed_count += 1
        
        logger.info(f"Closed {closed_count} positions, {failed_count} failed")
        
        return {
            "success": True,
            "closed": closed_count,
            "failed": failed_count,
            "total": len(positions)
        }
    
    def _get_error_description(self, error_code: int) -> str:
        """Get human-readable error description"""
        errors = {
            mt5.TRADE_RETCODE_REQUOTE: "Requote",
            mt5.TRADE_RETCODE_REJECT: "Request rejected",
            mt5.TRADE_RETCODE_CANCEL: "Request canceled",
            mt5.TRADE_RETCODE_PLACED: "Order placed",
            mt5.TRADE_RETCODE_DONE: "Request completed",
            mt5.TRADE_RETCODE_DONE_PARTIAL: "Partially filled",
            mt5.TRADE_RETCODE_ERROR: "Request error",
            mt5.TRADE_RETCODE_TIMEOUT: "Request timeout",
            mt5.TRADE_RETCODE_INVALID: "Invalid request",
            mt5.TRADE_RETCODE_INVALID_VOLUME: "Invalid volume",
            mt5.TRADE_RETCODE_INVALID_PRICE: "Invalid price",
            mt5.TRADE_RETCODE_INVALID_STOPS: "Invalid stops",
            mt5.TRADE_RETCODE_TRADE_DISABLED: "Trading disabled",
            mt5.TRADE_RETCODE_MARKET_CLOSED: "Market closed",
            mt5.TRADE_RETCODE_NO_MONEY: "Insufficient funds",
            mt5.TRADE_RETCODE_PRICE_CHANGED: "Price changed",
            mt5.TRADE_RETCODE_PRICE_OFF: "No prices",
            mt5.TRADE_RETCODE_INVALID_EXPIRATION: "Invalid expiration",
            mt5.TRADE_RETCODE_ORDER_CHANGED: "Order changed",
            mt5.TRADE_RETCODE_TOO_MANY_REQUESTS: "Too many requests",
            mt5.TRADE_RETCODE_NO_CHANGES: "No changes",
            mt5.TRADE_RETCODE_SERVER_DISABLES_AT: "Auto trading disabled by server",
            mt5.TRADE_RETCODE_CLIENT_DISABLES_AT: "Auto trading disabled by client",
            mt5.TRADE_RETCODE_LOCKED: "Request locked",
            mt5.TRADE_RETCODE_FROZEN: "Order or position frozen",
            mt5.TRADE_RETCODE_INVALID_FILL: "Invalid filling type",
            mt5.TRADE_RETCODE_CONNECTION: "No connection",
            mt5.TRADE_RETCODE_ONLY_REAL: "Only real accounts allowed",
            mt5.TRADE_RETCODE_LIMIT_ORDERS: "Orders limit reached",
            mt5.TRADE_RETCODE_LIMIT_VOLUME: "Volume limit reached",
        }
        
        return errors.get(error_code, f"Unknown error ({error_code})")
    
    def _is_retryable_error(self, error_code: int) -> bool:
        """Check if error is retryable"""
        retryable_errors = [
            mt5.TRADE_RETCODE_REQUOTE,
            mt5.TRADE_RETCODE_PRICE_CHANGED,
            mt5.TRADE_RETCODE_TIMEOUT,
            mt5.TRADE_RETCODE_PRICE_OFF,
            mt5.TRADE_RETCODE_CONNECTION,
        ]
        
        return error_code in retryable_errors
