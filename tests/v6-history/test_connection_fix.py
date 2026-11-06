from pathlib import Path
import runpy, subprocess, re, json, hashlib, zipfile

migration=runpy.run_path('input/build_connection_fix.py')
files,ea,ui,bridge=migration['make_sources']()
root=migration['ROOT']
checks=[]
def check(name, condition):
    assert condition,name
    checks.append(name)

check('EA includes JSON bridge exactly once',ea.count('#include "OrionAppControl.mqh"')==1)
check('One command processor; no plaintext fallback','void ProcessCommand(' not in ea and bridge.count('void ProcessCommand(')==1 and 'StringFind(m, kw)' not in ea)
check('Startup stopped and optional continuous mode is OFF by default','bool g_remoteRunning = false;' in bridge and 'input bool AutoTradeWhileRunning = false;' in bridge)
check('Authenticated command subscription','Authorization: Bearer "+CommandReadToken' in bridge)
check('Authenticated alert/status publishing','"Authorization: Bearer " + AlertWriteToken' in ea)
check('Separate protected topics required','CommandTopic==NtfyTopic' in bridge and '!ConfirmProtectedTopics' in bridge)
check('UTC freshness and future-time checks present','now-at>CommandMaxAgeSeconds' in bridge and 'at-now>15' in bridge and 'at<(long)g_startedUtc' in bridge)
check('Replay marker flush precedes trade execution',bridge.index('GlobalVariablesFlush();')<bridge.index('if(n>0) ExecuteQueued(n-1);'))
check('Persistent UUID key is channel/account scoped','string data=ControlServer()+"/"+CommandTopic+"/"+id;' in bridge and 'ACCOUNT_LOGIN' in bridge)
check('Channel singleton guard present','GlobalVariableSetOnCondition(g_controlLock,g_controlOwner,0)' in bridge)
check('STOP processed even with trading disabled',bridge.index('if(action=="STOP")')<bridge.index('if(!TradeOnRun)') and 'if(TradeOnRun && CommandPollSeconds' not in ea)
check('STOP clears queue and never closes broker positions','while(ArraySize(pq_id)>0) RemoveQueued(0);' in bridge and 'PositionClose' not in bridge and 'PositionClose' not in ea)
check('Final order gate checks remote STOP','if(!g_remoteRunning)' in ea[ea.index('bool TryTrade('):ea.index('void ExecuteQueued(')])
check('Continuous mode clears pre-RUN queue','if(AutoTradeWhileRunning)\n   {\n      while(ArraySize(pq_id)>0) RemoveQueued(0);' in bridge)
check('Signal-only timer still polls STOP/status','ControlTimer();' in ea and 'if(TradeOnRun && CommandPollSeconds' not in ea)
check('Broker trade limits retained','CountMyPositions("") >= MaxOpenTrades' in ea and 'OneTradePerSymbol && CountMyPositions(sym) > 0' in ea)
check('No unbounded since=all replay','since = "all"' not in ea and 'since="all"' not in bridge)
check('Parser source includes escaped-string, root-field and duplicate-key handling','bool JString(' in bridge and 'bool JSkip(' in bridge and 'keys[i]==key' in bridge and "else if(c=='u')" in bridge)
check('Persistent controller sequence rejects delayed same-second RUN','SeenKey("SEQ_"+controller)' in bridge and 'if((double)seq<=previousSequence)' in bridge and 'GlobalVariableSet(sequenceKey,(double)seq)' in bridge)
main=files[root+'app/src/main/java/com/orionbeastfx/alerts/MainActivity.java'].decode()
check('App reserves a persistent controller sequence before sending',main.index('putString("controllerId",controller).putLong("commandSequence",sequence).commit()')<main.index('URL url=new URL(Store.server'))
check('App sends controller UUID in command JSON','body.put("controller_id",controller)' in main)
check('Monotonic timers do not stall on UTC clock correction','GetTickCount64()' in bridge and 'now-g_lastPollMs' in bridge)
check('Malformed/future envelope cannot poison event watermark','g_lastEventUtc' not in bridge and 'eventTime<=now+15' in bridge and 'eventTime<=now) g_cursorUtc=eventTime' in bridge)
check('Status carries command ID and mode','JsonQuote(g_ackId)' in bridge and 'JsonQuote(mode)' in bridge)
check('Local publication is not claimed to be an EA execution','this does not confirm EA execution' in files[root+'app/src/main/java/com/orionbeastfx/alerts/MainActivity.java'].decode())

scripts=re.findall(r'<script[^>]*>(.*?)</script>',ui,re.S)
assert scripts
Path('ui-syntax.js').write_text('\n'.join(scripts))
result=subprocess.run(['node','--check','ui-syntax.js'],capture_output=True,text=True)
assert result.returncode==0,result.stderr
checks.append('Bundled WebView JavaScript parses in Node')

