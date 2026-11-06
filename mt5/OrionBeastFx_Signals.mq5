// OrionBeastFx Signals v6 — Android JSON control over protected ntfy topics.
// Starts STOPPED. RUN/STOP is authenticated by ntfy topic ACLs, not a public topic name.
// Default: RUN attempts latest pending signal once. No new automatic-entry mode by default.
// Optional AutoTradeWhileRunning=true: RUN arms FUTURE signals until STOP.
// STOP blocks new entries and clears pending signals; it NEVER closes positions.
// Install OrionAppControl.mqh beside this file. See EA-INTEGRATION.md in the project.
#property copyright "OrionBeastFx"
#property version   "6.00"
#property description "Trend + spike-watch scanner; authenticated app RUN/STOP control, starts stopped."

#include <Trade\Trade.mqh>

//--- ntfy settings
input string NtfyServer         = "https://ntfy.sh";   // ntfy server
input string NtfyTopic          = "OrionBeastFx";      // ntfy topic (alerts out)

//--- trading: only on RUN from the app
input bool   TradeOnRun         = true;   // Allow opening trades when RUN is received (false = signal-only)
input string CommandTopic       = "";     // Required separate protected command topic (must match Android Settings)
input string RunKeyword         = "RUN";  // Retained for preset compatibility; plaintext commands are disabled
input int    CommandPollSeconds = 2;      // How often to check for RUN
input int    SignalValidSeconds = 120;    // A pending signal expires after this many seconds
input double LotSize            = 0.01;   // Fixed lot (used when RiskPercent = 0)
input double RiskPercent        = 0.0;    // Risk % of balance per trade (0 = use LotSize)
input int    MaxOpenTrades      = 3;      // Max open trades from this EA
input bool   OneTradePerSymbol  = true;   // Only one open trade per symbol
input double MaxSlipFracSL      = 0.3;    // Reject if price moved against you > this x SL distance
input int    SlippagePoints     = 50;     // Max deviation in points
input int    MagicNumber        = 202611; // Magic number of trades opened by this EA

//--- what to scan
input string SymbolList         = "";     // Symbols, comma separated. Empty = everything in Market Watch
input bool   ScanM1             = true;   // Trend module: scan M1
input bool   ScanM5             = true;   // Trend module: scan M5

//--- module switches
input bool   EnableTrendSignals = true;   // Module 1: trend signals
input bool   EnableSpikeWatch   = true;   // Module 2: spike watch (M1)

//--- trend settings
input int    FastEMA            = 9;      // Fast EMA
input int    SlowEMA            = 21;     // Slow EMA
input int    TrendEMA           = 50;     // Trend EMA (higher timeframe filter)
input int    RSIPeriod          = 14;     // RSI period
input int    ATRPeriod          = 14;     // ATR period
input double SL_ATR             = 1.5;    // Stop loss (x ATR)
input double TrendTPMinATR      = 1.5;    // Dynamic TP: minimum (x ATR) for a weak setup
input double TrendTPMaxATR      = 3.0;    // Dynamic TP: maximum (x ATR) for a strong setup
input bool   UseHTFFilter       = true;   // Only trade with higher-TF trend (M1->M5, M5->M15)
input int    CooldownBars       = 3;      // Min bars between trend signals per symbol/timeframe
input bool   SkipTrendAfterSpike= true;   // Ignore EMA crosses right after a spike candle

//--- spike watch: which symbols and which direction
input string UpSpikeKeyword     = "GainX";   // Symbols containing this spike UP   (BUY)
input string DownSpikeKeyword   = "PainX";   // Symbols containing this spike DOWN (SELL)

//--- spike watch: rolling MAD
input int    SpikeLookback      = 300;    // M1 bars used for rolling median / MAD
input double SpikeZ             = 8.0;    // Robust z-score of candle range that counts as a spike
input int    FallbackInterval   = 15;     // Bars between spikes if history is too thin
input int    MinSpikesInHistory = 2;      // Spikes needed in lookback before alerts are allowed

//--- spike watch: tick acceleration
input int    TickWindow         = 8;      // Ticks per velocity window (now vs previous)
input int    TickLookback       = 150;    // Ticks pulled for the MAD scale
input double SpikeTickZ         = 15.0;   // A tick this many MADs away = spike already printing
input double AccZFull            = 3.0;   // Accel z-score that gives full acceleration score
input double DriftZFull         = 3.0;    // Drift z-score that gives full drift score

//--- spike watch: scoring
input double W_Time             = 0.30;   // Weight: bars since spike vs typical interval
input double W_Drift            = 0.25;   // Weight: drift away from spike direction
input double W_RSI              = 0.20;   // Weight: RSI exhaustion
input double W_Accel            = 0.25;   // Weight: tick acceleration
input double SpikeAlertScore    = 70.0;   // Alert when score (0-100) reaches this
input int    SpikeCooldownBars  = 8;      // Bars to stay quiet after a spike alert

//--- spike watch: dynamic TP / SL
input int    SpikeRecentCount   = 5;      // TP is based on the median of the last N spikes
input double SpikeTPMinFrac     = 0.5;    // TP fraction of recent spike size at the lowest score
input double SpikeTPMaxFrac     = 1.0;    // TP fraction of recent spike size at score 100
input double SpikeSLFrac        = 0.6;    // SL = TP x this (before the drift allowance)
input double SpikeDriftSLMult   = 1.5;    // SL must also cover expected drift until the spike x this

//--- misc
input bool   SendStartupMsg     = true;   // Send a message when EA starts
input bool   TerminalAlert      = false;  // Pop-up alert in MT5 (off = cleaner)

CTrade trade;

