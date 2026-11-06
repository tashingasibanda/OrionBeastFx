from pathlib import Path
import zipfile, re, json, hashlib

ROOT='OrionBeastFx/'
def replace_once(s, old, new):
    if s.count(old)!=1:
        raise ValueError('Expected one match, got '+str(s.count(old))+': '+old[:100])
    return s.replace(old,new,1)

def make_sources():
    original=Path('input/OrionBeastFx_Signals.mq5').read_text(encoding='utf-8-sig')
    ea=replace_once(original,'#property version   "4.00"','#property version   "6.00"')
    # Remove outdated plaintext-command instructions; retain all strategy maths.
    end=ea.index('#property copyright')
    ea='''// OrionBeastFx Signals v6 — Android JSON control over protected ntfy topics.
// Starts STOPPED. RUN/STOP is authenticated by ntfy topic ACLs, not a public topic name.
// Default: RUN attempts latest pending signal once. No new automatic-entry mode by default.
// Optional AutoTradeWhileRunning=true: RUN arms FUTURE signals until STOP.
// STOP blocks new entries and clears pending signals; it NEVER closes positions.
// Install OrionAppControl.mqh beside this file. See EA-INTEGRATION.md in the project.
'''+ea[end:]
    ea=replace_once(ea,'#property description "Trend + spike-watch scanner. Opens trades ONLY when the app sends RUN via ntfy."','#property description "Trend + spike-watch scanner; authenticated app RUN/STOP control, starts stopped."')
    ea=replace_once(ea,'// Topic the app sends RUN to (empty = same as NtfyTopic)','// Required separate protected command topic (must match Android Settings)')
    ea=replace_once(ea,'// Command must START with this word','// Retained for preset compatibility; plaintext commands are disabled')
    ea=replace_once(ea,'int OnInit()\n{','int OnInit()\n{\n   if(!ControlInit()) return(INIT_PARAMETERS_INCORRECT);')
    ea=replace_once(ea,'int    g_secTick    = 0;','int    g_secTick    = 0;\n\n#include "OrionAppControl.mqh"')
    ea=replace_once(ea,'   EventSetTimer(1);','   if(!EventSetTimer(1)) return(INIT_FAILED);')
    ea=replace_once(ea,'   return(INIT_SUCCEEDED);','   ControlSendStatus();\n   return(INIT_SUCCEEDED);')
    ea=replace_once(ea,'void OnDeinit(const int reason)\n{','void OnDeinit(const int reason)\n{\n   ControlDeinit();')
    ea=replace_once(ea,'''   // 1) listen for RUN from the app
   g_secTick++;
   if(TradeOnRun && CommandPollSeconds > 0 && (g_secTick % CommandPollSeconds) == 0)
      PollCommands();''','''   // Poll even in signal-only mode so STOP and status reports always work.
   ControlTimer();''')
    ea=replace_once(ea,'''   for(int j = 0; j < sp; j++)
      SpikeCheck(j);
}''','''   for(int j = 0; j < sp; j++)
      SpikeCheck(j);

   // Explicit opt-in only. RUN cleared the old queue; these are fresh signals.
   if(AutoTradeWhileRunning && g_remoteRunning && TradeOnRun)
   {
      PurgeQueue();
      while(ArraySize(pq_id)>0 && g_remoteRunning) ExecuteQueued(0);
   }
}''')
    start=ea.index('string JsonField(')
    end=ea.index('//+==================================================================+\n//|  TRADE EXECUTION',start)
    ea=ea[:start]+'// JSON listener implemented in OrionAppControl.mqh.\n\n'+ea[end:]
    ea=replace_once(ea,'   if(!TradeOnRun)\n   { report = "Trading is disabled in EA inputs."; return(false); }','''   if(!TradeOnRun)
   { report = "Trading is disabled in EA inputs."; return(false); }
   if(!g_remoteRunning)
   { report = "STOP active: new entries are disabled."; return(false); }''')
    ea=replace_once(ea,'   string url = NtfyServer + "/" + NtfyTopic;','   string url = ControlServer() + "/" + NtfyTopic;')
    ea=replace_once(ea,'                    "Tags: "     + tags     + "\\r\\n";','                    "Tags: "     + tags     + "\\r\\n" +\n                    "Authorization: Bearer " + AlertWriteToken + "\\r\\n";')
    ea=replace_once(ea,'   Print("RUN #",','   g_controlNote=(ok ? "Order accepted by MT5: " : "Trade rejected: ")+report;\n   ControlSendStatus();\n   Print("RUN #",')
    ea=ea.replace('  (send RUN "+ IntegerToString(id)', '  (send RUN "+ IntegerToString(id)') if False else ea
    ea=replace_once(ea,'         mode = "Trades open ONLY on RUN from app (lot " + DoubleToString(LotSize, 2) +\n                ", max " + IntegerToString(MaxOpenTrades) + " trades)";','''         mode = "Starts STOPPED. App JSON RUN/STOP; mode: " + (AutoTradeWhileRunning ? "continuous opt-in" : "manual latest pending") +
                "; max " + IntegerToString(MaxOpenTrades) + " trades";''')
    # Human-readable text must describe the app, not unsupported plaintext commands.
    old='body += "\\nID: " + IntegerToString(id) + "  (send RUN " + IntegerToString(id) + " to trade)";'
    assert ea.count(old)==2
    ea=ea.replace(old,'body += "\\nID: " + IntegerToString(id) + "  (use app RUN; manual mode selects latest pending signal)";')
    # Signal calculations, position limits and broker execution checks are preserved.
    for name,nextname in [('double Median(', 'double Percentile('),('double Percentile(', 'double MadScale('),('double MadScale(', 'bool LastBarIsSpike('),('void Check(', 'void SendSignal('),('void UpdateSpikeBar(', 'bool TickAccel('),('bool TickAccel(', 'void SpikeLevels('),('void SpikeLevels(', 'void SpikeCheck('),('void SpikeCheck(', 'void SendSpikeAlert(')]:
        def body(src):
            a=src.index(name); b=src.index(nextname,a)
            return src[a:b]
        assert body(ea)==body(original),name+' was unexpectedly changed'
    include=Path('input/OrionAppControl.mqh').read_bytes()
    with zipfile.ZipFile('input/OrionBeastFx-Android-Project-v5.zip') as z:
        files={n:z.read(n) for n in z.namelist()}
    path=ROOT+'app/src/main/assets/index.html'
    ui=files[path].decode()
    old=re.search(r'^function botState\(\).*$',ui,re.M).group()
    new="""function botState(){const ack=data.state.bot_status||{},ackTime=Number(ack.time||data.state.bot_status_time||0),requestTime=Number(data.commandTime||0),pending=!!data.commandId&&!!data.commandState,matched=!pending||ack.command_id===data.commandId;if(ack.status&&matched){if(stale(ackTime))return{label:'EA status stale · reconnect LIVE / check MT5',on:false};return{label:ack.status==='running'?(ack.mode==='manual'?'EA READY · manual RUN':'EA reports RUNNING'):'EA reports STOPPED',on:ack.status==='running'};}if(pending){const action=data.commandState==='STOP_REQUESTED'?'STOP':'RUN';const timeout=Date.now()/1000-requestTime>30;return{label:action+(timeout?' unconfirmed · check MT5 and LIVE':' requested · awaiting matching EA report'),on:false};}return{label:'EA status unconfirmed',on:false};}"""
    ui=replace_once(ui,old,new)
    ui=replace_once(ui,'if(botFeedback)c.append(node(\'div\',botFeedback,\'feedback\'));',"const report=data.state.bot_status||{};if(report.message)c.append(node('p',report.message,'bot-panel-note'));if(!data.active)c.append(node('p','Turn LIVE on to receive EA acknowledgements. Publishing alone does not prove that the EA acted.','bot-panel-note'));if(botFeedback)c.append(node('div',botFeedback,'feedback'));")
    ui=replace_once(ui,'Run and Stop are sent only when you tap a button. The app reports that ntfy accepted a command; only an EA status message can show what the EA reports.','Default manual mode: RUN attempts the latest pending signal once. To start trading future signals until STOP, explicitly set AutoTradeWhileRunning=true in MT5. The app waits for the matching EA acknowledgement; ntfy acceptance alone is not execution.')
    files[path]=ui.encode()
    path=ROOT+'app/src/main/java/com/orionbeastfx/alerts/EventReducer.java'
    reducer=files[path].decode()
    reducer=replace_once(reducer,'            out.put("bot_status",bot);out.put("bot_status_time",time);','''            if(e.has("mode")){String mode=e.getString("mode");if(!mode.equals("manual")&&!mode.equals("continuous"))throw new JSONException("invalid control mode");bot.put("mode",mode);}
            if(e.has("message")){String message=e.getString("message");if(message.length()>2000)throw new JSONException("control message too long");bot.put("message",message);}
            out.put("bot_status",bot);out.put("bot_status_time",time);''')
    files[path]=reducer.encode()
    path=ROOT+'app/src/main/java/com/orionbeastfx/alerts/MainActivity.java'
    main=files[path].decode()
    main=replace_once(main,'@JavascriptInterface public String sendBotCommand(String command)','@JavascriptInterface public synchronized String sendBotCommand(String command)')
    main=replace_once(main,'            String id=UUID.randomUUID().toString();long sequence=p.getLong("commandSequence",0L)+1L;long now=System.currentTimeMillis()/1000L;', '''            String controller=p.getString("controllerId","");
            if(controller.isEmpty())controller=UUID.randomUUID().toString();
            String id=UUID.randomUUID().toString();long sequence=p.getLong("commandSequence",0L)+1L;long now=System.currentTimeMillis()/1000L;
            if(sequence<=0||sequence>999999999999999L)return commandResult(false,"Command sequence exhausted; configure a new controller.",null);
            if(!p.edit().putString("controllerId",controller).putLong("commandSequence",sequence).commit())return commandResult(false,"Could not reserve a safe command sequence.",null);''')
    main=replace_once(main,'body.put("sequence",sequence);body.put("requested_at",now);','body.put("sequence",sequence);body.put("requested_at",now);body.put("controller_id",controller);')
    # Remove pending status when channel settings change, so an old channel cannot appear to acknowledge a new request.
    anchor='                boolean ok=Store.prefs(MainActivity.this).edit().putString("server",s)'
    main=replace_once(main,anchor,'''                android.content.SharedPreferences previous=Store.prefs(MainActivity.this);
                if(!s.equals(Store.server(MainActivity.this))||!t.equals(Store.topic(MainActivity.this))||!commandTopic.equals(previous.getString("commandTopic",""))) {
                    if(!previous.edit().remove("commandState").remove("commandTime").remove("commandId").commit())return "Could not reset the previous control channel status.";
                }
'''+anchor)
    files[path]=main.encode()
    files[ROOT+'mt5/OrionBeastFx_Signals.mq5']=ea.encode()
    files[ROOT+'mt5/OrionAppControl.mqh']=include
    setup=Path('input/EA-CONNECTION-SETUP.md').read_bytes()
    files[ROOT+'EA-INTEGRATION.md']=setup
    files[ROOT+'README.md']=b'# OrionBeastFx v6 connection repair\n\nRead EA-INTEGRATION.md before use. MT5 source is in mt5/.\n\n'+files[ROOT+'README.md']
    files[ROOT+'CHANGELOG.md']=b'''# v6 connection repair
- Matched Android JSON protocol to MT5; authenticated command reads and status writes.
- Explicit STOP, startup-stopped gate, UTC TTL, durable duplicate-command suppression.
- One channel receiver per MT5 terminal/account; matching command IDs and stale/unconfirmed UI.
- Original manual latest-pending RUN is the default; optional continuous mode requires explicit EA input.
- Preserved indicator calculations and dynamic TP/SL; no new profit or risk guarantees.
- Source-level protocol checks and host-side UI tests only; no Android/MetaEditor compilation or live broker test here.
\n'''+files[ROOT+'CHANGELOG.md']
    return files,ea,ui,include.decode()

if __name__=='__main__':
    files,ea,ui,bridge=make_sources()
    out=Path('output');out.mkdir(exist_ok=True)
    dest=out/'OrionBeastFx-v6-Android-MT5-Connection-Fix.zip'
    with zipfile.ZipFile(dest,'w',zipfile.ZIP_DEFLATED) as z:
        for n,data in sorted(files.items()): z.writestr(n,data)
    with zipfile.ZipFile(dest) as z:
        assert z.testzip() is None
        assert len(z.namelist())==len(set(z.namelist()))
        assert z.read(ROOT+'mt5/OrionBeastFx_Signals.mq5').decode()==ea
    print('Archive validated:',len(files),'files;',dest.stat().st_size,'bytes')
    print('Strategy-math preservation checks: 8 sections unchanged')
