from pathlib import Path
import zipfile,re,json,hashlib
ROOT='OrionBeastFx/'
def once(s,a,b):
    assert s.count(a)==1,(s.count(a),a[:100])
    return s.replace(a,b,1)

SIGNAL_JS=r'''
let botSending=false,commandTimer=null;
function controlsReady(){return !!(native&&data.commandTopic&&data.commandToken&&data.commandConfirmed);}
function renderCommandControls(){
 const ready=controlsReady(),state=botState();
 document.querySelectorAll('[data-command]').forEach(b=>{b.disabled=!ready||botSending;b.textContent=botSending?'SENDING…':b.dataset.command;b.setAttribute('aria-busy',String(botSending));});
 document.querySelectorAll('[data-command-status]').forEach(n=>n.textContent=state.label);
 document.querySelectorAll('[data-command-help]').forEach(n=>n.textContent=!ready?'Configure protected command topic and token in Settings to unlock controls.':!data.active?'LIVE is OFF: turn it on to receive the EA acknowledgement.':'RUN controls the EA. LIVE only controls this phone’s receiver. STOP does not close existing trades.');
 document.querySelectorAll('[data-command-feedback]').forEach(n=>n.textContent=botFeedback);
}
window.onBotCommandResult=function(result){
 clearTimeout(commandTimer);botSending=false;
 try{if(typeof result==='string')result=JSON.parse(result);if(!result.ok)throw Error(result.error||'Command failed');botFeedback=result.message||'Request published; awaiting EA acknowledgement.';}
 catch(e){botFeedback=e.message||'Could not send command.';}
 read();renderCommandControls();if(sheet==='bot')renderBotPanel();
};
function sendBotCommand(action){
 if(botSending)return;
 try{
  if(action!=='RUN'&&action!=='STOP')throw Error('Invalid command.');
  if(!controlsReady())throw Error('Open the Android app and configure protected command settings first.');
  if(typeof native.sendBotCommandAsync!=='function')throw Error('Install the matching v7 Android build; this bridge is outdated.');
  botSending=true;botFeedback='Sending '+action+'…';renderCommandControls();if(sheet==='bot')renderBotPanel();
  commandTimer=setTimeout(()=>{botSending=false;botFeedback='Publish result timed out: EA state is unconfirmed. Check MT5/LIVE before retrying.';renderCommandControls();if(sheet==='bot')renderBotPanel();},20000);
  native.sendBotCommandAsync(action);
 }catch(e){clearTimeout(commandTimer);botSending=false;botFeedback=e.message||'Could not send command.';renderCommandControls();if(sheet==='bot')renderBotPanel();}
}
function positivePrice(v){if(typeof v!=='number'&&typeof v!=='string')return false;const t=String(v).trim();return t.length>0&&t.length<=40&&Number.isFinite(Number(t))&&Number(t)>0;}
function normaliseSignal(e,m){
 if(!e||e.type!=='signal'||!['BUY','SELL'].includes(e.side)||typeof e.symbol!=='string'||!e.symbol.trim()||e.symbol.length>80)return null;
 if(!positivePrice(e.entry)||!positivePrice(e.sl)||!positivePrice(e.tp))return null;
 const created=Number(e.created_at||m.time),valid=Number(e.valid_for_seconds||120);
 if(!Number.isFinite(created)||created<=0||!Number.isInteger(valid)||valid<1||valid>86400)return null;
 return {symbol:e.symbol.trim(),side:e.side,timeframe:String(e.timeframe||''),module:String(e.module||'signal'),entry:String(e.entry),sl:String(e.sl),tp:String(e.tp),signal_id:Number.isSafeInteger(Number(e.signal_id))&&Number(e.signal_id)>0?String(e.signal_id):'',created_at:created,valid_for_seconds:valid,description:typeof e.description==='string'?e.description:'',message_id:m.id||'',score:typeof e.score==='number'&&Number.isFinite(e.score)?e.score:null};
}
function signalFromMessage(m){
 const text=String(m.message||'').trim();
 if(text.startsWith('{')){try{return normaliseSignal(JSON.parse(text),m);}catch(e){return null;}}
 // Older EA alerts remain readable, but order/status messages are not trade signals.
 const side=text.match(/^(?:Signal|Spike watch):\s*(BUY|SELL)\s*$/mi);
 if(!side)return null;
 const field=name=>{const r=text.match(new RegExp('^'+name+':\\s*([^\\r\\n]+)','mi'));return r?r[1].trim():'';};
 const price=name=>{const r=field(name).match(/^[+]?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?/);return r?r[0]:'';};
 const id=text.match(/^ID:\s*(\d+)/mi);
 return normaliseSignal({type:'signal',side:side[1].toUpperCase(),symbol:field('Symbol'),timeframe:field('TF'),module:/^Spike watch:/mi.test(text)?'spike':'trend',entry:price('Entry'),sl:price('SL'),tp:price('TP'),signal_id:id?Number(id[1]):0,created_at:m.time,valid_for_seconds:120,description:text},m);
}
function signalRows(){
 const seen=new Set(),rows=[];
 for(const m of data.inbox||[]){const e=signalFromMessage(m);if(!e)continue;const key=e.message_id||[e.symbol,e.side,e.timeframe,e.signal_id,e.created_at].join('|');if(seen.has(key))continue;seen.add(key);rows.push(e);}
 return rows.sort((a,b)=>b.created_at-a.created_at);
}
function renderSignals(){
 const target=$('signal-list');target.replaceChildren();const rows=signalRows();
 if(!rows.length){empty(target,'No valid EA signals yet. Turn LIVE on and wait for a real trend or spike signal.');return;}
 target.append(node('p',rows.length+' received signals · newest first','muted'));
 for(const e of rows.slice(0,listLimit)){
  const expired=Date.now()/1000>e.created_at+e.valid_for_seconds;
  const card=node('article',undefined,'signal-card '+e.side.toLowerCase());
  const header=node('div',undefined,'signal-card-head'),name=node('div');
  name.append(node('h3',e.symbol),node('span',(e.module==='spike'?'SPIKE WATCH':'TREND')+(e.timeframe?' · '+e.timeframe:''),'muted'));
  header.append(name,node('span',e.side,'signal-side '+e.side.toLowerCase()));card.append(header);
  const grid=node('dl',undefined,'signal-levels');
  for(const [label,value] of [['Entry',e.entry],['Stop loss',e.sl],['Take profit',e.tp]]){const item=node('div');item.append(node('dt',label),node('dd',value));grid.append(item);}card.append(grid);
  const foot=node('div',undefined,'signal-card-foot');foot.append(node('time',stamp(e.created_at)),node('span',expired?'EXPIRED':'RECENT',expired?'signal-expired':'signal-fresh'));card.append(foot);
  card.append(node('p',(e.signal_id?'Signal #'+e.signal_id+' · ':'Signal-only · ')+(expired?'Pending lifetime elapsed.':'EA decides whether this signal is still pending and tradable.'),'muted'));
  if(e.score!==null)card.append(node('p','EA score: '+e.score+'/100','muted'));
  if(e.description){const details=node('details');details.append(node('summary','EA details'),node('pre',e.description,'signal-description'));card.append(details);}
  target.append(card);
 }
 if(rows.length>listLimit){const more=node('button','Load more signals','action');more.type='button';more.onclick=()=>{listLimit+=40;renderSignals();};target.append(more);}
}
'''
CSS='''
/* v7: visible controls and real signal cards, no synthetic market values. */
.ea-controls{margin:16px 0;padding:18px;background:var(--card);border:1px solid var(--line);border-radius:18px}
.ea-controls h3{margin:0 0 8px;font-size:16px}.ea-control-row{display:grid;grid-template-columns:1fr 1fr;gap:12px;margin:12px 0}
.ea-control-row button{min-height:52px;border:0;border-radius:12px;font-weight:800;font-size:15px;letter-spacing:.7px}
.ea-run{background:#158355;color:#fff}.ea-stop{background:#b52e40;color:#fff}.ea-control-state{font-weight:700}.command-help,.command-feedback{font-size:12px;color:var(--muted);margin:8px 0;overflow-wrap:anywhere}.command-feedback{color:var(--gold)}
#signal-list{padding:0;background:transparent;box-shadow:none;border:0;display:grid;gap:14px}.signal-card{padding:18px;background:var(--card);border:1px solid var(--line);border-left:4px solid var(--green);border-radius:16px;min-width:0}.signal-card.sell{border-left-color:var(--red)}
.signal-card-head,.signal-card-foot{display:flex;align-items:center;justify-content:space-between;gap:10px}.signal-card h3{margin:0 0 2px;font-size:19px;overflow-wrap:anywhere}.signal-side{padding:6px 12px;border-radius:9px;font-weight:800;font-size:12px;background:var(--soft);color:var(--green)}.signal-side.sell{color:var(--red)}
.signal-levels{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:8px;margin:18px 0}.signal-levels>div{padding:10px 8px;border-radius:10px;background:var(--soft);min-width:0}.signal-levels dt{font-size:10px;color:var(--muted);text-transform:uppercase;letter-spacing:.4px}.signal-levels dd{margin:5px 0 0;font-weight:700;font-size:13px;font-variant-numeric:tabular-nums;overflow-wrap:anywhere}.signal-card-foot{font-size:11px;color:var(--muted)}.signal-expired{color:var(--muted)}.signal-fresh{color:var(--green)}.signal-card p{font-size:12px}.signal-card summary{cursor:pointer;color:var(--gold);font-size:12px}.signal-description{white-space:pre-wrap;overflow-wrap:anywhere;font:12px/1.6 inherit}.signal-card .muted{overflow-wrap:anywhere}
'''
def controls(name):
 return '<section class="ea-controls" aria-label="EA trading controls '+name+'"><h3>EA controls</h3><div class="ea-control-state" data-command-status>EA status unconfirmed</div><div class="ea-control-row"><button class="ea-run" type="button" data-command="RUN" disabled>RUN</button><button class="ea-stop" type="button" data-command="STOP" disabled>STOP</button></div><p class="command-help" data-command-help>Configure command settings to unlock controls.</p><p class="command-feedback" data-command-feedback role="status" aria-live="polite"></p></section>'