//--- trend items (parallel arrays, one entry per symbol/timeframe)
string          g_sym[];
ENUM_TIMEFRAMES g_tf[];
ENUM_TIMEFRAMES g_htf[];
int             g_hFast[];
int             g_hSlow[];
int             g_hRSI[];
int             g_hATR[];
int             g_hHTF[];
datetime        g_last[];
int             g_since[];

//--- spike-watch items (one entry per spike symbol)
string          gs_sym[];
int             gs_dir[];
int             gs_hRSI[];
datetime        gs_last[];
bool            gs_ready[];
int             gs_cool[];
int             gs_barsSince[];
int             gs_nSpikes[];
double          gs_interval[];
double          gs_medSize[];
double          gs_recentSize[];
double          gs_sizeP75[];
double          gs_medC[];
double          gs_scC[];
double          gs_zDrift[];
double          gs_rsi[];
double          gs_sT[];
double          gs_sD[];
double          gs_sR[];

//--- pending signals waiting for RUN
int             pq_id[];
string          pq_sym[];
int             pq_dir[];
double          pq_entry[];
double          pq_sl[];      // stop distance
double          pq_tp[];      // take-profit distance
datetime        pq_time[];

int    g_nextId     = 1;
bool   g_baseline   = false;
string g_lastCmdId  = "";
int    g_secTick    = 0;

#include "OrionAppControl.mqh"

