package com.orionbeastfx.alerts;
import android.app.*;
import android.os.*;
import android.content.*;
import android.content.pm.PackageManager;
import android.graphics.*;
import android.graphics.drawable.*;
import android.net.Uri;
import android.view.*;
import android.widget.*;
import org.json.*;
import java.time.*;
import java.time.format.DateTimeFormatter;
import java.util.*;

public class MainActivity extends Activity {
    private final int INK=Color.rgb(55,40,25), GOLD=Color.rgb(165,119,53), GREEN=Color.rgb(27,145,98), MUTED=Color.rgb(130,119,104);
    private LinearLayout root,body;private ScrollView scroll;private String tab="Home";private boolean history=false;
    private final Handler handler=new Handler(Looper.getMainLooper());
    private final Runnable tick=new Runnable(){public void run(){render();handler.postDelayed(this,5000);}};
    int dp(float n){return (int)(getResources().getDisplayMetrics().density*n+0.5f);}
    TextView text(String s,int size,int color){TextView v=new TextView(this);v.setText(s);v.setTextSize(size);v.setTextColor(color);v.setPadding(0,dp(5),0,dp(5));return v;}
    GradientDrawable shape(int color,int radius){GradientDrawable d=new GradientDrawable();d.setColor(color);d.setCornerRadius(dp(radius));return d;}
    LinearLayout col(){LinearLayout l=new LinearLayout(this);l.setOrientation(1);return l;}
    LinearLayout row(){LinearLayout l=new LinearLayout(this);l.setGravity(Gravity.CENTER_VERTICAL);return l;}
    void space(LinearLayout l,int h){Space s=new Space(this);l.addView(s,new LinearLayout.LayoutParams(1,dp(h)));}
    TextView button(String title,Runnable action){TextView v=text(title,12,INK);v.setGravity(Gravity.CENTER);v.setPadding(dp(10),dp(12),dp(10),dp(12));v.setBackground(shape(0xEEFFFFFF,18));v.setMinHeight(dp(48));v.setOnClickListener(w->action.run());return v;}
    void weight(LinearLayout r,View v){LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(0,-2,1);lp.setMargins(dp(3),dp(3),dp(3),dp(3));r.addView(v,lp);}
    LinearLayout card(){LinearLayout c=col();c.setPadding(dp(16),dp(12),dp(16),dp(12));c.setBackground(shape(0xEDFFFDFA,22));LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(-1,-2);lp.setMargins(0,dp(10),0,dp(6));body.addView(c,lp);return c;}
    public void onCreate(Bundle state){super.onCreate(state);getWindow().setStatusBarColor(0xFFF5EEE2);getWindow().setNavigationBarColor(0xFFF5EEE2);}
    protected void onResume(){super.onResume();render();handler.postDelayed(tick,5000);}
    protected void onPause(){handler.removeCallbacks(tick);super.onPause();}
    void render(){
        int y=scroll==null?0:scroll.getScrollY();
        root=col();root.setBackground(new GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM,new int[]{0xFFF9F4EA,0xFFF1E4D0,0xFFFAF5EC}));
        root.setOnApplyWindowInsetsListener((v,i)->{v.setPadding(i.getSystemWindowInsetLeft(),i.getSystemWindowInsetTop(),i.getSystemWindowInsetRight(),i.getSystemWindowInsetBottom());return i;});
        setContentView(root);root.requestApplyInsets();
        scroll=new ScrollView(this);scroll.setFillViewport(true);body=col();body.setPadding(dp(16),dp(12),dp(16),dp(12));scroll.addView(body);root.addView(scroll,new LinearLayout.LayoutParams(-1,0,1));
        if(tab.equals("Home"))home();else if(tab.equals("Terminal"))terminal();else if(tab.equals("Signal"))signals();else settings();
        LinearLayout nav=row();nav.setPadding(dp(8),dp(5),dp(8),dp(8));nav.setBackground(shape(0xF2FFFDFA,28));
        for(String name:new String[]{"Home","Signal","Terminal","Settings"}){TextView b=button(name,()->{tab=name;history=false;scroll.scrollTo(0,0);render();});b.setTextColor(name.equals(tab)?GOLD:MUTED);weight(nav,b);}
        root.addView(nav,new LinearLayout.LayoutParams(-1,-2));scroll.post(()->scroll.scrollTo(0,y));
    }
    void home(){
        LinearLayout top=row();String status=AlertService.active?Store.prefs(this).getString("status","Connecting"):"Offline";
        TextView badge=text("● "+status.toUpperCase(Locale.ROOT),12,status.equals("Connected")?GREEN:0xFFC76149);badge.setMaxLines(2);weight(top,badge);weight(top,button("Change Image",()->pickImage()));body.addView(top);
        FrameLayout hero=new FrameLayout(this);body.addView(hero,new LinearLayout.LayoutParams(-1,dp(300)));
        ImageView art=new ImageView(this);art.setScaleType(ImageView.ScaleType.CENTER_CROP);art.setAlpha(0.65f);art.setImageResource(R.drawable.hero_chart);
        String uri=Store.prefs(this).getString("image","");if(!uri.isEmpty())try{art.setImageURI(Uri.parse(uri));}catch(Exception ex){art.setImageResource(R.drawable.hero_chart);}
        hero.addView(art,new FrameLayout.LayoutParams(-1,-1));LinearLayout branding=col();branding.setGravity(Gravity.CENTER_HORIZONTAL);branding.setPadding(0,dp(7),0,0);
        ImageView logo=new ImageView(this);logo.setImageResource(R.drawable.lion);logo.setScaleType(ImageView.ScaleType.FIT_CENTER);branding.addView(logo,new LinearLayout.LayoutParams(dp(95),dp(110)));
        TextView name=text("STAR BEAST FX",28,INK);name.setTypeface(Typeface.create("serif",Typeface.NORMAL));name.setLetterSpacing(0.10f);name.setGravity(Gravity.CENTER);branding.addView(name);
        TextView sub=text("Powered By SIBANDA · MT4/MT5",11,GOLD);sub.setGravity(Gravity.CENTER);branding.addView(sub);hero.addView(branding,new FrameLayout.LayoutParams(-1,-2));
        LinearLayout actions=row();weight(actions,button("HISTORY",()->{history=true;tab="Signal";scroll.scrollTo(0,0);render();}));weight(actions,button("AI INSIGHT",()->new AlertDialog.Builder(this).setTitle("AI Insight").setMessage("No AI provider is connected. This app never invents trade advice or performance. Use Terminal for EA-reported symbol states.").setPositiveButton("OK",null).show()));
        TextView start=button(AlertService.active?"STOP LIVE":"START LIVE",()->toggle());start.setTextColor(GREEN);start.setBackground(shape(0xFFDCEEDD,18));weight(actions,start);body.addView(actions);
        JSONObject state=Store.state(this);String today=LocalDate.now().toString();JSONObject summaries=state.optJSONObject("summaries");JSONObject summary=summaries==null?null:summaries.optJSONObject(today);
        LinearLayout c=card();TextView heading=text("Today's Summary",23,INK);heading.setTypeface(Typeface.create("serif",Typeface.NORMAL));c.addView(heading);c.addView(text(LocalDate.now().format(DateTimeFormatter.ofPattern("MMM d, yyyy")),12,MUTED));
        LinearLayout stats=row();metric(stats,summary,"trades","TRADES",false);metric(stats,summary,"win_rate","WIN RATE",false);metric(stats,summary,"net_r","NET P/L (R)",true);c.addView(stats);
        c.addView(text(summary==null?"Awaiting today's EA summary · no simulated figures":"EA-reported · "+stamp(summary.optLong("time")),11,MUTED));
        LinearLayout info=card();info.addView(text("EA connection",16,GOLD));info.addView(text("Server: "+Store.server(this)+"\nTopic: "+Store.topic(this),12,INK));
        info.addView(text("Last structured EA update: "+(state.optLong("last_ea")==0?"Not received":stamp(state.optLong("last_ea"))),12,MUTED));
        info.addView(text("Connected means the ntfy stream is open—not proof the EA is running.",11,MUTED));
    }
    void metric(LinearLayout row,JSONObject s,String key,String label,boolean signed){LinearLayout box=col();box.setGravity(Gravity.CENTER);String value="—";if(s!=null&&s.has(key)){double n=s.optDouble(key);value=key.equals("trades")?String.format(Locale.US,"%.0f",n):String.format(Locale.US,signed?"%+.2fR":"%.1f%%",n);}TextView v=text(value,24,GREEN);box.addView(v);box.addView(text(label,9,MUTED));weight(row,box);}
    String stamp(long seconds){return seconds<=0?"Not received":DateTimeFormatter.ofPattern("MMM d HH:mm:ss").format(Instant.ofEpochSecond(seconds).atZone(ZoneId.systemDefault()));}
    void terminal(){
        body.addView(text("Terminal",29,INK));body.addView(text("Symbols reported by your EA",14,GOLD));
        body.addView(text("Saved states are not assumed live. Each row shows its last ntfy message time. Send a fresh snapshot to replace the complete list.",12,MUTED));
        JSONObject symbols=Store.state(this).optJSONObject("symbols");
        for(String group:new String[]{"watch","standby"}){
            LinearLayout c=card();java.util.List<String> names=new ArrayList<>();
            if(symbols!=null)for(Iterator<String> k=symbols.keys();k.hasNext();){String key=k.next();JSONObject r=symbols.optJSONObject(key);if(r!=null&&group.equals(r.optString("state")))names.add(key);}
            Collections.sort(names);c.addView(text((group.equals("watch")?"● ON WATCH":"◌ ON STANDBY")+"  ("+names.size()+")",17,group.equals("watch")?GREEN:GOLD));
            if(names.isEmpty())c.addView(text("No symbols reported in this state.",13,MUTED));
            for(String name:names){JSONObject r=symbols.optJSONObject(name);String tf=r.optString("timeframe");c.addView(text(name+(tf.isEmpty()?"":" · "+tf),21,INK));String reason=r.optString("reason");if(!reason.isEmpty())c.addView(text(reason,13,INK));long time=r.optLong("time");boolean stale=System.currentTimeMillis()/1000-time>Store.prefs(this).getInt("stale",300);c.addView(text(stamp(time)+(stale?" · STALE":"")+(!AlertService.active?" · RECEIVER OFFLINE":""),11,MUTED));}
        }
        LinearLayout help=card();help.addView(text("No symbols yet?",17,INK));help.addView(text("Your EA must publish structured symbol or snapshot messages. Plain text alerts still appear under Signal, but the app will not guess symbol states from them. See EA-INTEGRATION.md in the project.",13,MUTED));
    }
    void signals(){
        body.addView(text(history?"History":"Signal",29,INK));body.addView(text("Latest 300 received messages · this server/topic",12,MUTED));JSONArray messages=Store.inbox(this);int shown=0;
        for(int i=0;i<messages.length();i++){JSONObject m=messages.optJSONObject(i);if(m==null)continue;if(!history&&m.optBoolean("parsed"))continue;shown++;LinearLayout c=card();c.addView(text(m.optString("title","EA message"),17,INK));c.addView(text(stamp(m.optLong("time")),11,GOLD));TextView content=text(m.optString("message"),14,INK);content.setTextIsSelectable(true);c.addView(content);if(m.has("parse_error"))c.addView(text("Not applied: "+m.optString("parse_error"),12,0xFFC76149));}
        if(shown==0)body.addView(text("No messages received for this view.",15,MUTED));
    }
    void settings(){
        body.addView(text("Settings",29,INK));LinearLayout c=card();c.addView(text("Receiver",19,INK));c.addView(text(Store.server(this)+"\nTopic: "+Store.topic(this),14,MUTED));c.addView(button("Edit server / topic / access token",()->editConnection()));c.addView(button(AlertService.active?"Stop receiver":"Start receiver",()->toggle()));
        LinearLayout design=card();design.addView(text("Appearance",19,INK));design.addView(button("Change hero image",()->pickImage()));design.addView(button("Restore ivory chart artwork",()->{Store.prefs(this).edit().remove("image").apply();render();}));
        LinearLayout state=card();state.addView(text("Terminal freshness",19,INK));state.addView(text("Mark states stale after "+Store.prefs(this).getInt("stale",300)+" seconds. Stale does not change Watch/Standby.",13,MUTED));state.addView(button("Change stale threshold",()->editStale()));
        LinearLayout sec=card();sec.addView(text("Privacy & delivery",19,INK));sec.addView(text("Public ntfy topics can be read or forged by other people. Use a protected topic and access token for private signals. Tokens are stored in app-private preferences; Android backup is disabled. Battery controls or network loss may delay delivery. This app does not place trades.",13,MUTED));
    }
    void editConnection(){
        if(AlertService.active){new AlertDialog.Builder(this).setMessage("Stop the receiver before changing the connection.").setPositiveButton("OK",null).show();return;}
        LinearLayout fields=col();fields.setPadding(dp(20),dp(8),dp(20),dp(8));EditText server=new EditText(this),topic=new EditText(this),token=new EditText(this);
        server.setHint("HTTPS server");server.setText(Store.server(this));server.setInputType(17);fields.addView(server);topic.setHint("Topic");topic.setText(Store.topic(this));topic.setSingleLine(true);fields.addView(topic);token.setHint("Access token (optional)");token.setText(Store.token(this));token.setInputType(129);fields.addView(token);
        AlertDialog dialog=new AlertDialog.Builder(this).setTitle("Connection").setView(fields).setPositiveButton("Save",null).setNegativeButton("Cancel",null).create();dialog.setOnShowListener(x->dialog.getButton(-1).setOnClickListener(v->{
            String s=server.getText().toString().trim().replaceAll("/+$",""),t=topic.getText().toString().trim(),tok=token.getText().toString().trim();
            try{java.net.URI u=new java.net.URI(s);if(!"https".equals(u.getScheme())||u.getHost()==null||u.getUserInfo()!=null||u.getQuery()!=null||u.getFragment()!=null)throw new Exception();if(!t.matches("[A-Za-z0-9_-]{1,128}"))throw new Exception();if(tok.contains("\n")||tok.contains("\r"))throw new Exception();}catch(Exception e){Toast.makeText(this,"Use a valid HTTPS server and a topic with letters, digits, _ or -.",Toast.LENGTH_LONG).show();return;}
            Store.prefs(this).edit().putString("server",s).putString("topic",t).putString("token",tok).putString("status","Offline").apply();dialog.dismiss();render();}));dialog.show();
    }
    void editStale(){EditText input=new EditText(this);input.setInputType(2);input.setText(String.valueOf(Store.prefs(this).getInt("stale",300)));AlertDialog d=new AlertDialog.Builder(this).setTitle("Stale after seconds (30–86400)").setView(input).setPositiveButton("Save",null).setNegativeButton("Cancel",null).create();d.setOnShowListener(x->d.getButton(-1).setOnClickListener(v->{try{int n=Integer.parseInt(input.getText().toString());if(n<30||n>86400)throw new Exception();Store.prefs(this).edit().putInt("stale",n).apply();d.dismiss();render();}catch(Exception e){input.setError("Enter 30 to 86400");}}));d.show();}
    void toggle(){
        if(AlertService.active){stopService(new Intent(this,AlertService.class));handler.postDelayed(()->render(),250);return;}
        if(Build.VERSION.SDK_INT>=33&&checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED){requestPermissions(new String[]{android.Manifest.permission.POST_NOTIFICATIONS},10);return;}
        startForegroundService(new Intent(this,AlertService.class));handler.postDelayed(()->render(),250);
    }
    public void onRequestPermissionsResult(int request,String[] p,int[] results){super.onRequestPermissionsResult(request,p,results);if(request==10){if(results.length>0&&results[0]==PackageManager.PERMISSION_GRANTED)toggle();else Toast.makeText(this,"Notification permission is needed to start alerts.",Toast.LENGTH_LONG).show();}}
    void pickImage(){Intent i=new Intent(Intent.ACTION_OPEN_DOCUMENT);i.setType("image/*");i.addCategory(Intent.CATEGORY_OPENABLE);i.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION|Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);startActivityForResult(i,20);}
    protected void onActivityResult(int request,int result,Intent data){super.onActivityResult(request,result,data);if(request==20&&result==RESULT_OK&&data!=null&&data.getData()!=null){Uri uri=data.getData();try{getContentResolver().takePersistableUriPermission(uri,Intent.FLAG_GRANT_READ_URI_PERMISSION);Store.prefs(this).edit().putString("image",uri.toString()).apply();render();}catch(Exception e){Toast.makeText(this,"Could not keep access to that image. Choose another file.",Toast.LENGTH_LONG).show();}}}
}
