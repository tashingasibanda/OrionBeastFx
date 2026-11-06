// OrionBeastFx Signals v7 — Android JSON control over protected ntfy topics.
// Starts STOPPED. RUN/STOP is authenticated by ntfy topic ACLs, not a public topic name.
// Default: RUN attempts latest pending signal once. No new automatic-entry mode by default.
// Optional AutoTradeWhileRunning=true: RUN arms FUTURE signals until STOP.
// STOP blocks new entries and clears pending signals; it NEVER closes positions.
// Standalone v7 source: custom app-control include is bundled below. See project EA-INTEGRATION.md.
#property copyright "OrionBeastFx"
#property version   "7.00"
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

// BEGIN bundled app control — no custom .mqh file needed
// OrionBeastFx app control v6. Include after the EA globals.
// Default remains one RUN -> latest pending signal. Optional continuous mode is explicit.
input string CommandReadToken = "";       // ntfy token with read access to command topic
input string AlertWriteToken = "";        // ntfy token with write access to alert topic
input bool ConfirmProtectedTopics = false; // Confirm server ACLs restrict commands AND status publishing
input bool AutoTradeWhileRunning = false;  // false: original manual RUN; true: RUN arms future fresh signals
input int CommandMaxAgeSeconds = 60;        // Unix UTC clock must be synchronised on phone and PC
input int StatusEverySeconds = 30;

bool g_remoteRunning = false;
datetime g_startedUtc = 0;
ulong g_lastPollMs = 0;
ulong g_lastStatusMs = 0;
long g_cursorUtc = 0;
string g_ackId = "";
string g_controlNote = "Started stopped";
string g_controlLock = "";
double g_controlOwner = 0;