//+------------------------------------------------------------------+
int OnInit()
{
   if(!ControlInit()) return(INIT_PARAMETERS_INCORRECT);
   string syms[];
   int n = 0;

   if(StringLen(SymbolList) > 0)
   {
      string raw[];
      int parts = StringSplit(SymbolList, ',', raw);
      for(int a = 0; a < parts; a++)
      {
         string s = raw[a];
         StringTrimLeft(s);
         StringTrimRight(s);
         if(StringLen(s) == 0) continue;
         if(!SymbolSelect(s, true))
         {
            Print("Symbol not found: ", s);
            continue;
         }
         ArrayResize(syms, n + 1);
         syms[n] = s;
         n++;
      }
   }
   else
   {
      int total = SymbolsTotal(true);   // Market Watch only
      for(int b = 0; b < total; b++)
      {
         ArrayResize(syms, n + 1);
         syms[n] = SymbolName(b, true);
         n++;
      }
   }

   if(n == 0)
   {
      Alert("OrionBeastFx_Signals: no symbols to scan.");
      return(INIT_FAILED);
   }

   if(EnableTrendSignals)
   {
      for(int c = 0; c < n; c++)
      {
         if(ScanM1) AddItem(syms[c], PERIOD_M1, PERIOD_M5);
         if(ScanM5) AddItem(syms[c], PERIOD_M5, PERIOD_M15);
      }
   }

   if(EnableSpikeWatch)
   {
      for(int e = 0; e < n; e++)
      {
         int dir = SpikeDir(syms[e]);
         if(dir != 0) AddSpike(syms[e], dir);
      }
   }

   int feeds  = ArraySize(g_sym);
   int spikes = ArraySize(gs_sym);
   if(feeds == 0 && spikes == 0)
   {
      Alert("OrionBeastFx_Signals: nothing to scan.");
      return(INIT_FAILED);
   }

   if(!EventSetTimer(1)) return(INIT_FAILED);

   Print("OrionBeastFx_Signals: ", IntegerToString(feeds), " trend feeds, ",
         IntegerToString(spikes), " spike-watch symbols");

   if(SendStartupMsg)
   {
      string mode = "Signal-only (trading off)";
      if(TradeOnRun)
         mode = "Starts STOPPED. App JSON RUN/STOP; mode: " + (AutoTradeWhileRunning ? "continuous opt-in" : "manual latest pending") +
                "; max " + IntegerToString(MaxOpenTrades) + " trades";
      SendNtfy("OrionBeastFx Online",
               "Trend feeds: " + IntegerToString(feeds) +
               " | Spike watch symbols: " + IntegerToString(spikes) + "\n" + mode,
               "default", "white_check_mark");
   }
   ControlSendStatus();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void AddItem(const string sym, const ENUM_TIMEFRAMES tf, const ENUM_TIMEFRAMES htf)
{
   int hf = iMA(sym, tf, FastEMA, 0, MODE_EMA, PRICE_CLOSE);
   int hs = iMA(sym, tf, SlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   int hr = iRSI(sym, tf, RSIPeriod, PRICE_CLOSE);
   int ha = iATR(sym, tf, ATRPeriod);
   int hh = iMA(sym, htf, TrendEMA, 0, MODE_EMA, PRICE_CLOSE);

   if(hf == INVALID_HANDLE || hs == INVALID_HANDLE || hr == INVALID_HANDLE ||
      ha == INVALID_HANDLE || hh == INVALID_HANDLE)
   {
      Print("Skipping ", sym, " ", TfName(tf), " (indicator handle failed)");
      if(hf != INVALID_HANDLE) IndicatorRelease(hf);
      if(hs != INVALID_HANDLE) IndicatorRelease(hs);
      if(hr != INVALID_HANDLE) IndicatorRelease(hr);
      if(ha != INVALID_HANDLE) IndicatorRelease(ha);
      if(hh != INVALID_HANDLE) IndicatorRelease(hh);
      return;
   }

   int k = ArraySize(g_sym);
   ArrayResize(g_sym,   k + 1);
   ArrayResize(g_tf,    k + 1);
   ArrayResize(g_htf,   k + 1);
   ArrayResize(g_hFast, k + 1);
   ArrayResize(g_hSlow, k + 1);
   ArrayResize(g_hRSI,  k + 1);
   ArrayResize(g_hATR,  k + 1);
   ArrayResize(g_hHTF,  k + 1);
   ArrayResize(g_last,  k + 1);
   ArrayResize(g_since, k + 1);

   g_sym[k]   = sym;
   g_tf[k]    = tf;
   g_htf[k]   = htf;
   g_hFast[k] = hf;
   g_hSlow[k] = hs;
   g_hRSI[k]  = hr;
   g_hATR[k]  = ha;
   g_hHTF[k]  = hh;
   g_last[k]  = 0;
   g_since[k] = 1000;
}

//+------------------------------------------------------------------+
void AddSpike(const string sym, const int dir)
{
   int hr = iRSI(sym, PERIOD_M1, RSIPeriod, PRICE_CLOSE);
   if(hr == INVALID_HANDLE)
   {
      Print("Spike watch skipped for ", sym, " (RSI handle failed)");
      return;
   }

   int k = ArraySize(gs_sym);
   ArrayResize(gs_sym,        k + 1);
   ArrayResize(gs_dir,        k + 1);
   ArrayResize(gs_hRSI,       k + 1);
   ArrayResize(gs_last,       k + 1);
   ArrayResize(gs_ready,      k + 1);
   ArrayResize(gs_cool,       k + 1);
   ArrayResize(gs_barsSince,  k + 1);
   ArrayResize(gs_nSpikes,    k + 1);
   ArrayResize(gs_interval,   k + 1);
   ArrayResize(gs_medSize,    k + 1);
   ArrayResize(gs_recentSize, k + 1);
   ArrayResize(gs_sizeP75,    k + 1);
   ArrayResize(gs_medC,       k + 1);
   ArrayResize(gs_scC,        k + 1);
   ArrayResize(gs_zDrift,     k + 1);
   ArrayResize(gs_rsi,        k + 1);
   ArrayResize(gs_sT,         k + 1);
   ArrayResize(gs_sD,         k + 1);
   ArrayResize(gs_sR,         k + 1);

   gs_sym[k]        = sym;
   gs_dir[k]        = dir;
   gs_hRSI[k]       = hr;
   gs_last[k]       = 0;
   gs_ready[k]      = false;
   gs_cool[k]       = 0;
   gs_barsSince[k]  = 0;
   gs_nSpikes[k]    = 0;
   gs_interval[k]   = (double)FallbackInterval;
   gs_medSize[k]    = 0.0;
   gs_recentSize[k] = 0.0;
   gs_sizeP75[k]    = 0.0;
   gs_medC[k]       = 0.0;
   gs_scC[k]        = 0.0;
   gs_zDrift[k]     = 0.0;
   gs_rsi[k]        = 50.0;
   gs_sT[k]         = 0.0;
   gs_sD[k]         = 0.0;
   gs_sR[k]         = 0.0;
}

//+------------------------------------------------------------------+
int SpikeDir(const string sym)
{
   string u  = sym;
   string up = UpSpikeKeyword;
   string dn = DownSpikeKeyword;
   StringToUpper(u);
   StringToUpper(up);
   StringToUpper(dn);
   if(StringLen(up) > 0 && StringFind(u, up) >= 0) return(1);
   if(StringLen(dn) > 0 && StringFind(u, dn) >= 0) return(-1);
   return(0);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ControlDeinit();
   EventKillTimer();
   int total = ArraySize(g_sym);
   for(int i = 0; i < total; i++)
   {
      IndicatorRelease(g_hFast[i]);
      IndicatorRelease(g_hSlow[i]);
      IndicatorRelease(g_hRSI[i]);
      IndicatorRelease(g_hATR[i]);
      IndicatorRelease(g_hHTF[i]);
   }
   int sp = ArraySize(gs_sym);
   for(int j = 0; j < sp; j++)
      IndicatorRelease(gs_hRSI[j]);
}

//+------------------------------------------------------------------+
void OnTick()
{
   // all work is done in OnTimer so every symbol is covered
}

//+------------------------------------------------------------------+
void OnTimer()
{
   // Poll even in signal-only mode so STOP and status reports always work.
   ControlTimer();

   // 2) scan for signals
   int total = ArraySize(g_sym);
   for(int i = 0; i < total; i++)
      Check(i);

   int sp = ArraySize(gs_sym);
   for(int j = 0; j < sp; j++)
      SpikeCheck(j);

   // Explicit opt-in only. RUN cleared the old queue; these are fresh signals.
   if(AutoTradeWhileRunning && g_remoteRunning && TradeOnRun)
   {
      PurgeQueue();
      while(ArraySize(pq_id)>0 && g_remoteRunning) ExecuteQueued(0);
   }
}

//+==================================================================+
//|  MATH HELPERS                                                    |
//+==================================================================+
double Clamp01(const double x)
{
   if(x < 0.0) return(0.0);
   if(x > 1.0) return(1.0);
   return(x);
}

//--- median of the first n values of a[]
double Median(const double &a[], const int n)
{
   if(n <= 0) return(0.0);
   double tmp[];
   ArrayResize(tmp, n);
   ArrayCopy(tmp, a, 0, 0, n);
   ArraySort(tmp);
   if((n % 2) == 1) return(tmp[n / 2]);
   return((tmp[n / 2 - 1] + tmp[n / 2]) / 2.0);
}

//--- percentile (0..1) of the first n values of a[]
double Percentile(const double &a[], const int n, const double p)
{
   if(n <= 0) return(0.0);
   double tmp[];
   ArrayResize(tmp, n);
   ArrayCopy(tmp, a, 0, 0, n);
   ArraySort(tmp);
   double pos = p * (double)(n - 1);
   int lo = (int)MathFloor(pos);
   int hi = (int)MathCeil(pos);
   if(hi >= n) hi = n - 1;
   double frac = pos - (double)lo;
   return(tmp[lo] + (tmp[hi] - tmp[lo]) * frac);
}

//--- rolling MAD scaled to behave like a standard deviation (1.4826 x MAD)
double MadScale(const double &a[], const int n, const double med)
{
   if(n <= 0) return(0.0);
   double dev[];
   ArrayResize(dev, n);
   for(int i = 0; i < n; i++)
      dev[i] = MathAbs(a[i] - med);
   return(1.4826 * Median(dev, n));
}

//--- true if one of the last two closed bars on this tf is a robust-z spike candle
bool LastBarIsSpike(const string sym, const ENUM_TIMEFRAMES tf)
{
   MqlRates r[];
   ArraySetAsSeries(r, true);
   int got = CopyRates(sym, tf, 1, 100, r);
   if(got < 30) return(false);

   double rng[];
   ArrayResize(rng, got);
   for(int i = 0; i < got; i++)
      rng[i] = r[i].high - r[i].low;

   double pt  = SymbolInfoDouble(sym, SYMBOL_POINT);
   double med = Median(rng, got);
   double sc  = MadScale(rng, got, med);
   double fl  = MathMax(med * 0.1, pt);
   if(sc < fl) sc = fl;

   if((rng[0] - med) / sc > SpikeZ) return(true);
   if((rng[1] - med) / sc > SpikeZ) return(true);
   return(false);
}

//+==================================================================+
//|  PENDING SIGNAL QUEUE                                            |
//+==================================================================+
void RemoveQueued(const int q)
{
   int n = ArraySize(pq_id);
   if(q < 0 || q >= n) return;
   for(int i = q; i < n - 1; i++)
   {
      pq_id[i]    = pq_id[i + 1];
      pq_sym[i]   = pq_sym[i + 1];
      pq_dir[i]   = pq_dir[i + 1];
      pq_entry[i] = pq_entry[i + 1];
      pq_sl[i]    = pq_sl[i + 1];
      pq_tp[i]    = pq_tp[i + 1];
      pq_time[i]  = pq_time[i + 1];
   }
   ArrayResize(pq_id,    n - 1);
   ArrayResize(pq_sym,   n - 1);
   ArrayResize(pq_dir,   n - 1);
   ArrayResize(pq_entry, n - 1);
   ArrayResize(pq_sl,    n - 1);
   ArrayResize(pq_tp,    n - 1);
   ArrayResize(pq_time,  n - 1);
}

void PurgeQueue()
{
   for(int i = ArraySize(pq_id) - 1; i >= 0; i--)
   {
      if(TimeCurrent() - pq_time[i] > SignalValidSeconds)
         RemoveQueued(i);
   }
}

//--- park a signal until the app sends RUN. Returns its ID (0 if trading is off)
int QueueSignal(const string sym, const int dir, const double entry,
                const double slDist, const double tpDist)
{
   if(!TradeOnRun) return(0);

   PurgeQueue();
   while(ArraySize(pq_id) >= 30) RemoveQueued(0);

   int k = ArraySize(pq_id);
   ArrayResize(pq_id,    k + 1);
   ArrayResize(pq_sym,   k + 1);
   ArrayResize(pq_dir,   k + 1);
   ArrayResize(pq_entry, k + 1);
   ArrayResize(pq_sl,    k + 1);
   ArrayResize(pq_tp,    k + 1);
   ArrayResize(pq_time,  k + 1);

   int id = g_nextId;
   g_nextId++;

   pq_id[k]    = id;
   pq_sym[k]   = sym;
   pq_dir[k]   = dir;
   pq_entry[k] = entry;
   pq_sl[k]    = slDist;
   pq_tp[k]    = tpDist;
   pq_time[k]  = TimeCurrent();
   return(id);
}

//+==================================================================+
//|  RUN COMMAND LISTENER (ntfy poll)                                |
//+==================================================================+
// JSON listener implemented in OrionAppControl.mqh.

//+==================================================================+
//|  TRADE EXECUTION                                                 |
//+==================================================================+
int CountMyPositions(const string sym)
{
   int cnt = 0;
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      string ps = PositionGetSymbol(i);        // also selects the position
      if(StringLen(ps) == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)MagicNumber) continue;
      if(StringLen(sym) > 0 && ps != sym) continue;
      cnt++;
   }
   return(cnt);
}

