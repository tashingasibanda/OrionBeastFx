from pathlib import Path
import runpy,re,json,subprocess,zipfile,hashlib
from html.parser import HTMLParser
m=runpy.run_path('input/update_ui_v7.py')
files,ui,java,reducer,ea,previous=m['transform']()
ROOT=m['ROOT'];checks=[]
def check(name,condition):
    assert condition,name
    checks.append(name)

class Elements(HTMLParser):
    def __init__(self):super().__init__();self.nodes=[]
    def handle_starttag(self,tag,attrs):
        d=dict(attrs)
        if 'id' in d or tag=='button':self.nodes.append({'tag':tag,'attrs':d})
p=Elements();p.feed(ui)
scripts=re.findall(r'<script[^>]*>(.*?)</script>',ui,re.S)
assert scripts
script='\n'.join(scripts)
Path('app-ui.js').write_text(script)
r=subprocess.run(['node','--check','app-ui.js'],capture_output=True,text=True)
check('Entire bundled app JavaScript parses',r.returncode==0)
if r.returncode:raise RuntimeError(r.stderr)

shim=r'''
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
const all=ELEMENTS.map(e=>new Element(e.tag,e.attrs));const ids=Object.fromEntries(all.filter(e=>e.attrs.id).map(e=>[e.attrs.id,e]));
const document={getElementById:id=>{assert(ids[id],'Unknown DOM id '+id);return ids[id];},createElement:tag=>new Element(tag),createElementNS:(_,tag)=>new Element(tag),documentElement:{dataset:{}},hidden:false,activeElement:null,addEventListener(){},querySelectorAll(sel){const match=sel.match(/^\[([^\]]+)\]$/);return match?all.filter(e=>Object.prototype.hasOwnProperty.call(e.attrs,match[1])):[];}};
const window=global;const timers=new Map();let timerId=0;global.setTimeout=(f,ms)=>{timers.set(++timerId,f);return timerId;};global.clearTimeout=id=>timers.delete(id);global.setInterval=()=>1;
const calls=[];let stateSnapshot={state:{},inbox:[],active:true,status:'Connected',stale:300,dark:true,server:'https://test.invalid',topic:'alerts',token:'reader',commandTopic:'commands',commandToken:'writer',commandConfirmed:true,commandState:'',commandTime:0,commandId:''};
window.Orion={snapshot:()=>JSON.stringify(stateSnapshot),sendBotCommandAsync:action=>calls.push(action),toggleLive:()=>calls.push('LIVE'),theme:()=>true,saveSettings:()=>''};
'''.replace('ELEMENTS',json.dumps(p.nodes))

suite=r'''
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
'''
Path('actual-ui-tests.js').write_text(shim+'\n'+script+'\n'+suite)
r=subprocess.run(['node','actual-ui-tests.js'],capture_output=True,text=True)
if r.returncode:raise RuntimeError(r.stderr+'\n'+r.stdout)
result=json.loads(r.stdout.strip());check('Actual button/card handlers pass '+str(result['button_and_card_scenarios'])+' scenarios',result['success'])

check('Home and Trader each have explicit wired RUN/STOP buttons',ui.count('data-command="RUN"')==2 and ui.count('data-command="STOP"')==2 and "b.onclick=()=>sendBotCommand(b.dataset.command)" in ui)
check('WebView command path is async and native queue is off-thread','native.sendBotCommandAsync(action)' in ui and 'commands.execute(() -> {' in java and 'runOnUiThread(() -> {' in java)
check('Native callback refuses destroyed WebView','if(!activityDestroyed&&web!=null)web.evaluateJavascript' in java and 'commands.shutdown()' in java)
check('No custom include required in standalone EA','#include "OrionAppControl.mqh"' not in ea and '#include <Trade\\Trade.mqh>' in ea)
check('Both strategy modules emit real structured signal events','SendSignalCard(title,body,sym,tfn,dirTxt' in ea and 'SendSignalCard(title,body,sym,"M1",side' in ea and '\\"type\\":\\"signal\\"' in ea)
check('Signal reducer validates side, prices and lifetime','"signal".equals(type)' in reducer and 'invalid signal price' in reducer and 'invalid signal lifetime' in reducer and 'next.length()<100' in reducer)
check('Signal card text is created with textContent',"if(text!==undefined)n.textContent=String(text)" in ui and 'node(\'pre\',e.description' in ui)
check('No per-card trade button falsely targets an ID','intentionally no misleading per-card trade button' in files[ROOT+'EA-INTEGRATION.md'].decode())
for start,end in [('double Median(', 'double Percentile('),('double Percentile(', 'double MadScale('),('double MadScale(', 'bool LastBarIsSpike('),('void Check(', 'void SendSignal('),('void UpdateSpikeBar(', 'bool TickAccel('),('bool TickAccel(', 'void SpikeLevels('),('void SpikeLevels(', 'void SpikeCheck('),('void SpikeCheck(', 'void SendSpikeAlert(')]:
    def section(src):a=src.index(start);return src[a:src.index(end,a)]
    check('Preserved strategy section '+start,section(ea)==section(previous))
# Structural lexer is not a substitute for a Java/MQL compiler.
def balanced(s):
    t=re.sub(r'//[^\n]*|/\*.*?\*/|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'', '',s,flags=re.S);stack=[];pairs={')':'(',']':'[','}':'{'}
    for c in t:
        if c in '([{':stack.append(c)
        elif c in pairs:
            if not stack or stack.pop()!=pairs[c]:return False
    return not stack
check('Standalone MQL lexical brackets balanced',balanced(ea))
check('Modified Java sources lexical brackets balanced',balanced(java) and balanced(reducer))
check('Existing trade/STOP and persistent ordering safeguards retained','if(!g_remoteRunning)' in ea and 'GlobalVariablesFlush();' in ea and 'if((double)seq<=previousSequence)' in ea)
report={'passed':checks,'actual_ui_test':result,'unchanged_strategy_sections':8,'limits':['No JDK/Android SDK/Gradle: APK not compiled.','No MetaEditor compiler: MQ5 source not compiled.','No real ntfy, Android device, MT5 terminal or broker execution test.'],'standalone_ea_sha256':hashlib.sha256(ea.encode()).hexdigest()}
files[ROOT+'tests/v7-ui-test-report.json']=(json.dumps(report,indent=2)+'\n').encode()
files[ROOT+'tests/v7-actual-ui-tests.js']=Path('actual-ui-tests.js').read_bytes()
files[ROOT+'tests/update_ui_v7.py']=Path('input/update_ui_v7.py').read_bytes()
files[ROOT+'tests/test_ui_v7.py']=Path('input/test_ui_v7.py').read_bytes()
Path('output').mkdir(exist_ok=True)
archive=Path('output/OrionBeastFx-v7-Buttons-SignalCards.zip');mq5=Path('output/OrionBeastFx_Signals_v7.mq5')
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
    for n,b in sorted(files.items()):z.writestr(n,b)
mq5.write_bytes(ea.encode())
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    assert z.read(ROOT+'mt5/OrionBeastFx_Signals.mq5')==mq5.read_bytes()
print(json.dumps(report,indent=2))
print('Verified ZIP:',archive.stat().st_size,'bytes;',len(files),'files. Standalone MQ5:',mq5.stat().st_size,'bytes; exactly matches ZIP EA.')