SIGNAL_JAVA=r'''
        } else if ("signal".equals(type)) {
            String side=e.getString("side");if(!side.equals("BUY")&&!side.equals("SELL"))throw new JSONException("invalid signal side");
            String symbol=e.getString("symbol").trim();if(symbol.isEmpty()||symbol.length()>80)throw new JSONException("invalid signal symbol");
            JSONObject signal=new JSONObject(e.toString());
            for(String key:new String[]{"entry","sl","tp"}){
                Object raw=e.get(key);if(!(raw instanceof Number)&&!(raw instanceof String))throw new JSONException("invalid signal price");
                String value=String.valueOf(raw).trim();double price;
                try{price=Double.parseDouble(value);}catch(Exception ex){throw new JSONException("invalid signal price");}
                if(value.isEmpty()||value.length()>40||!Double.isFinite(price)||price<=0)throw new JSONException("invalid signal price");
                signal.put(key,value);
            }
            double created=e.getDouble("created_at"),valid=e.getDouble("valid_for_seconds");
            if(!Double.isFinite(created)||created<=0||created!=Math.floor(created)||!Double.isFinite(valid)||valid<1||valid>86400||valid!=Math.floor(valid))throw new JSONException("invalid signal lifetime");
            if(e.optString("description","").length()>10000)throw new JSONException("signal description too long");
            signal.put("symbol",symbol);signal.put("received_at",time);
            JSONArray history=out.optJSONArray("signals");if(history==null)history=new JSONArray();
            JSONArray next=new JSONArray();next.put(signal);
            String key=signal.optString("signal_id")+"|"+symbol+"|"+signal.getLong("created_at");
            for(int i=0;i<history.length()&&next.length()<100;i++){
                JSONObject old=history.getJSONObject(i);String oldKey=old.optString("signal_id")+"|"+old.optString("symbol")+"|"+old.optLong("created_at");
                if(!oldKey.equals(key))next.put(old);
            }
            out.put("signals",next);
'''
SIGNAL_MQL=r'''
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
'''