double CalcLots(const string sym, const double slDist)
{
   double minL = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   double maxL = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);

   double lots = LotSize;
   if(RiskPercent > 0.0 && slDist > 0.0)
   {
      double tv = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
      double ts = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
      if(tv > 0.0 && ts > 0.0)
      {
         double riskMoney  = AccountInfoDouble(ACCOUNT_BALANCE) * RiskPercent / 100.0;
         double lossPerLot = slDist / ts * tv;
         if(lossPerLot > 0.0) lots = riskMoney / lossPerLot;
      }
   }

   int vd = 2;
   if(step > 0.0)
   {
      lots = MathFloor(lots / step + 0.000000001) * step;
      vd = (int)MathMax(0.0, MathCeil(-MathLog10(step)));
   }
   if(lots < minL) lots = minL;
   if(lots > maxL) lots = maxL;
   return(NormalizeDouble(lots, vd));
}

bool TryTrade(const string sym, const int dir, const int id, const double entry,
              double slD, double tpD, const datetime tq, string &report)
{
   report = "";

   if(!TradeOnRun)
   { report = "Trading is disabled in EA inputs."; return(false); }
   if(!g_remoteRunning)
   { report = "STOP active: new entries are disabled."; return(false); }

   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
   { report = "Algo Trading is OFF in MT5. Turn it on and run again."; return(false); }

   if(TimeCurrent() - tq > SignalValidSeconds)
   { report = "Signal expired."; return(false); }

   ENUM_SYMBOL_TRADE_MODE mode = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(sym, SYMBOL_TRADE_MODE);
   bool allowed = (mode == SYMBOL_TRADE_MODE_FULL) ||
                  (mode == SYMBOL_TRADE_MODE_LONGONLY  && dir > 0) ||
                  (mode == SYMBOL_TRADE_MODE_SHORTONLY && dir < 0);
   if(!allowed)
   { report = sym + " is not tradable right now."; return(false); }

   if(CountMyPositions("") >= MaxOpenTrades)
   { report = "Max open trades reached (" + IntegerToString(MaxOpenTrades) + ")."; return(false); }

   if(OneTradePerSymbol && CountMyPositions(sym) > 0)
   { report = "A trade is already open on " + sym + "."; return(false); }

   double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
   { report = "No price for " + sym + "."; return(false); }

   int d = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);

   // price already ran away from the signal price?
   double adverse = (dir > 0) ? (ask - entry) : (entry - bid);
   if(adverse > MaxSlipFracSL * slD)
   {
      report = "Price moved " + DoubleToString(adverse, d) + " against the signal (limit " +
               DoubleToString(MaxSlipFracSL * slD, d) + ").";
      return(false);
   }

   // respect broker minimum stop distance
   double pt   = SymbolInfoDouble(sym, SYMBOL_POINT);
   double need = ((double)SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL)) * pt + (ask - bid);
   if(slD < need * 1.1) slD = need * 1.1;
   if(tpD < need * 1.1) tpD = need * 1.1;

   double price = (dir > 0) ? ask : bid;
   double sl = NormalizeDouble(price - (double)dir * slD, d);
   double tp = NormalizeDouble(price + (double)dir * tpD, d);
   double lots = CalcLots(sym, slD);

   trade.SetExpertMagicNumber((ulong)MagicNumber);
   trade.SetDeviationInPoints((ulong)SlippagePoints);
   trade.SetTypeFillingBySymbol(sym);

   string cmt = "OBFX#" + IntegerToString(id);
   bool ok = false;
   if(dir > 0) ok = trade.Buy(lots, sym, 0.0, sl, tp, cmt);
   else        ok = trade.Sell(lots, sym, 0.0, sl, tp, cmt);

   uint rc = trade.ResultRetcode();
   if(ok && (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_PLACED || rc == TRADE_RETCODE_DONE_PARTIAL))
   {
      report = "Lots: " + DoubleToString(lots, 2) + "\n" +
               "Price: " + DoubleToString(trade.ResultPrice(), d) + "\n" +
               "SL: " + DoubleToString(sl, d) + "\n" +
               "TP: " + DoubleToString(tp, d) + "\n" +
               "Order: " + IntegerToString((long)trade.ResultOrder());
      return(true);
   }

   report = "Order failed: " + trade.ResultRetcodeDescription() + " (" + IntegerToString((int)rc) + ")";
   return(false);
}