bool ControlTopicValid(const string s)
{
   int n=StringLen(s);
   if(n<1 || n>128) return false;
   for(int i=0;i<n;i++)
   {
      ushort c=StringGetCharacter(s,i);
      if(!((c>='a'&&c<='z')||(c>='A'&&c<='Z')||(c>='0'&&c<='9')||c=='_'||c=='-')) return false;
   }
   return true;
}
bool ControlTokenValid(const string s)
{
   if(StringLen(s)==0) return false;
   for(int i=0;i<StringLen(s);i++)
   {
      ushort c=StringGetCharacter(s,i);
      if(c<=32 || c>=127) return false;
   }
   return true;
}
bool ControlInit()
{
   // Fail closed instead of silently reading a public/shared alert topic.
   if(StringFind(NtfyServer,"https://")!=0 || StringLen(NtfyServer)<9 ||
      StringFind(NtfyServer,"?")>=0 || StringFind(NtfyServer,"#")>=0 ||
      StringFind(NtfyServer,"@")>=0 || StringFind(NtfyServer,"\r")>=0 || StringFind(NtfyServer,"\n")>=0)
   { Print("Control: use an HTTPS ntfy server URL without credentials, query or fragment."); return false; }
   if(!ControlTopicValid(NtfyTopic)||!ControlTopicValid(CommandTopic)||CommandTopic==NtfyTopic)
   { Print("Control: set valid, DIFFERENT alert and command topics (letters, digits, _ or -)."); return false; }
   if(!ControlTokenValid(CommandReadToken)||!ControlTokenValid(AlertWriteToken)||!ConfirmProtectedTopics)
   { Print("Control: configure command-read and alert-write tokens, restrict server ACLs, then confirm protected topics."); return false; }
   if(CommandPollSeconds<1||CommandPollSeconds>60||CommandMaxAgeSeconds<5||CommandMaxAgeSeconds>300||StatusEverySeconds<5||StatusEverySeconds>300||SignalValidSeconds<1||MaxOpenTrades<1)
   { Print("Control: invalid poll, TTL, heartbeat, signal lifetime or trade limit input."); return false; }
   // A single receiver/order owner prevents duplicate execution on multiple charts.
   g_controlLock=SeenKey("CHANNEL_LOCK");
   g_controlOwner=(double)ChartID();
   if(g_controlOwner==0) g_controlOwner=1;
   if(!GlobalVariableTemp(g_controlLock)||!GlobalVariableSetOnCondition(g_controlLock,g_controlOwner,0))
   { Print("Control: this account/channel already has an EA receiver. Remove the other instance or restart the terminal after a crash."); g_controlLock=""; return false; }
   g_startedUtc=TimeGMT(); g_cursorUtc=(long)g_startedUtc;
   g_baseline=true; g_remoteRunning=false;
   return true;
}
string ControlServer()
{
   string s=NtfyServer;
   while(StringLen(s)>8 && StringSubstr(s,StringLen(s)-1)=="/") s=StringSubstr(s,0,StringLen(s)-1);
   return s;
}
string JsonQuote(const string s)
{
   string r="\"";
   for(int i=0;i<StringLen(s);i++)
   {
      ushort c=StringGetCharacter(s,i);
      if(c=='"') r+="\\\"";
      else if(c=='\\') r+="\\\\";
      else if(c=='\n') r+="\\n";
      else if(c=='\r') r+="\\r";
      else if(c=='\t') r+="\\t";
      else if(c<32) r+=" ";
      else r+=ShortToString(c);
   }
   return r+"\"";
}
void JSpace(const string s,int &p)
{
   while(p<StringLen(s))
   {
      ushort c=StringGetCharacter(s,p);
      if(c!=32&&c!=9&&c!=10&&c!=13) break;
      p++;
   }
}
bool JString(const string s,int &p,string &value)
{
   value="";
   if(p>=StringLen(s)||StringGetCharacter(s,p)!='"') return false;
   p++;
   while(p<StringLen(s))
   {
      ushort c=StringGetCharacter(s,p++);
      if(c=='"') return true;
      if(c<32) return false;
      if(c!='\\') { value+=ShortToString(c); continue; }
      if(p>=StringLen(s)) return false;
      c=StringGetCharacter(s,p++);
      if(c=='"'||c=='\\'||c=='/') value+=ShortToString(c);
      else if(c=='n') value+="\n";
      else if(c=='r') value+="\r";
      else if(c=='t') value+="\t";
      else if(c=='b') value+=ShortToString(8);
      else if(c=='f') value+=ShortToString(12);
      else if(c=='u')
      {
         int v=0;
         for(int k=0;k<4;k++)
         {
            if(p>=StringLen(s)) return false;
            ushort h=StringGetCharacter(s,p++); int d=-1;
            if(h>='0'&&h<='9') d=(int)h-48;
            else if(h>='a'&&h<='f') d=(int)h-87;
            else if(h>='A'&&h<='F') d=(int)h-55;
            if(d<0) return false;
            v=v*16+d;
         }
         value+=ShortToString((ushort)v);
      }
      else return false;
   }
   return false;
}
bool JNumber(const string s)
{
   int p=0,n=StringLen(s);
   if(n==0) return false;
   if(StringGetCharacter(s,p)=='-') p++;
   if(p>=n) return false;
   if(StringGetCharacter(s,p)=='0') p++;
   else
   {
      if(StringGetCharacter(s,p)<'1'||StringGetCharacter(s,p)>'9') return false;
      while(p<n&&StringGetCharacter(s,p)>='0'&&StringGetCharacter(s,p)<='9') p++;
   }
   if(p<n&&StringGetCharacter(s,p)=='.')
   {
      int start=++p;
      while(p<n&&StringGetCharacter(s,p)>='0'&&StringGetCharacter(s,p)<='9') p++;
      if(p==start) return false;
   }
   if(p<n&&(StringGetCharacter(s,p)=='e'||StringGetCharacter(s,p)=='E'))
   {
      p++;
      if(p<n&&(StringGetCharacter(s,p)=='+'||StringGetCharacter(s,p)=='-')) p++;
      int start=p;
      while(p<n&&StringGetCharacter(s,p)>='0'&&StringGetCharacter(s,p)<='9') p++;
      if(p==start) return false;
   }
   return p==n;
}
bool JSkip(const string s,int &p,const int depth)
{
   if(depth>12) return false;
   JSpace(s,p); if(p>=StringLen(s)) return false;
   ushort c=StringGetCharacter(s,p);
   if(c=='"') { string v; return JString(s,p,v); }
   if(c=='{'||c=='[')
   {
      ushort end=(c=='{'?'}':']'); bool object=(c=='{'); p++; JSpace(s,p);
      if(p<StringLen(s)&&StringGetCharacter(s,p)==end) { p++; return true; }
      while(p<StringLen(s))
      {
         if(object)
         {
            string key;
            if(!JString(s,p,key)) return false;
            JSpace(s,p); if(p>=StringLen(s)||StringGetCharacter(s,p++)!=':') return false;
         }
         if(!JSkip(s,p,depth+1)) return false;
         JSpace(s,p); if(p>=StringLen(s)) return false;
         c=StringGetCharacter(s,p++);
         if(c==end) return true;
         if(c!=',') return false;
         JSpace(s,p);
      }
      return false;
   }
   int start=p;
   while(p<StringLen(s))
   {
      c=StringGetCharacter(s,p);
      if(c==','||c=='}'||c==']'||c==32||c==9||c==10||c==13) break;
      p++;
   }
   string v=StringSubstr(s,start,p-start);
   return v=="true"||v=="false"||v=="null"||JNumber(v);
}
// Extract only a ROOT field, validate whole object, and reject duplicate root keys.
bool JGet(const string s,const string wanted,string &out,bool &isString)
{
   out=""; isString=false;
   if(StringLen(s)>65536) return false;
   int p=0; JSpace(s,p);
   if(p>=StringLen(s)||StringGetCharacter(s,p++)!='{') return false;
   bool found=false; string keys[]; int count=0;
   JSpace(s,p);
   if(p<StringLen(s)&&StringGetCharacter(s,p)=='}') { p++; JSpace(s,p); return false; }
   while(p<StringLen(s))
   {
      string key;
      if(!JString(s,p,key)) return false;
      for(int i=0;i<count;i++) if(keys[i]==key) return false;
      if(count>=64) return false;
      ArrayResize(keys,++count); keys[count-1]=key;
      JSpace(s,p); if(p>=StringLen(s)||StringGetCharacter(s,p++)!=':') return false;
      JSpace(s,p); int start=p;
      if(!JSkip(s,p,0)) return false;
      if(key==wanted)
      {
         found=true;
         if(StringGetCharacter(s,start)=='"') { int q=start; isString=true; if(!JString(s,q,out)) return false; }
         else out=StringSubstr(s,start,p-start);
      }
      JSpace(s,p); if(p>=StringLen(s)) return false;
      ushort c=StringGetCharacter(s,p++);
      if(c=='}') { JSpace(s,p); return p==StringLen(s)&&found; }
      if(c!=',') return false;
      JSpace(s,p);
   }
   return false;
}
string JsonField(const string line,const string key)
{
   string v; bool quoted;
   if(!JGet(line,key,v,quoted)||!quoted) return "";
   return v;
}
bool JPositiveLong(const string s,const string key,long &out)
{
   string v; bool quoted;
   if(!JGet(s,key,v,quoted)||quoted||StringLen(v)<1||StringLen(v)>15) return false;
   for(int i=0;i<StringLen(v);i++) if(StringGetCharacter(v,i)<'0'||StringGetCharacter(v,i)>'9') return false;
   if(StringLen(v)>1&&StringGetCharacter(v,0)=='0') return false;
   out=StringToInteger(v); return out>0;
}
string SeenKey(const string id)
{
   uint h1=2166136261,h2=5381;
   string data=ControlServer()+"/"+CommandTopic+"/"+id;
   for(int i=0;i<StringLen(data);i++) { uint c=(uint)StringGetCharacter(data,i); h1=(h1^c)*16777619; h2=h2*33+c; }
   return "OBFX."+IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN))+"."+IntegerToString((long)h1)+"."+IntegerToString((long)h2);
}
bool ControlSendStatus()
{
   string mode=AutoTradeWhileRunning?"continuous":"manual";
   string body="{\"type\":\"bot_status\",\"status\":"+JsonQuote(g_remoteRunning?"running":"stopped")+
      ",\"command_id\":"+JsonQuote(g_ackId)+",\"mode\":"+JsonQuote(mode)+",\"message\":"+JsonQuote(g_controlNote)+"}";
   bool ok=SendNtfy("OrionBeastFx EA status",body,"default","robot");
   if(ok) g_lastStatusMs=GetTickCount64();
   return ok;
}
void ProcessCommand(const string msg)
{
   // No plaintext fallback: only the authenticated topic's exact app JSON contract.
   string action=JsonField(msg,"action"),id=JsonField(msg,"command_id"),controller=JsonField(msg,"controller_id");
   long at=0,seq=0;
   if(JsonField(msg,"type")!="bot_command"||(action!="RUN"&&action!="STOP")||
      StringLen(id)!=36||StringLen(controller)!=36||!JPositiveLong(msg,"requested_at",at)||!JPositiveLong(msg,"sequence",seq))
   { Print("Control: ignored malformed command."); return; }
   for(int i=0;i<36;i++)
   {
      ushort c=StringGetCharacter(id,i);
      if(i==8||i==13||i==18||i==23) { if(c!='-') return; }
      else if(!((c>='0'&&c<='9')||(c>='a'&&c<='f')||(c>='A'&&c<='F'))) return;
      c=StringGetCharacter(controller,i);
      if(i==8||i==13||i==18||i==23) { if(c!='-') return; }
      else if(!((c>='0'&&c<='9')||(c>='a'&&c<='f')||(c>='A'&&c<='F'))) return;
   }
   long now=(long)TimeGMT();
   if(at<(long)g_startedUtc||now-at>CommandMaxAgeSeconds||at-now>15)
   { Print("Control: ignored old/future command; synchronise UTC clocks."); return; }
   // With one channel owner, persist and flush an at-most-once marker before any possible order.
   string seen=SeenKey(id);
   if(GlobalVariableCheck(seen))
   {
      // A repeated delivery does not trade again. Re-send current status, not old RUN state.
      if(id==g_ackId) ControlSendStatus();
      return;
   }
   string sequenceKey=SeenKey("SEQ_"+controller);
   double previousSequence=GlobalVariableCheck(sequenceKey)?GlobalVariableGet(sequenceKey):0;
   if((double)seq<=previousSequence)
   { Print("Control: rejected out-of-order request."); return; }
   if(GlobalVariableSet(seen,(double)now)==0 || GlobalVariableSet(sequenceKey,(double)seq)==0)
   { Print("Control: could not persist command ordering; refused command."); return; }
   GlobalVariablesFlush();
   g_ackId=id;
   if(action=="STOP")
   {
      g_remoteRunning=false;
      while(ArraySize(pq_id)>0) RemoveQueued(0);
      g_controlNote="Stopped: new entries blocked; existing positions are NOT closed";
      ControlSendStatus(); return;
   }
   if(!TradeOnRun)
   {
      g_remoteRunning=false; g_controlNote="RUN rejected: TradeOnRun is disabled in EA inputs";
      ControlSendStatus(); return;
   }
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)||!MQLInfoInteger(MQL_TRADE_ALLOWED))
   {
      g_remoteRunning=false; g_controlNote="RUN rejected: enable MT5 Algo Trading and EA trading permission";
      ControlSendStatus(); return;
   }
   g_remoteRunning=true;
   if(AutoTradeWhileRunning)
   {
      while(ArraySize(pq_id)>0) RemoveQueued(0);
      g_controlNote="Continuous mode armed: only fresh signals after RUN may open trades";
      ControlSendStatus();
   }
   else
   {
      PurgeQueue();
      g_controlNote="Manual mode ready: this RUN attempts latest pending signal only";
      ControlSendStatus();
      int n=ArraySize(pq_id);
      if(n>0) ExecuteQueued(n-1);
      else { g_controlNote="Manual mode: no fresh pending signal; tap RUN after a signal arrives"; ControlSendStatus(); }
   }
}
void PollCommands()
{
   string since=g_lastCmdId;
   if(StringLen(since)==0) since=IntegerToString(g_cursorUtc);
   string url=ControlServer()+"/"+CommandTopic+"/json?poll=1&since="+since;
   char req[],res[]; string rh; ArrayResize(req,0);
   ResetLastError();
   int code=WebRequest("GET",url,"Authorization: Bearer "+CommandReadToken+"\r\n",2500,req,res,rh);
   if(code!=200)
   {
      int err=GetLastError();
      Print("Control poll failed: HTTP ",code," MQL error ",err,". Check HTTPS allowlist, topic ACL and token.");
      if(code==400) g_lastCmdId=""; // Cached cursor expired: bounded UTC fallback, never since=all.
      return;
   }
   if(ArraySize(res)>1048576) { Print("Control: oversized poll response rejected."); return; }
   string body=CharArrayToString(res,0,WHOLE_ARRAY,CP_UTF8),lines[];
   int nl=StringSplit(body,'\n',lines);
   for(int i=0;i<nl;i++)
   {
      if(JsonField(lines[i],"event")!="message") continue;
      string id=JsonField(lines[i],"id");
      if(!ControlTopicValid(id)) continue;
      long eventTime=0;
      if(!JPositiveLong(lines[i],"time",eventTime)) continue;
      string message=JsonField(lines[i],"message");
      if(StringLen(message)>8192) continue;
      long now=(long)TimeGMT();
      // Only server envelopes near this session are eligible; never let rejected
      // future timestamps poison a watermark and block later STOP messages.
      if(eventTime>=(long)g_startedUtc-15 && eventTime<=now+15) ProcessCommand(message);
      g_lastCmdId=id;
      if(eventTime>g_cursorUtc && eventTime<=now) g_cursorUtc=eventTime;
   }
}
void ControlDeinit()
{
   g_remoteRunning=false;
   if(StringLen(g_controlLock)>0)
   {
      GlobalVariableSetOnCondition(g_controlLock,0,g_controlOwner);
      g_controlLock="";
   }
}
void ControlTimer()
{
   ulong now=GetTickCount64();
   if(g_lastPollMs==0 || now-g_lastPollMs>=(ulong)CommandPollSeconds*1000)
   { g_lastPollMs=now; PollCommands(); }
   if(g_lastStatusMs==0 || now-g_lastStatusMs>=(ulong)StatusEverySeconds*1000)
   { g_lastStatusMs=now; ControlSendStatus(); }
}