def transform():
 with zipfile.ZipFile('input/OrionBeastFx-v6-Android-MT5-Connection-Fix.zip') as z:files={n:z.read(n) for n in z.namelist()}
 asset=ROOT+'app/src/main/assets/index.html';ui=files[asset].decode()
 ui=once(ui,'</style>',CSS+'\n</style>')
 row=re.search(r'^<div class="blue-actions".*$',ui,re.M).group()
 ui=once(ui,row,controls('home'))
 ui=once(ui,'<article class="card" id="signal-list"></article>',controls('trader')+'<div id="signal-list" aria-label="Received signal cards"></div>')
 ui=once(ui,"let data={","let data={") # assert known script surface before further edits
 old=re.search(r'^function renderSignals\(\).*$',ui,re.M).group();ui=once(ui,old,'// v7 signal cards are rendered below.')
 old=re.search(r'^function sendBotCommand\(.*$',ui,re.M).group();ui=once(ui,old,'// v7 asynchronous command handler is defined below.')
 ui=once(ui,' renderBotStatus();',' renderBotStatus();renderCommandControls();')
 ui=once(ui,"run.disabled=!configured;","run.disabled=!configured||botSending;")
 ui=once(ui,"stop.disabled=!configured;","stop.disabled=!configured||botSending;")
 ui=once(ui,"const native=window.Orion;","const native=window.Orion;\n"+SIGNAL_JS)
 ui=once(ui,"$('history-button').onclick=", "document.querySelectorAll('[data-command]').forEach(b=>b.onclick=()=>sendBotCommand(b.dataset.command));\n$('history-button').onclick=")
 # Correct any misleading default status before native data loads.
 ui=once(ui,'id="bot-label">Bot Stopped','id="bot-label">EA status unconfirmed')
 files[asset]=ui.encode()
 path=ROOT+'app/src/main/java/com/orionbeastfx/alerts/MainActivity.java';java=files[path].decode()
 java=once(java,'    private WebView web;','    private WebView web;\n    private final java.util.concurrent.ExecutorService commands=java.util.concurrent.Executors.newSingleThreadExecutor();\n    private volatile boolean activityDestroyed=false;')
 java=once(java,'        @JavascriptInterface public synchronized String sendBotCommand(String command) {','''        @JavascriptInterface public void sendBotCommandAsync(final String command) {
            if(activityDestroyed)return;
            try {
                commands.execute(() -> {
                    final String result=sendBotCommand(command);
                    runOnUiThread(() -> {
                        if(!activityDestroyed&&web!=null)web.evaluateJavascript("window.onBotCommandResult && window.onBotCommandResult("+result+")",null);
                    });
                });
            }catch(java.util.concurrent.RejectedExecutionException ignored){
                android.util.Log.w("OrionControl","Activity closed before command could be queued");
            }
        }
        @JavascriptInterface public synchronized String sendBotCommand(String command) {''')
 java=once(java,'@Override protected void onDestroy(){if(web!=null)', '@Override protected void onDestroy(){activityDestroyed=true;commands.shutdown();if(web!=null)')
 files[path]=java.encode()
 path=ROOT+'app/src/main/java/com/orionbeastfx/alerts/EventReducer.java';reducer=files[path].decode()
 reducer=once(reducer,'        } else if ("bot_status".equals(type)) {',SIGNAL_JAVA+'        } else if ("bot_status".equals(type)) {')
 files[path]=reducer.encode()
 path=ROOT+'mt5/OrionBeastFx_Signals.mq5';ea=files[path].decode();priorEA=ea
 ea=once(ea,'#property version   "6.00"','#property version   "7.00"')
 ea=once(ea,'// OrionBeastFx Signals v6','// OrionBeastFx Signals v7')
 ea=once(ea,'   SendNtfy(title, body, "high", tag);','   SendSignalCard(title,body,sym,tfn,dirTxt,id,entry,sl,tp,"trend",strength*100.0,"high",tag);')
 ea=once(ea,'   SendNtfy(title, body, "urgent", "zap,warning");','   SendSignalCard(title,body,sym,"M1",side,id,entry,sl,tp,"spike",score,"urgent","zap,warning");')
 ea=once(ea,'string TfName(const ENUM_TIMEFRAMES tf)',SIGNAL_MQL+'\nstring TfName(const ENUM_TIMEFRAMES tf)')
 # Standalone distribution: only MT5's standard Trade include remains external.
 control=files[ROOT+'mt5/OrionAppControl.mqh'].decode()
 standalone=once(ea,'#include "OrionAppControl.mqh"','// BEGIN bundled app control — no custom .mqh file needed\n'+control+'\n// END bundled app control')
 standalone=once(standalone,'// Install OrionAppControl.mqh beside this file. See EA-INTEGRATION.md in the project.','// Standalone v7 source: custom app-control include is bundled below. See project EA-INTEGRATION.md.')
 files[path]=standalone.encode()
 # Keep the include for audit, but the main .mq5 does not depend on it.
 files[ROOT+'README.md']=b'''# OrionBeastFx v7 - buttons and signal cards

- Visible RUN/STOP controls on Home and Trader, separate from LIVE receiver.
- Async native command publishing: no HTTP call on the WebView JavaScript path.
- Real signal cards: BUY/SELL, symbol, timeframe/module, entry, SL, TP, ID, timestamp and lifetime.
- Current EA emits validated structured signals; older plaintext signals are also readable.
- Standalone mt5/OrionBeastFx_Signals.mq5 includes the custom control code inline.
- Connection setup and safety details: EA-INTEGRATION.md.

This is source code, not a compiled APK/EX5. Build Android with the included workflow/Android Studio and compile MT5 in MetaEditor. Start with demo.
'''
 setup=files[ROOT+'EA-INTEGRATION.md'].decode()
 setup=once(setup,'# OrionBeastFx v6: Android ↔ MT5 connection repair','# OrionBeastFx v7: working controls and signal cards')
 setup=once(setup,'2. Copy BOTH files from this ZIP\'s mt5/ folder into it: OrionBeastFx_Signals.mq5 and OrionAppControl.mqh. Keep them together.','2. Copy mt5/OrionBeastFx_Signals.mq5 into that folder. It is standalone: custom control code is bundled inline. The archived .mqh is supplied for reference only.')
 setup=once(setup,'3. Open the .mq5 in MetaEditor and compile. The .mqh is an include, not a separately attachable EA.','3. Open the .mq5 in MetaEditor and compile. MT5’s standard Trade/Trade.mqh is still required (normally installed with MT5).')
 setup+='''\n## v7 buttons and cards
RUN and STOP are directly visible on Home and Trader. They unlock only after command settings are valid. Publishing runs on a native background queue; the UI shows sending, publish outcome, then the matching EA acknowledgement. No command is sent merely by opening the app. LIVE is still an independent receiver toggle. If the receiver is off the app warns you; it does not pretend to know that the EA acted.

Trader shows cards for real trend/spike signals with BUY/SELL, symbol/timeframe, entry/SL/TP, timestamp and signal ID. EXPIRED is based on the signal's advertised lifetime, not proof of broker execution or whether a pending signal was consumed. There is intentionally no misleading per-card trade button: default RUN still attempts the EA's latest pending signal, not an arbitrarily selected card. Original alert details are retained inside each card. Structured status/heartbeat/order reports are not rendered as signal cards; History retains raw received messages.

The separate downloadable OrionBeastFx_Signals_v7.mq5 has exactly the same bytes as mt5/OrionBeastFx_Signals.mq5 inside this ZIP. You do not need an extra custom .mqh to use it. Rebuild/install the matching v7 app; older APKs do not have the async bridge or card reducer.
'''
 files[ROOT+'EA-INTEGRATION.md']=setup.encode()
 files[ROOT+'CHANGELOG.md']=b'''# v7 UI correction
- Added directly accessible Home/Trader RUN and STOP buttons.
- Added async native publishing with visible progress/error handling.
- Added validated structured signal events and real signal cards; legacy alerts remain readable.
- Exported standalone .mq5 source separately as requested.
- No APK/EX5 compile or real ntfy/broker test performed here.
\n'''+files[ROOT+'CHANGELOG.md']
 # Prior migration scripts refer to v6 input and are historical, not current v7 test output.
 for n in list(files):
    if n.startswith(ROOT+'tests/'):
        files[ROOT+'tests/v6-history/'+n[len(ROOT+'tests/'):]]=files.pop(n)
 return files,ui,java,reducer,standalone,priorEA

if __name__=='__main__':
 files,ui,java,reducer,ea,prior=transform()
 Path('output').mkdir(exist_ok=True)
 with zipfile.ZipFile('output/OrionBeastFx-v7-Buttons-SignalCards.zip','w',zipfile.ZIP_DEFLATED) as z:
    for n,b in sorted(files.items()):z.writestr(n,b)
 Path('output/OrionBeastFx_Signals_v7.mq5').write_text(ea,encoding='utf-8')
 print('Created v7 archive and separate standalone EA source.')