void ExecuteQueued(const int q)
{
   if(q < 0 || q >= ArraySize(pq_id)) return;

   string   sym   = pq_sym[q];
   int      dir   = pq_dir[q];
   int      id    = pq_id[q];
   double   entry = pq_entry[q];
   double   slD   = pq_sl[q];
   double   tpD   = pq_tp[q];
   datetime tq    = pq_time[q];
   RemoveQueued(q);

   string side = "SELL";
   if(dir > 0) side = "BUY";

   string report = "";
   bool ok = TryTrade(sym, dir, id, entry, slD, tpD, tq, report);

   if(ok)
      SendNtfy("TRADE OPENED " + side + " " + sym,
               "Opened " + side + " " + sym + " (signal #" + IntegerToString(id) + ")\n" + report,
               "high", "white_check_mark");
   else
      SendNtfy("TRADE REJECTED " + sym,
               "Signal #" + IntegerToString(id) + " " + side + " " + sym + "\n" + report,
               "high", "x");

   g_controlNote=(ok ? "Order accepted by MT5: " : "Trade rejected: ")+report;
   ControlSendStatus();
   Print("RUN #", IntegerToString(id), " ", side, " ", sym, ": ", (ok ? "OPENED" : "REJECTED"), " | ", report);
}

//+==================================================================+
//|  MODULE 1 - TREND                                                |
//+==================================================================+
void Check(const int i)
{
   string          sym = g_sym[i];
   ENUM_TIMEFRAMES tf  = g_tf[i];
   ENUM_TIMEFRAMES htf = g_htf[i];

   datetime t = iTime(sym, tf, 0);
   if(t == 0) return;                          // data not ready yet
   if(g_last[i] == 0)                          // first run: don't fire on an old bar
   {
      g_last[i] = t;
      return;
   }
   if(t == g_last[i]) return;                  // act once per new bar
   g_last[i] = t;
   g_since[i]++;

   double fast[], slow[], rsi[], atr[], htfMa[];
   ArraySetAsSeries(fast,  true);
   ArraySetAsSeries(slow,  true);
   ArraySetAsSeries(rsi,   true);
   ArraySetAsSeries(atr,   true);
   ArraySetAsSeries(htfMa, true);

   if(CopyBuffer(g_hFast[i], 0, 0, 3, fast)  < 3) return;
   if(CopyBuffer(g_hSlow[i], 0, 0, 3, slow)  < 3) return;
   if(CopyBuffer(g_hRSI[i],  0, 0, 2, rsi)   < 2) return;
   if(CopyBuffer(g_hATR[i],  0, 0, 2, atr)   < 2) return;
   if(CopyBuffer(g_hHTF[i],  0, 0, 3, htfMa) < 3) return;

   if(g_since[i] < CooldownBars) return;

   // EMA cross on the last closed bar (shift 1 vs shift 2)
   bool crossUp   = (fast[2] <= slow[2] && fast[1] > slow[1]);
   bool crossDown = (fast[2] >= slow[2] && fast[1] < slow[1]);
   if(!crossUp && !crossDown) return;

   // a cross right after a spike candle is noise
   if(SkipTrendAfterSpike && LastBarIsSpike(sym, tf)) return;

   // Higher timeframe trend filter
   double htfClose = iClose(sym, htf, 1);
   bool htfUp   = true;
   bool htfDown = true;
   if(UseHTFFilter)
   {
      htfUp   = (htfClose > htfMa[1] && htfMa[1] >= htfMa[2]);
      htfDown = (htfClose < htfMa[1] && htfMa[1] <= htfMa[2]);
   }

   // RSI momentum confirmation
   bool buyOK  = (crossUp   && htfUp   && rsi[1] > 50.0 && rsi[1] < 70.0);
   bool sellOK = (crossDown && htfDown && rsi[1] < 50.0 && rsi[1] > 30.0);
   if(!buyOK && !sellOK) return;

   double range = atr[1];
   if(range <= 0.0) return;

   // dynamic TP: stronger setup (RSI momentum + stretch above HTF average) = bigger target
   double htfExt   = MathAbs(htfClose - htfMa[1]) / range;
   double strength = 0.5 * Clamp01(MathAbs(rsi[1] - 50.0) / 20.0) + 0.5 * Clamp01(htfExt / 2.0);
   double tpMult   = TrendTPMinATR + (TrendTPMaxATR - TrendTPMinATR) * strength;
   double tpDist   = range * tpMult;
   double slDist   = range * SL_ATR;

   if(buyOK)
   {
      double entry = SymbolInfoDouble(sym, SYMBOL_ASK);
      SendSignal(sym, tf, "BUY", 1, entry, slDist, tpDist, tpMult, strength, rsi[1]);
      g_since[i] = 0;
   }
   else
   {
      double entry = SymbolInfoDouble(sym, SYMBOL_BID);
      SendSignal(sym, tf, "SELL", -1, entry, slDist, tpDist, tpMult, strength, rsi[1]);
      g_since[i] = 0;
   }
}

