
const assert=require('assert');
class Element{
 constructor(tag='div',attrs={}){this.tagName=tag;this.children=[];this.attrs={...attrs};this.dataset={};this.hidden='hidden' in attrs;this.disabled='disabled' in attrs;this._text='';this.style={};this.value='';this.checked=false;this.className=attrs.class||'';for(const [k,v]of Object.entries(attrs)){if(k.startsWith('data-'))this.dataset[k.slice(5).replace(/-([a-z])/g,(_,c)=>c.toUpperCase())]=v;}this.classList={toggle:()=>{},add:()=>{},remove:()=>{}};}
 append(...nodes){this.children.push(...nodes);}
 replaceChildren(...nodes){this.children=[...nodes];this._text='';}
 set textContent(v){this._text=String(v);this.children=[];}get textContent(){return this._text+this.children.map(n=>typeof n==='string'?n:n.textContent).join(' ');}
 set innerHTML(v){this._html=v;this.children=[];}get innerHTML(){return this._html||'';}
 setAttribute(k,v){this.attrs[k]=v;}getAttribute(k){return this.attrs[k];}
 focus(){}addEventListener(){}querySelectorAll(){return [];}querySelector(){return new Element();}
}
const all=[{"tag": "symbol", "attrs": {"id": "i-home", "viewbox": "0 0 24 24"}}, {"tag": "symbol", "attrs": {"id": "i-signal", "viewbox": "0 0 24 24"}}, {"tag": "symbol", "attrs": {"id": "i-terminal", "viewbox": "0 0 24 24"}}, {"tag": "symbol", "attrs": {"id": "i-settings", "viewbox": "0 0 24 24"}}, {"tag": "symbol", "attrs": {"id": "i-history", "viewbox": "0 0 24 24"}}, {"tag": "symbol", "attrs": {"id": "i-sparkles", "viewbox": "0 0 24 24"}}, {"tag": "symbol", "attrs": {"id": "i-power", "viewbox": "0 0 24 24"}}, {"tag": "symbol", "attrs": {"id": "i-chart", "viewbox": "0 0 24 24"}}, {"tag": "symbol", "attrs": {"id": "i-activity", "viewbox": "0 0 24 24"}}, {"tag": "symbol", "attrs": {"id": "i-target", "viewbox": "0 0 24 24"}}, {"tag": "symbol", "attrs": {"id": "i-close", "viewbox": "0 0 24 24"}}, {"tag": "symbol", "attrs": {"id": "i-moon", "viewbox": "0 0 24 24"}}, {"tag": "symbol", "attrs": {"id": "i-trade", "viewbox": "0 0 24 24"}}, {"tag": "symbol", "attrs": {"id": "i-trash", "viewbox": "0 0 24 24"}}, {"tag": "symbol", "attrs": {"id": "i-info", "viewbox": "0 0 24 24"}}, {"tag": "symbol", "attrs": {"id": "i-chat", "viewbox": "0 0 24 24"}}, {"tag": "symbol", "attrs": {"id": "i-analyze", "viewbox": "0 0 24 24"}}, {"tag": "symbol", "attrs": {"id": "i-symbols", "viewbox": "0 0 24 24"}}, {"tag": "symbol", "attrs": {"id": "i-bot", "viewbox": "0 0 24 24"}}, {"tag": "symbol", "attrs": {"id": "i-play", "viewbox": "0 0 24 24"}}, {"tag": "symbol", "attrs": {"id": "i-stop", "viewbox": "0 0 24 24"}}, {"tag": "span", "attrs": {"id": "connection-dot", "class": "dot"}}, {"tag": "span", "attrs": {"id": "connection-label"}}, {"tag": "div", "attrs": {"id": "native-error", "class": "native-error", "role": "alert", "hidden": null}}, {"tag": "section", "attrs": {"id": "view-Home"}}, {"tag": "button", "attrs": {"class": "action", "id": "history-button"}}, {"tag": "button", "attrs": {"class": "action", "id": "insight-button"}}, {"tag": "button", "attrs": {"class": "action live stopped", "id": "live-button"}}, {"tag": "span", "attrs": {"id": "live-label"}}, {"tag": "button", "attrs": {"class": "ea-run", "type": "button", "data-command": "RUN", "disabled": null}}, {"tag": "button", "attrs": {"class": "ea-stop", "type": "button", "data-command": "STOP", "disabled": null}}, {"tag": "span", "attrs": {"class": "bot-dot", "id": "bot-dot"}}, {"tag": "span", "attrs": {"id": "bot-label"}}, {"tag": "button", "attrs": {"class": "info-button", "data-action": "info", "aria-label": "About bot and connection status"}}, {"tag": "button", "attrs": {"class": "", "data-action": "analyzer"}}, {"tag": "button", "attrs": {"class": "", "data-action": "history"}}, {"tag": "button", "attrs": {"class": "", "data-action": "chat"}}, {"tag": "button", "attrs": {"class": "", "data-action": "remove"}}, {"tag": "section", "attrs": {"id": "view-Signal", "hidden": null}}, {"tag": "button", "attrs": {"class": "ea-run", "type": "button", "data-command": "RUN", "disabled": null}}, {"tag": "button", "attrs": {"class": "ea-stop", "type": "button", "data-command": "STOP", "disabled": null}}, {"tag": "div", "attrs": {"id": "signal-list", "aria-label": "Received signal cards"}}, {"tag": "section", "attrs": {"id": "view-Terminal", "hidden": null}}, {"tag": "span", "attrs": {"class": "count", "id": "watch-count"}}, {"tag": "div", "attrs": {"id": "watch-list"}}, {"tag": "span", "attrs": {"class": "count", "id": "standby-count"}}, {"tag": "div", "attrs": {"id": "standby-list"}}, {"tag": "section", "attrs": {"id": "view-Settings", "hidden": null}}, {"tag": "input", "attrs": {"id": "dark-toggle", "type": "checkbox", "aria-label": "Dark Mode"}}, {"tag": "p", "attrs": {"id": "theme-feedback", "class": "feedback", "aria-live": "polite"}}, {"tag": "form", "attrs": {"id": "connection-form", "class": "card"}}, {"tag": "input", "attrs": {"id": "server", "type": "url", "autocomplete": "off", "required": null}}, {"tag": "input", "attrs": {"id": "topic", "autocomplete": "off", "required": null, "maxlength": "128"}}, {"tag": "input", "attrs": {"id": "token", "type": "password", "autocomplete": "off"}}, {"tag": "input", "attrs": {"id": "stale", "type": "number", "min": "30", "max": "86400", "step": "1", "required": null}}, {"tag": "input", "attrs": {"id": "command-topic", "autocomplete": "off", "maxlength": "128", "placeholder": "Set a protected topic"}}, {"tag": "input", "attrs": {"id": "command-token", "type": "password", "autocomplete": "off", "placeholder": "Required for Run/Stop"}}, {"tag": "input", "attrs": {"id": "control-confirmed", "type": "checkbox"}}, {"tag": "button", "attrs": {"class": "save", "type": "submit"}}, {"tag": "div", "attrs": {"id": "settings-feedback", "class": "feedback", "role": "status"}}, {"tag": "button", "attrs": {"id": "bot-fab", "class": "bot-fab", "type": "button", "aria-label": "Open EA Run and Stop controls"}}, {"tag": "button", "attrs": {"data-tab": "Home", "class": "active", "aria-current": "page"}}, {"tag": "button", "attrs": {"data-tab": "Signal"}}, {"tag": "button", "attrs": {"data-tab": "Terminal"}}, {"tag": "button", "attrs": {"data-tab": "Settings"}}, {"tag": "div", "attrs": {"class": "overlay", "id": "overlay", "hidden": null}}, {"tag": "h2", "attrs": {"id": "sheet-title"}}, {"tag": "button", "attrs": {"id": "close-sheet", "class": "close", "aria-label": "Close"}}, {"tag": "div", "attrs": {"id": "sheet-content"}}].map(e=>new Element(e.tag,e.attrs));const ids=Object.fromEntries(all.filter(e=>e.attrs.id).map(e=>[e.attrs.id,e]));
const document={getElementById:id=>{assert(ids[id],'Unknown DOM id '+id);return ids[id];},createElement:tag=>new Element(tag),createElementNS:(_,tag)=>new Element(tag),documentElement:{dataset:{}},hidden:false,activeElement:null,addEventListener(){},querySelectorAll(sel){const match=sel.match(/^\[([^\]]+)\]$/);return match?all.filter(e=>Object.prototype.hasOwnProperty.call(e.attrs,match[1])):[];}};
const window=global;const timers=new Map();let timerId=0;global.setTimeout=(f,ms)=>{timers.set(++timerId,f);return timerId;};global.clearTimeout=id=>timers.delete(id);global.setInterval=()=>1;
const calls=[];let stateSnapshot={state:{},inbox:[],active:true,status:'Connected',stale:300,dark:true,server:'https://test.invalid',topic:'alerts',token:'reader',commandTopic:'commands',commandToken:'writer',commandConfirmed:true,commandState:'',commandTime:0,commandId:''};
window.Orion={snapshot:()=>JSON.stringify(stateSnapshot),sendBotCommandAsync:action=>calls.push(action),toggleLive:()=>calls.push('LIVE'),theme:()=>true,saveSettings:()=>''};


