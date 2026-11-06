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