//+------------------------------------------------------------------+
void SendSignal(const string sym, const ENUM_TIMEFRAMES tf, const string dirTxt, const int dir,
                const double entry, const double slDist, const double tpDist,
                const double tpMult, const double strength, const double rsiVal)
{
   int d = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   double sl = entry - (double)dir * slDist;
   double tp = entry + (double)dir * tpDist;
   int id = QueueSignal(sym, dir, entry, slDist, tpDist);

   string tfn   = TfName(tf);
   string title = dirTxt + " " + sym + " " + tfn;
   string body  =
      "Signal: " + dirTxt + "\n" +
      "Symbol: " + sym + "\n" +
      "TF: "     + tfn + "\n" +
      "Entry: "  + DoubleToString(entry, d) + "\n" +
      "SL: "     + DoubleToString(sl, d) + "\n" +
      "TP: "     + DoubleToString(tp, d) + " (dynamic " + DoubleToString(tpMult, 2) + " ATR)\n" +
      "RR: "     + DoubleToString(tpDist / slDist, 2) + "\n" +
      "Strength: " + DoubleToString(strength * 100.0, 0) + "%\n" +
      "RSI: "    + DoubleToString(rsiVal, 1) + "\n" +
      "Time: "   + TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES);
   if(id > 0)
      body += "\nID: " + IntegerToString(id) + "  (use app RUN; manual mode selects latest pending signal)";

   string tag = "chart_with_downwards_trend,red_circle";
   if(dir > 0) tag = "chart_with_upwards_trend,green_circle";

   if(TerminalAlert) Alert(title, " @ ", DoubleToString(entry, d));
   SendNtfy(title, body, "high", tag);
}

//+==================================================================+
//|  MODULE 2 - SPIKE WATCH (M1)                                     |
//+==================================================================+

//--- runs once per new M1 bar: rolling MAD, spike history, drift, RSI
void UpdateSpikeBar(const int s)
{
   string sym = gs_sym[s];
   int    dir = gs_dir[s];
   gs_ready[s] = false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int n = CopyRates(sym, PERIOD_M1, 1, SpikeLookback, rates);
   if(n < 60) return;

   double pt = SymbolInfoDouble(sym, SYMBOL_POINT);

   // 1) rolling median + MAD of candle range
   double rng[];
   ArrayResize(rng, n);
   for(int i = 0; i < n; i++)
      rng[i] = rates[i].high - rates[i].low;

   double medR = Median(rng, n);
   double scR  = MadScale(rng, n, medR);
   double flR  = MathMax(medR * 0.1, pt);
   if(scR < flR) scR = flR;

   // 2) find past spike candles (right direction, robust z above SpikeZ)
   //    index 0 = most recent closed bar, so sizes[] is ordered newest first
   int    idx[];
   double sizes[];
   int    cnt = 0;
   for(int i = 0; i < n; i++)
   {
      double z = (rng[i] - medR) / scR;
      bool right = (dir > 0) ? (rates[i].close > rates[i].open)
                             : (rates[i].close < rates[i].open);
      if(z > SpikeZ && right)
      {
         ArrayResize(idx,   cnt + 1);
         ArrayResize(sizes, cnt + 1);
         idx[cnt]   = i;
         sizes[cnt] = rng[i];
         cnt++;
      }
   }

   int barsSince = n;
   if(cnt > 0) barsSince = idx[0];

   double interval = (double)FallbackInterval;
   if(cnt >= 3)
   {
      double gaps[];
      ArrayResize(gaps, cnt - 1);
      for(int k = 1; k < cnt; k++)
         gaps[k - 1] = (double)(idx[k] - idx[k - 1]);
      interval = Median(gaps, cnt - 1);
   }
   if(interval < 1.0) interval = 1.0;

   // spike size statistics: overall median, recent median (drives TP), 75th percentile (caps TP)
   double medSize = 0.0;
   double recent  = 0.0;
   double p75     = 0.0;
   if(cnt > 0)
   {
      medSize = Median(sizes, cnt);
      p75     = Percentile(sizes, cnt, 0.75);
      int nr = MathMin(cnt, MathMax(1, SpikeRecentCount));
      double rec[];
      ArrayResize(rec, nr);
      for(int k = 0; k < nr; k++) rec[k] = sizes[k];
      recent = Median(rec, nr);
   }

   // 3) drift since last spike, in MAD units of close-to-close moves
   int m = n - 1;
   double cd[];
   ArrayResize(cd, m);
   for(int i = 0; i < m; i++)
      cd[i] = rates[i].close - rates[i + 1].close;

   double medC = Median(cd, m);
   double scC  = MadScale(cd, m, medC);
   if(scC < pt) scC = pt;

   int L = MathMin(30, n - 1);
   if(cnt > 0) L = idx[0];

   double zDrift = 0.0;
   if(L >= 1 && L < n)
   {
      double drift = -(double)dir * (rates[0].close - rates[L].close);
      zDrift = drift / (scC * MathSqrt((double)L));
   }

   // 4) RSI on the last closed M1 bar
   double rb[];
   ArraySetAsSeries(rb, true);
   if(CopyBuffer(gs_hRSI[s], 0, 1, 1, rb) < 1) return;
   double rsiVal = rb[0];

   // 5) component scores (0..1)
   double sT = 0.0;
   if(barsSince >= 2) sT = Clamp01((double)barsSince / interval);
   double sD = Clamp01(zDrift / DriftZFull);
   double sR = Clamp01((double)dir * (50.0 - rsiVal) / 20.0);

   gs_barsSince[s]  = barsSince;
   gs_nSpikes[s]    = cnt;
   gs_interval[s]   = interval;
   gs_medSize[s]    = medSize;
   gs_recentSize[s] = recent;
   gs_sizeP75[s]    = p75;
   gs_medC[s]       = medC;
   gs_scC[s]        = scC;
   gs_zDrift[s]     = zDrift;
   gs_rsi[s]        = rsiVal;
   gs_sT[s]         = sT;
   gs_sD[s]         = sD;
   gs_sR[s]         = sR;
   gs_ready[s]      = true;
}