// END bundled app control

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
   SendSignalCard(title,body,sym,tfn,dirTxt,id,entry,sl,tp,"trend",strength*100.0,"high",tag);
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
   SendSignalCard(title,body,sym,"M1",side,id,entry,sl,tp,"spike",score,"urgent","zap,warning");
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

// Structured signal for v7 Android cards. Values are EA-calculated prices, not app guesses.
bool SendSignalCard(const string title,const string description,const string sym,
                    const string timeframe,const string side,const int signalId,
                    const double entry,const double sl,const double tp,const string module,
                    const double score,const string priority,const string tags)
{
   int digits=(int)SymbolInfoInteger(sym,SYMBOL_DIGITS);
   if(entry<=0 || sl<=0 || tp<=0 || !MathIsValidNumber(entry) || !MathIsValidNumber(sl) || !MathIsValidNumber(tp))
   { Print("Signal card rejected: invalid EA price for ",sym); return false; }
   string body="{\"type\":\"signal\",\"symbol\":"+JsonQuote(sym)+
      ",\"side\":"+JsonQuote(side)+",\"timeframe\":"+JsonQuote(timeframe)+
      ",\"module\":"+JsonQuote(module)+",\"signal_id\":"+IntegerToString(signalId)+
      ",\"created_at\":"+IntegerToString((long)TimeGMT())+
      ",\"valid_for_seconds\":"+IntegerToString(SignalValidSeconds)+
      ",\"entry\":"+JsonQuote(DoubleToString(entry,digits))+
      ",\"sl\":"+JsonQuote(DoubleToString(sl,digits))+
      ",\"tp\":"+JsonQuote(DoubleToString(tp,digits))+
      ",\"score\":"+DoubleToString(score,1)+",\"description\":"+JsonQuote(description)+"}";
   return SendNtfy(title,body,priority,tags);
}

string TfName(const ENUM_TIMEFRAMES tf)
{
   string s = EnumToString(tf);
   StringReplace(s, "PERIOD_", "");
   return(s);
}
//+------------------------------------------------------------------+