'use strict';
const $=id=>document.getElementById(id);let data={state:{},inbox:[],active:false,stale:300,dark:true,commandTopic:'',commandToken:'',commandConfirmed:false,commandState:'',commandTime:0},tab='Home',sheet=null,listLimit=40,historyLimit=40,lastSig='',lastTerm='',opener=null,livePending=false,botFeedback='';
const native=window.Orion;

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

const icon=name=>'<svg aria-hidden="true"><use href="#i-'+name+'"/></svg>';
function node(tag,text,cls){const n=document.createElement(tag);if(text!==undefined)n.textContent=String(text);if(cls)n.className=cls;return n;}
function empty(target,text,name='signal'){const e=node('div',undefined,'empty');e.innerHTML=icon(name);e.append(node('div',text));target.replaceChildren(e);}
function stamp(sec){return sec?new Date(sec*1000).toLocaleString([], {month:'short',day:'numeric',hour:'2-digit',minute:'2-digit',second:'2-digit'}):'Not received yet';}
function dayKey(){const d=new Date();return d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0')+'-'+String(d.getDate()).padStart(2,'0');}
function stale(sec){return !sec||Date.now()/1000-sec>data.stale;}
function setTheme(dark){document.documentElement.dataset.theme=dark?'dark':'light';$('dark-toggle').checked=dark;}
function nav(next){tab=next;for(const name of ['Home','Signal','Terminal','Settings'])$('view-'+name).hidden=name!==next;document.querySelectorAll('.nav button').forEach(b=>{b.classList.toggle('active',b.dataset.tab===next);if(b.dataset.tab===next)b.setAttribute('aria-current','page');else b.removeAttribute('aria-current');});if(next==='Signal')renderSignals();if(next==='Terminal')renderTerminal();window.scrollTo(0,0);}
window.goHome=()=>{if(sheet)closeSheet();else nav('Home');};
function read(){try{if(!native)throw Error('Android bridge unavailable. Open the installed Android app to receive live EA data.');const next=JSON.parse(native.snapshot());if(next.error)throw Error(next.error);data=next;setTheme(!!data.dark);$('native-error').hidden=true;render();return true;}catch(e){$('native-error').textContent=e.message;$('native-error').hidden=false;return false;}}
function render(){
 const active=!!data.active,connected=active&&data.status==='Connected';$('connection-dot').classList.toggle('on',connected);$('connection-label').textContent=connected?'CONNECTED':active?'CONNECTING':'OFFLINE';
 $('live-label').textContent=active?'STOP LIVE':'START LIVE';$('live-button').classList.toggle('stopped',!active);$('live-button').setAttribute('aria-label',active?'Stop live receiver':'Start live receiver');$('live-button').setAttribute('aria-pressed',String(active));
 renderBotStatus();renderCommandControls();
 if(tab==='Signal')renderSignals();if(tab==='Terminal')renderTerminal();if(sheet==='insight')renderInsight();if(sheet==='history')renderMessages($('sheet-content'),data.inbox||[],historyLimit,true);if(sheet==='bot')renderBotPanel();
}
function renderTerminal(){for(const group of ['watch','standby']){const rows=Object.values(data.state.symbols||{}).filter(r=>r.state===group).sort((a,b)=>a.symbol.localeCompare(b.symbol));$(group+'-count').textContent=rows.length;const list=$(group+'-list');list.replaceChildren();if(!rows.length){empty(list,'No symbols reported '+(group==='watch'?'on watch':'on standby')+'.','terminal');continue;}for(const r of rows){const row=node('div',undefined,'symbol');const title=node('div',undefined,'symbol-title');title.append(node('span',r.symbol));if(r.timeframe)title.append(node('span',r.timeframe,'tag'));row.append(title);if(r.reason)row.append(node('p',r.reason));if(r.tp!==undefined&&r.tp!==null)row.append(node('p','EA-calculated TP: '+r.tp+(r.tp_method?' · '+r.tp_method:''),'tp-value'));row.append(node('time',stamp(r.time)+(stale(r.time)?' · STALE':'')+(!data.active?' · RECEIVER OFFLINE':'')));list.append(row);}}}
// v7 signal cards are rendered below.
function renderMessages(target,messages,limit,history){target.replaceChildren();if(!messages.length){empty(target,history?'No received messages yet.':'No signal notifications yet.');return;}target.append(node('p',Math.min(limit,messages.length)+' of '+messages.length+' saved messages · newest first','muted'));for(const m of messages.slice(0,limit)){const row=node('article',undefined,'message');row.append(node('time',stamp(m.time)));row.append(node('h3',m.title||(m.parsed?'EA structured update':'EA alert')));row.append(node(m.parsed?'pre':'p',m.message||''));if(m.parse_error)row.append(node('p','Structured data rejected: '+m.parse_error,'negative'));target.append(row);}if(messages.length>limit){const b=node('button','Load more','action load-more');b.onclick=()=>{if(history){historyLimit+=40;renderMessages(target,messages,historyLimit,true);}else{listLimit+=40;renderSignals();}};target.append(b);}}
function renderInsight(){const c=$('sheet-content');c.replaceChildren();c.append(node('p','AI analysis is not connected. The observations below only describe your received EA data; they are not trade recommendations.','notice'));const rows=Object.values(data.state.symbols||{});for(const group of ['watch','standby']){const r=node('div',undefined,'status-row');r.append(node('span',group==='watch'?'On Watch':'On Standby'));r.append(node('strong',rows.filter(x=>x.state===group).length));c.append(r);}c.append(node('p','Last structured update: '+stamp(data.state.last_ea),'muted'));c.append(node('p',!data.state.last_ea?'Waiting for EA data.':stale(data.state.last_ea)?'EA data is stale. Check your EA and receiver connection.':'A recent structured EA update is available.','muted'));}
function botState(){const ack=data.state.bot_status||{},ackTime=Number(ack.time||data.state.bot_status_time||0),requestTime=Number(data.commandTime||0),pending=!!data.commandId&&!!data.commandState,matched=!pending||ack.command_id===data.commandId;if(ack.status&&matched){if(stale(ackTime))return{label:'EA status stale · reconnect LIVE / check MT5',on:false};return{label:ack.status==='running'?(ack.mode==='manual'?'EA READY · manual RUN':'EA reports RUNNING'):'EA reports STOPPED',on:ack.status==='running'};}if(pending){const action=data.commandState==='STOP_REQUESTED'?'STOP':'RUN';const timeout=Date.now()/1000-requestTime>30;return{label:action+(timeout?' unconfirmed · check MT5 and LIVE':' requested · awaiting matching EA report'),on:false};}return{label:'EA status unconfirmed',on:false};}
function renderBotStatus(){const s=botState();$('bot-dot').classList.toggle('on',s.on);$('bot-label').textContent=s.label;}
function renderBotPanel(){const c=$('sheet-content');c.replaceChildren();const s=botState(),status=node('div',undefined,'bot-panel-status');const dot=node('span',undefined,'bot-dot');dot.classList.toggle('on',s.on);status.append(dot,node('span',s.label));c.append(status);c.append(node('p','Default manual mode: RUN attempts the latest pending signal once. To start trading future signals until STOP, explicitly set AutoTradeWhileRunning=true in MT5. The app waits for the matching EA acknowledgement; ntfy acceptance alone is not execution.','notice'));const configured=!!(data.commandTopic&&data.commandTopic.trim()&&data.commandToken&&data.commandToken.trim()&&data.commandConfirmed);const actions=node('div',undefined,'bot-control-actions');const run=node('button',undefined,'bot-command-btn run');run.type='button';run.append(icon('play'),node('span','RUN'));run.disabled=!configured||botSending;run.onclick=()=>sendBotCommand('RUN');const stop=node('button',undefined,'bot-command-btn stop');stop.type='button';stop.append(icon('stop'),node('span','STOP'));stop.disabled=!configured||botSending;stop.onclick=()=>sendBotCommand('STOP');actions.append(run,stop);c.append(actions);if(!configured){c.append(node('p','Control is locked until you set a separate command topic, command token, and confirm that server access is restricted. The EA must also be updated to listen for commands.','bot-panel-note'));const setup=node('button','Configure command channel','save');setup.onclick=()=>{closeSheet();nav('Settings');};c.append(setup);}c.append(node('p','STOP is specified to prevent new entries; it does not close existing positions. Your EA must preserve its normal management of open trades.','bot-panel-note'));const report=data.state.bot_status||{};if(report.message)c.append(node('p',report.message,'bot-panel-note'));if(!data.active)c.append(node('p','Turn LIVE on to receive EA acknowledgements. Publishing alone does not prove that the EA acted.','bot-panel-note'));if(botFeedback)c.append(node('div',botFeedback,'feedback'));}
// v7 asynchronous command handler is defined below.
function openSheet(which){
 opener=document.activeElement;sheet=which;historyLimit=40;
 const titles={history:'History',insight:'AI Insight',info:'Receiver status',quotes:'Quotes',chat:'AI Chat',remove:'Remove connection',bot:'EA Run / Stop'};
 $('sheet-title').textContent=titles[which]||'OrionBeastFx';$('overlay').hidden=false;document.body.style.overflow='hidden';
 const c=$('sheet-content');c.replaceChildren();
 if(which==='bot')renderBotPanel();
 else if(which==='history')renderMessages(c,data.inbox||[],historyLimit,true);
 else if(which==='insight')renderInsight();
 else if(which==='info'){
  c.append(node('p','The Home LIVE button controls this phone’s alert receiver. The floating bot control publishes a Run/Stop request only after a tap and only with a configured protected command topic.','notice'));
  c.append(node('p','A published request is not proof the EA received it or placed a trade. The EA must send a status acknowledgement.','muted'));
 }else if(which==='quotes'){
  c.append(node('p','No live quote feed is connected. Watch and Standby symbols come only from structured EA messages.','notice'));
  const b=node('button','View symbols','save');b.onclick=()=>{closeSheet();nav('Terminal');};c.append(b);
 }else if(which==='chat'){
  c.append(node('p','AI chat is not connected. No AI replies or trade advice are generated.','notice'));
  const b=node('button','View received-data insights','save');b.onclick=()=>openSheet('insight');c.append(b);
 }else if(which==='remove'){
  c.append(node('p','Close this phone’s active receiver connection? Your saved alerts, symbols and settings will stay. This does not remove an EA from MetaTrader.','notice'));
  const b=node('button',data.active?'Remove active connection':'No active connection','save danger');b.disabled=!data.active;
  b.onclick=()=>{closeSheet();if(data.active)$('live-button').click();};c.append(b);
  const cancel=node('button','Cancel','action');cancel.onclick=closeSheet;c.append(cancel);
 }
 $('close-sheet').focus();
}
function closeSheet(){sheet=null;$('overlay').hidden=true;document.body.style.overflow='';if(opener)opener.focus();}
document.querySelectorAll('[data-command]').forEach(b=>b.onclick=()=>sendBotCommand(b.dataset.command));
$('history-button').onclick=()=>openSheet('history');$('insight-button').onclick=()=>openSheet('insight');$('bot-fab').onclick=()=>{botFeedback='';openSheet('bot');};$('close-sheet').onclick=closeSheet;$('overlay').onclick=e=>{if(e.target===$('overlay'))closeSheet();};
document.addEventListener('keydown',e=>{if(!sheet)return;if(e.key==='Escape')closeSheet();if(e.key==='Tab'){const a=[...$('overlay').querySelectorAll('button,[tabindex="0"]')];const first=a[0],last=a[a.length-1];if(e.shiftKey&&document.activeElement===first){e.preventDefault();last.focus();}else if(!e.shiftKey&&document.activeElement===last){e.preventDefault();first.focus();}}});
document.querySelectorAll('[data-tab]').forEach(b=>b.onclick=()=>nav(b.dataset.tab));
document.querySelectorAll('[data-action]').forEach(b=>b.onclick=()=>{
 const a=b.dataset.action;
 if(a==='trade')nav('Signal');else if(a==='analyzer')nav('Terminal');else openSheet(a);
});
$('live-button').onclick=()=>{if(!native||livePending)return;livePending=true;$('live-button').disabled=true;try{native.toggleLive();}catch(e){$('native-error').textContent=e.message;$('native-error').hidden=false;}setTimeout(()=>{read();livePending=false;$('live-button').disabled=false;},450);};
$('dark-toggle').onchange=()=>{const next=$('dark-toggle').checked;try{if(!native||!native.theme(next))throw Error('Theme could not be saved.');data.dark=next;setTheme(next);$('theme-feedback').textContent='Appearance saved';}catch(e){setTheme(!!data.dark);$('theme-feedback').textContent=e.message;}};
$('connection-form').onsubmit=e=>{e.preventDefault();try{if(!native)throw Error('Open the Android app to save settings.');const error=native.saveSettings(JSON.stringify({server:$('server').value,topic:$('topic').value,token:$('token').value,stale:Number($('stale').value),commandTopic:$('command-topic').value,commandToken:$('command-token').value,commandConfirmed:$('control-confirmed').checked}));if(error)throw Error(error);$('settings-feedback').textContent='Settings saved';read();}catch(err){$('settings-feedback').textContent=err.message;}};
if(read()){for(const name of ['server','topic','token','stale'])$(name).value=data[name]??'';$('command-topic').value=data.commandTopic||'';$('command-token').value=data.commandToken||'';$('control-confirmed').checked=!!data.commandConfirmed;}else render();
// Read app-private native state; this does not poll the network or publish anything.
setInterval(()=>{if(!document.hidden)read();},2000);document.addEventListener('visibilitychange',()=>{if(!document.hidden)read();});


let tests=0;function passed(){tests++;}
function flatten(n){return [n,...n.children.filter(x=>typeof x!=='string').flatMap(flatten)];}
const homeRun=all.find(x=>x.dataset.command==='RUN'),homeStop=all.find(x=>x.dataset.command==='STOP');
assert(homeRun&&homeStop);assert.equal(calls.length,0,'Opening app must not send any command');passed();
assert.equal(homeRun.disabled,false);assert.equal(homeStop.disabled,false);passed();
homeRun.onclick();assert.deepEqual(calls,['RUN']);assert.equal(botSending,true);assert.equal(homeRun.disabled,true);assert.match(homeRun.textContent,/SENDING/);passed();
homeRun.onclick();assert.deepEqual(calls,['RUN'],'Double tap while publishing must be ignored');passed();
window.onBotCommandResult({ok:true,message:'Published, waiting for EA'});assert.equal(botSending,false);assert.equal(homeStop.disabled,false);assert.match(ids['signal-list'].textContent||botFeedback,/Published|waiting|^$/);passed();
homeStop.onclick();assert.equal(calls.at(-1),'STOP');window.onBotCommandResult({ok:false,error:'HTTP 403: denied'});assert.equal(botSending,false);assert.match(botFeedback,/403/);passed();
ids['live-button'].onclick();assert.equal(calls.at(-1),'LIVE');passed();
stateSnapshot.commandToken='';read();assert.equal(homeRun.disabled,true);const before=calls.length;homeRun.onclick();assert.equal(calls.length,before);assert.match(botFeedback,/configure/i);passed();
stateSnapshot.commandToken='writer';read();
const now=Math.floor(Date.now()/1000);
const payload={type:'signal',side:'BUY',symbol:'EURUSD',timeframe:'M1',module:'trend',entry:'1.10000',sl:'1.09900',tp:'1.10200',signal_id:7,created_at:now,valid_for_seconds:120,score:81.5,description:'EA computed <script>not executable</script>'};
const record={id:'test1',time:now,message:JSON.stringify(payload),parsed:true};
assert.equal(signalFromMessage(record).tp,'1.10200');passed();
assert.equal(signalFromMessage({...record,message:JSON.stringify({...payload,tp:'NaN'})}),null);assert.equal(signalFromMessage({...record,message:JSON.stringify({...payload,entry:-1})}),null);passed();
assert.equal(signalFromMessage({...record,message:'{broken'}),null);assert.equal(signalFromMessage({...record,message:JSON.stringify({type:'bot_status',status:'running'})}),null);passed();
const legacy={id:'legacy',time:now-130,message:'Signal: SELL\nSymbol: GBPUSD\nTF: M5\nEntry: 1.25000\nSL: 1.25100\nTP: 1.24800 (dynamic 2.00 ATR)\nID: 8 (use app RUN)'};
assert.equal(signalFromMessage(legacy).side,'SELL');assert.equal(signalFromMessage(legacy).tp,'1.24800');passed();
assert.equal(signalFromMessage({id:'order',time:now,message:'Opened BUY EURUSD (signal #7)\nTP: 1.10200'}),null);passed();
data.inbox=[record,legacy,record,{id:'status',time:now,message:'{"type":"bot_status","status":"running"}'}];renderSignals();
const cards=ids['signal-list'].children.filter(n=>n.className.includes('signal-card '));assert.equal(cards.length,2);assert.match(cards[0].textContent,/EURUSD/);assert.match(cards[0].textContent,/BUY/);assert.match(cards[0].textContent,/1.10200/);assert.match(cards[1].textContent,/SELL/);assert.match(cards[1].textContent,/EXPIRED/);passed();
assert(flatten(cards[0]).every(n=>n.tagName!=='script'),'Signal text must never inject script elements');assert.match(cards[0].textContent,/<script>not executable<\/script>/);passed();
data.inbox=[];renderSignals();assert.match(ids['signal-list'].textContent,/No valid EA signals/);passed();
console.log(JSON.stringify({button_and_card_scenarios:tests,async_actions:calls,success:true}));