//+------------------------------------------------------------------+
//--- tick velocity acceleration (MAD-normalised) + tick-rate change
bool TickAccel(const string sym, const int dir, double &zAcc, double &rateChg, bool &spikeNow)
{
   int W = TickWindow;
   if(W < 3) W = 3;
   int want = MathMax(TickLookback, 3 * W + 20);

   MqlTick ticks[];
   int got = CopyTicks(sym, ticks, COPY_TICKS_ALL, 0, want);
   if(got < 3 * W + 10) return(false);

   double p[];
   ArrayResize(p, got);
   for(int k = 0; k < got; k++)
   {
      p[k] = ticks[k].bid;
      if(p[k] <= 0.0) p[k] = ticks[k].last;
   }

   int m = got - 1;
   double rr[];
   ArrayResize(rr, m);
   for(int k = 1; k < got; k++)
      rr[k - 1] = p[k] - p[k - 1];

   double pt  = SymbolInfoDouble(sym, SYMBOL_POINT);
   double med = Median(rr, m);
   double sc  = MadScale(rr, m, med);
   if(sc <= pt)
   {
      double sum = 0.0;
      for(int k = 0; k < m; k++) sum += MathAbs(rr[k]);
      sc = sum / (double)m;
      if(sc <= pt) sc = pt;
   }

   // a spike tick inside the recent window = it is already printing, too late
   spikeNow = false;
   int from = MathMax(0, m - 2 * W);
   for(int k = from; k < m; k++)
   {
      if(MathAbs(rr[k] - med) > SpikeTickZ * sc)
      {
         spikeNow = true;
         break;
      }
   }

   int last = got - 1;
   double R1 = p[last] - p[last - W];            // move over the latest W ticks
   double R0 = p[last - W] - p[last - 2 * W];    // move over the W ticks before that
   zAcc = (double)dir * (R1 - R0) / (sc * MathSqrt(2.0 * (double)W));

   // tick rate: last 5s vs previous 5s
   long tl = ticks[last].time_msc;
   int c1 = 0;
   int c0 = 0;
   for(int k = last; k >= 0; k--)
   {
      long dt = tl - ticks[k].time_msc;
      if(dt < 5000) c1++;
      else if(dt < 10000) c0++;
      else break;
   }
   rateChg = ((double)c1 - (double)c0) / MathMax((double)c0, 1.0);
   return(true);
}

//+------------------------------------------------------------------+
//--- dynamic SL / TP distances for a spike trade
//    TP  = recent spike size x (min..max fraction by score), capped at the 75th percentile
//    SL  = max( TP x SpikeSLFrac , expected drift until the spike arrives x multiplier )
void SpikeLevels(const int s, const double score, double &slDist, double &tpDist)
{
   string sym    = gs_sym[s];
   double pt     = SymbolInfoDouble(sym, SYMBOL_POINT);
   double spread = SymbolInfoDouble(sym, SYMBOL_ASK) - SymbolInfoDouble(sym, SYMBOL_BID);
   double minD   = MathMax(spread * 3.0, pt * 10.0);

   double conf = 1.0;
   if(SpikeAlertScore < 100.0)
      conf = Clamp01((score - SpikeAlertScore) / (100.0 - SpikeAlertScore));

   double frac = SpikeTPMinFrac + (SpikeTPMaxFrac - SpikeTPMinFrac) * conf;
   double tp   = gs_recentSize[s] * frac;
   if(gs_sizeP75[s] > 0.0 && tp > gs_sizeP75[s]) tp = gs_sizeP75[s];
   if(tp < minD) tp = minD;

   double wait       = MathMax(gs_interval[s] - (double)gs_barsSince[s], 3.0);
   double driftAllow = SpikeDriftSLMult * (MathAbs(gs_medC[s]) * wait + gs_scC[s] * MathSqrt(wait));
   double sl         = MathMax(tp * SpikeSLFrac, driftAllow);
   if(sl < minD) sl = minD;

   slDist = sl;
   tpDist = tp;
}

