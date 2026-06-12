"""
Trading Bot - Main Orchestrator
Integrates all modules: MT5, Strategy, Risk Management, Trade Execution
"""

from typing import Optional, Dict, List
from datetime import datetime
import time
from loguru import logger

from config import get_settings
from mt5_integration import MT5Connector, DataManager
from strategies import AzizXalikovStrategyV2
from risk_management import PositionSizer, RiskManager
from utils import TradeExecutor


class ForexTradingBot:
    """
    Professional Forex Trading Bot
    Implements Aziz Xalikov v2.0 strategy with comprehensive risk management
    """
    
    def __init__(self):
        """Initialize trading bot with all components"""
        logger.info("=" * 60)
        logger.info("🤖 Forex AlgoTrader v2.0 - Initializing...")
        logger.info("=" * 60)
        
        # Load settings
        self.settings = get_settings()
        logger.info(f"✅ Settings loaded: Account ${self.settings.account_size:.2f}")
        
        # Initialize MT5 connection
        self.mt5_connector = MT5Connector(
            login=self.settings.mt5_login,
            password=self.settings.mt5_password,
            server=self.settings.mt5_server,
            path=self.settings.mt5_path
        )
        
        # Initialize data manager
        self.data_manager = DataManager(self.mt5_connector)
        
        # Initialize strategy
        self.strategy = AzizXalikovStrategyV2(
            fractal_period=self.settings.fractal_period,
            max_bars_between=self.settings.max_bars_between,
            max_channel_range=self.settings.max_channel_range,
            max_slope_atr=self.settings.max_slope_atr,
            enforce_slope=self.settings.enforce_slope,
            rsi_length=self.settings.rsi_length,
            rsi_overbought=self.settings.rsi_overbought,
            rsi_oversold=self.settings.rsi_oversold,
            rsi_buffer=self.settings.rsi_buffer,
            sl_method=self.settings.sl_method,
            sl_lookback=self.settings.sl_lookback,
            sl_atr_mult=self.settings.sl_atr_mult,
            min_timeframe_minutes=self.settings.min_timeframe_minutes
        )
        
        # Initialize risk management
        self.risk_manager = RiskManager(
            account_size=self.settings.account_size,
            max_daily_loss_pct=self.settings.max_daily_loss_pct,
            max_consecutive_losses=self.settings.max_consecutive_losses,
            max_trades_per_day=20,  # Increased for testing
            max_open_trades=self.settings.max_open_trades,
            demo_only=self.settings.demo_only
        )
        
        self.position_sizer = PositionSizer(
            account_size=self.settings.account_size,
            risk_per_trade=self.settings.risk_per_trade,
            min_lot_size=self.settings.min_lot_size,
            max_lot_size=self.settings.max_lot_size,
            use_dynamic_lots=self.settings.use_dynamic_lots
        )
        
        # Initialize trade executor
        self.trade_executor = TradeExecutor(self.mt5_connector)
        
        # Bot state
        self.is_running = False
        self.active_positions: Dict[str, Dict] = {}
        
        logger.success("✅ All components initialized successfully!")
    
    def start(self) -> bool:
        """
        Start the trading bot
        
        Returns:
            bool: True if started successfully
        """
        logger.info("🚀 Starting trading bot...")
        
        # Connect to MT5
        if not self.mt5_connector.connect():
            logger.error("Failed to connect to MT5")
            return False
        
        # Verify trading is allowed
        account_info = self.mt5_connector.get_account_info()
        if not account_info:
            logger.error("Failed to get account info")
            return False
        
        logger.info(f"Connected to account: {account_info['login']}")
        logger.info(f"Balance: ${account_info['balance']:.2f}")
        logger.info(f"Equity: ${account_info['equity']:.2f}")
        logger.info(f"Mode: {account_info['trade_mode']}")
        
        # Update risk manager with actual balance
        self.risk_manager.current_account_size = account_info['balance']
        self.position_sizer.update_account_size(account_info['balance'])
        
        # Validate symbols
        for symbol in self.settings.trading_symbols:
            if not self.data_manager.validate_symbol(symbol):
                logger.error(f"Symbol {symbol} validation failed")
                return False
        
        self.is_running = True
        logger.success("✅ Trading bot started successfully!")
        
        return True
    
    def stop(self):
        """Stop the trading bot"""
        logger.info("🛑 Stopping trading bot...")
        self.is_running = False
        self.mt5_connector.disconnect()
        logger.info("Trading bot stopped")
    
    def analyze_symbol(self, symbol: str, timeframe: str = "M15") -> Optional[Dict]:
        """
        Analyze symbol for trading signals
        
        Args:
            symbol: Trading symbol
            timeframe: Timeframe to analyze
        
        Returns:
            dict: Analysis result with signal if found
        """
        try:
            # Get market data with indicators
            df = self.data_manager.get_market_data_with_indicators(
                symbol=symbol,
                timeframe=timeframe,
                count=500,
                rsi_period=self.settings.rsi_length,
                atr_period=14
            )
            
            if df is None or df.empty:
                logger.warning(f"No data for {symbol} {timeframe}")
                return None
            
            # Run strategy analysis
            signal = self.strategy.analyze(df, symbol)
            
            if signal:
                logger.info(f"🎯 Signal detected: {signal.signal_type} {symbol}")
                logger.info(f"   Entry: {signal.entry_price:.5f}")
                logger.info(f"   SL: {signal.stop_loss:.5f}")
                logger.info(f"   TP1: {signal.take_profit_1:.5f}")
                logger.info(f"   TP2: {signal.take_profit_2:.5f}")
                logger.info(f"   Reason: {signal.reason}")
                
                return {
                    "signal": signal,
                    "symbol": symbol,
                    "timeframe": timeframe,
                    "timestamp": datetime.now()
                }
            
            return None
            
        except Exception as e:
            logger.exception(f"Error analyzing {symbol}: {e}")
            return None
    
    def execute_signal(self, signal_data: Dict) -> bool:
        """
        Execute trading signal
        
        Args:
            signal_data: Signal information
        
        Returns:
            bool: True if executed successfully
        """
        signal = signal_data['signal']
        symbol = signal.symbol
        
        try:
            # Check if trading is allowed
            account_info = self.mt5_connector.get_account_info()
            open_positions = self.mt5_connector.get_open_positions()
            
            risk_status = self.risk_manager.check_trading_allowed(
                account_info=account_info,
                open_positions_count=len(open_positions)
            )
            
            if not risk_status.trading_allowed:
                logger.warning(f"Trading not allowed: {risk_status.reason}")
                return False
            
            # Calculate position size
            symbol_info = self.mt5_connector.get_symbol_info(symbol)
            if not symbol_info:
                logger.error(f"Failed to get symbol info for {symbol}")
                return False
            
            lot_size = self.position_sizer.calculate_lot_size(
                symbol=symbol,
                entry_price=signal.entry_price,
                stop_loss=signal.stop_loss,
                symbol_info=symbol_info
            )
            
            # Validate position size
            is_valid, reason = self.position_sizer.validate_position_size(
                lot_size=lot_size,
                entry_price=signal.entry_price,
                account_equity=account_info['equity'],
                leverage=account_info.get('leverage', 100),
                contract_size=symbol_info['trade_contract_size']
            )
            
            if not is_valid:
                logger.error(f"Position size validation failed: {reason}")
                return False
            
            # Execute trade
            logger.info(f"🚀 Executing {signal.signal_type} trade for {symbol}")
            
            result = self.trade_executor.open_position(
                symbol=symbol,
                signal_type=signal.signal_type,
                volume=lot_size,
                price=signal.entry_price,
                sl=signal.stop_loss,
                tp=signal.take_profit_2,  # Use TP2 as main TP
                comment=f"Aziz v2.0 - {signal.reason[:20]}"
            )
            
            if result and result.get('success'):
                logger.success(f"✅ Trade executed successfully!")
                
                # Store active position
                self.active_positions[symbol] = {
                    "signal": signal,
                    "order": result['order'],
                    "deal": result['deal'],
                    "volume": result['volume'],
                    "entry_price": result['price'],
                    "open_time": datetime.now(),
                    "tp1_hit": False
                }
                
                return True
            else:
                logger.error(f"Failed to execute trade: {result}")
                return False
                
        except Exception as e:
            logger.exception(f"Error executing signal: {e}")
            return False
    
    def monitor_positions(self):
        """Monitor open positions and manage TP1/TP2/SL"""
        if not self.active_positions:
            return
        
        for symbol, pos_data in list(self.active_positions.items()):
            try:
                # Get current position from MT5
                positions = self.mt5_connector.get_open_positions(symbol)
                
                if not positions:
                    # Position closed
                    logger.info(f"Position {symbol} closed")
                    del self.active_positions[symbol]
                    continue
                
                position = positions[0]
                signal = pos_data['signal']
                
                # Check TP1
                if not pos_data['tp1_hit']:
                    if signal.signal_type == "BUY":
                        if position['price_current'] >= signal.take_profit_1:
                            logger.info(f"✅ TP1 reached for {symbol}!")
                            pos_data['tp1_hit'] = True
                            # Move SL to breakeven
                            self.trade_executor.modify_position(
                                position_ticket=position['ticket'],
                                sl=signal.entry_price
                            )
                    else:  # SELL
                        if position['price_current'] <= signal.take_profit_1:
                            logger.info(f"✅ TP1 reached for {symbol}!")
                            pos_data['tp1_hit'] = True
                            self.trade_executor.modify_position(
                                position_ticket=position['ticket'],
                                sl=signal.entry_price
                            )
                
            except Exception as e:
                logger.error(f"Error monitoring position {symbol}: {e}")
    
    def run_trading_loop(self, interval: int = 60):
        """
        Main trading loop
        
        Args:
            interval: Loop interval in seconds
        """
        logger.info(f"📊 Starting trading loop (interval: {interval}s)")
        
        while self.is_running:
            try:
                logger.info("=" * 60)
                logger.info(f"🔄 Trading Cycle - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
                logger.info("=" * 60)
                
                # Monitor existing positions
                self.monitor_positions()
                
                # Analyze each symbol
                for symbol in self.settings.trading_symbols:
                    logger.info(f"Analyzing {symbol}...")
                    
                    signal_data = self.analyze_symbol(symbol, "M15")
                    
                    if signal_data:
                        # Check if we already have a position
                        if symbol in self.active_positions:
                            logger.info(f"Already have position in {symbol}, skipping")
                            continue
                        
                        # Execute signal
                        self.execute_signal(signal_data)
                
                # Display statistics
                stats = self.risk_manager.get_statistics()
                logger.info(f"📊 Statistics: Trades: {stats['total_trades']}, "
                           f"Win Rate: {stats['win_rate']:.1f}%, "
                           f"P&L: ${stats['total_pnl']:.2f}")
                
                # Sleep until next cycle
                logger.info(f"💤 Sleeping for {interval} seconds...")
                time.sleep(interval)
                
            except KeyboardInterrupt:
                logger.info("Keyboard interrupt received")
                break
            except Exception as e:
                logger.exception(f"Error in trading loop: {e}")
                time.sleep(interval)
        
        logger.info("Trading loop stopped")


def main():
    """Main entry point"""
    from loguru import logger
    import sys
    
    # Configure logging
    logger.remove()
    logger.add(sys.stderr, level="INFO")
    logger.add("backend/logs/traderobot.log", rotation="1 day", retention="30 days", level="DEBUG")
    
    # Create and start bot
    bot = ForexTradingBot()
    
    if bot.start():
        try:
            bot.run_trading_loop(interval=300)  # 5 minutes
        except KeyboardInterrupt:
            logger.info("Shutting down...")
        finally:
            bot.stop()
    else:
        logger.error("Failed to start bot")


if __name__ == "__main__":
    main()