bot=re.search(r'^function botState\(\).*$',ui,re.M).group()
js='''const assert=require('assert');
const now=Math.floor(Date.now()/1000);
let data;
function stale(t){return now-Number(t)>300;}
'''+bot+'''
function state(request,ack){data={commandId:request.id||'',commandState:request.state||'',commandTime:request.time||0,state:{bot_status:ack||{}}};return botState();}
assert.equal(state({},{}).on,false);
assert.match(state({id:'a',state:'RUN_REQUESTED',time:now},{}).label,/awaiting/);
assert.equal(state({id:'a',state:'RUN_REQUESTED',time:now},{status:'running',command_id:'b',time:now,mode:'continuous'}).on,false);
assert.equal(state({id:'a',state:'RUN_REQUESTED',time:now},{status:'running',command_id:'a',time:now,mode:'continuous'}).on,true);
assert.match(state({id:'a',state:'RUN_REQUESTED',time:now},{status:'running',command_id:'a',time:now,mode:'manual'}).label,/manual RUN/);
assert.match(state({id:'b',state:'STOP_REQUESTED',time:now},{status:'stopped',command_id:'b',time:now}).label,/STOPPED/);
assert.equal(state({id:'a',state:'RUN_REQUESTED',time:now-500},{status:'running',command_id:'a',time:now-500}).on,false);
assert.match(state({id:'a',state:'RUN_REQUESTED',time:now-40},{}).label,/unconfirmed/);
assert.match(state({id:'a',state:'STOP_REQUESTED',time:now-40},{status:'running',command_id:'old',time:now}).label,/STOP unconfirmed/);
assert.equal(state({id:'a',state:'RUN_REQUESTED',time:now+5},{status:'running',command_id:'a',time:now,mode:'continuous'}).on,true);
assert.match(state({}, {status:'stopped',time:now}).label,/STOPPED/);
console.log('11 actual botState scenarios passed');
'''
Path('ui-test.js').write_text(js)
result=subprocess.run(['node','ui-test.js'],capture_output=True,text=True)
assert result.returncode==0,result.stderr
checks.append(result.stdout.strip())

# A string/comment-aware bracket check is useful but is NOT an MQL compiler.
def balanced(source):
    tokens=re.sub(r'//[^\n]*|/\*.*?\*/|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'', '',source,flags=re.S)
    stack=[]
    for c in tokens:
        if c in '([{':stack.append(c)
        elif c in ')]}':
            if not stack or stack.pop()!='([{['[')]}'.index(c)]:return False
    return not stack
check('EA lexical bracket balance',balanced(ea))
check('Bridge lexical bracket balance',balanced(bridge))

report={'checks_passed':checks,'unchanged_strategy_sections':8,'limitations':['No Android JDK/SDK/Gradle available; no APK compilation.','No MetaEditor/MQL5 compiler available; MQL lexical/source checks are not compilation.','No ntfy network end-to-end test, broker order, or device test performed.','No .apk or .ex5 included.'], 'sources':{'original_ea_sha256':hashlib.sha256(Path('input/OrionBeastFx_Signals.mq5').read_bytes()).hexdigest(),'original_android_zip_sha256':hashlib.sha256(Path('input/OrionBeastFx-Android-Project-v5.zip').read_bytes()).hexdigest(),'patched_ea_sha256':hashlib.sha256(ea.encode()).hexdigest(),'bridge_sha256':hashlib.sha256(bridge.encode()).hexdigest()}}
files[root+'tests/connection-test-report.json']=(json.dumps(report,indent=2)+'\n').encode()
files[root+'tests/test_connection_fix.py']=Path('input/test_connection_fix.py').read_bytes()
files[root+'tests/build_connection_fix.py']=Path('input/build_connection_fix.py').read_bytes()
files[root+'tests/README.md']=b'''# Reproducing host-side checks
These tests run against the original two uploads plus the migration helper, final OrionAppControl.mqh and EA-CONNECTION-SETUP.md.
Place all five source files, and test_connection_fix.py, in a directory named input/ then run python input/test_connection_fix.py from its parent. Python 3 and Node are required.
This is source/static and real bundled-UI testing, NOT MQL5 or Android compilation and NOT a live-network test.
'''
Path('output').mkdir(exist_ok=True)
archive=Path('output/OrionBeastFx-v6-Android-MT5-Connection-Fix.zip')
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
    for n,b in sorted(files.items()):z.writestr(n,b)
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    assert len(z.namelist())==len(set(z.namelist()))
    assert z.read(root+'mt5/OrionBeastFx_Signals.mq5').decode()==ea
    assert z.read(root+'mt5/OrionAppControl.mqh').decode()==bridge
print(json.dumps(report,indent=2))
print('ARCHIVE CHECK PASSED:',len(files),'files,',archive.stat().st_size,'bytes')