//+------------------------------------------------------------------+
void SpikeCheck(const int s)
{
   string sym = gs_sym[s];

   datetime t = iTime(sym, PERIOD_M1, 0);
   if(t == 0) return;
   if(gs_last[s] != t)
   {
      gs_last[s] = t;
      UpdateSpikeBar(s);
      if(gs_cool[s] > 0) gs_cool[s]--;
   }

   if(!gs_ready[s]) return;
   if(gs_cool[s] > 0) return;
   if(gs_nSpikes[s] < MinSpikesInHistory) return;
   if(gs_recentSize[s] <= 0.0) return;
   if(gs_barsSince[s] < 2) return;

   double wsum = W_Time + W_Drift + W_RSI + W_Accel;
   if(wsum <= 0.0) return;

   double zAcc = 0.0;
   double rateChg = 0.0;
   bool   spikeNow = false;
   if(!TickAccel(sym, gs_dir[s], zAcc, rateChg, spikeNow)) return;
   if(spikeNow) return;

   double sA = 0.75 * Clamp01(zAcc / AccZFull) + 0.25 * Clamp01(rateChg);
   double score = 100.0 * (W_Time * gs_sT[s] + W_Drift * gs_sD[s] +
                           W_RSI * gs_sR[s] + W_Accel * sA) / wsum;
   if(score < SpikeAlertScore) return;

   double slD = 0.0;
   double tpD = 0.0;
   SpikeLevels(s, score, slD, tpD);

   SendSpikeAlert(s, score, zAcc, rateChg, slD, tpD);
   gs_cool[s] = SpikeCooldownBars;
}

//+------------------------------------------------------------------+
void SendSpikeAlert(const int s, const double score, const double zAcc, const double rateChg,
                    const double slD, const double tpD)
{
   string sym = gs_sym[s];
   int    dir = gs_dir[s];
   int    d   = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);

   string side  = "SELL";
   double entry = SymbolInfoDouble(sym, SYMBOL_BID);
   if(dir > 0)
   {
      side  = "BUY";
      entry = SymbolInfoDouble(sym, SYMBOL_ASK);
   }

   double tp = entry + (double)dir * tpD;
   double sl = entry - (double)dir * slD;
   int id = QueueSignal(sym, dir, entry, slD, tpD);

   string title = "SPIKE WATCH " + side + " " + sym + " M1 (" + DoubleToString(score, 0) + ")";
   string body  =
      "Spike watch: " + side + "\n" +
      "Symbol: "      + sym + "\n" +
      "TF: M1\n" +
      "Score: "       + DoubleToString(score, 0) + "/100\n" +
      "Entry: "       + DoubleToString(entry, d) + "\n" +
      "SL: "          + DoubleToString(sl, d) + " (dynamic)\n" +
      "TP: "          + DoubleToString(tp, d) + " (dynamic)\n" +
      "RR: "          + DoubleToString(tpD / slD, 2) + "\n" +
      "Recent spike size: " + DoubleToString(gs_recentSize[s], d) + "\n" +
      "Bars since spike: " + IntegerToString(gs_barsSince[s]) +
      " (typical " + DoubleToString(gs_interval[s], 0) + ")\n" +
      "Spikes in history: " + IntegerToString(gs_nSpikes[s]) + "\n" +
      "Drift z: "     + DoubleToString(gs_zDrift[s], 1) + "\n" +
      "RSI: "         + DoubleToString(gs_rsi[s], 1) + "\n" +
      "Tick accel z: " + DoubleToString(zAcc, 1) + "\n" +
      "Tick rate chg: " + DoubleToString(rateChg * 100.0, 0) + "%\n" +
      "Time: "        + TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES);
   if(id > 0)
      body += "\nID: " + IntegerToString(id) + "  (use app RUN; manual mode selects latest pending signal)";

   if(TerminalAlert) Alert(title, " @ ", DoubleToString(entry, d));
   SendNtfy(title, body, "urgent", "zap,warning");
}

//+==================================================================+
//|  NTFY                                                            |
//+==================================================================+
bool SendNtfy(const string title, const string message, const string priority, const string tags)
{
   string url = ControlServer() + "/" + NtfyTopic;
   string headers = "Content-Type: text/plain; charset=utf-8\r\n" +
                    "Title: "    + title    + "\r\n" +
                    "Priority: " + priority + "\r\n" +
                    "Tags: "     + tags     + "\r\n" +
                    "Authorization: Bearer " + AlertWriteToken + "\r\n";

   char   post[];
   char   result[];
   string resHeaders;

   int len = StringToCharArray(message, post, 0, WHOLE_ARRAY, CP_UTF8);
   if(len > 0) ArrayResize(post, len - 1);   // drop trailing null

   ResetLastError();
   int code = WebRequest("POST", url, headers, 5000, post, result, resHeaders);
   if(code == -1)
   {
      int err = GetLastError();
      Print("ntfy WebRequest failed, error ", IntegerToString(err));
      if(err == 4014)
         Print("-> Add https://ntfy.sh to Tools > Options > Expert Advisors > Allow WebRequest");
      return(false);
   }
   if(code != 200)
   {
      Print("ntfy HTTP ", IntegerToString(code), " ", CharArrayToString(result));
      return(false);
   }
   return(true);
}

//+------------------------------------------------------------------+
string TfName(const ENUM_TIMEFRAMES tf)
{
   string s = EnumToString(tf);
   StringReplace(s, "PERIOD_", "");
   return(s);
}
//+------------------------------------------------------------------+
