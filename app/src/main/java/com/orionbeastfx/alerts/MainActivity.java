package com.orionbeastfx.alerts;
import android.app.Activity;
import android.os.*;
import android.content.*;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.view.View;
import android.webkit.*;
import android.widget.Toast;
import org.json.*;
import java.net.URI;
import java.net.HttpURLConnection;
import java.net.URL;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.util.UUID;

/** Trusted bundled UI; all ntfy networking remains in the native foreground service. */
public class MainActivity extends Activity {
    private WebView web;
    private void bars(boolean dark) {
        getWindow().setStatusBarColor(Color.parseColor(dark?"#121212":"#F7F4ED"));
        getWindow().setNavigationBarColor(Color.parseColor(dark?"#121212":"#F7F4ED"));
        getWindow().getDecorView().setSystemUiVisibility(dark?0:View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR|View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR);
    }
    @Override public void onCreate(Bundle saved) {
        super.onCreate(saved);setTitle("OrionBeastFx");
        // Keep the WebView inside system bars, including Android 15 edge-to-edge enforcement.
        android.widget.FrameLayout host=new android.widget.FrameLayout(this);
        host.setOnApplyWindowInsetsListener((v,insets)->{
            v.setPadding(insets.getSystemWindowInsetLeft(),insets.getSystemWindowInsetTop(),insets.getSystemWindowInsetRight(),insets.getSystemWindowInsetBottom());
            return insets.consumeSystemWindowInsets();
        });
        web=new WebView(this);host.addView(web);setContentView(host);
        bars(Store.prefs(this).getBoolean("dark",true));
        WebSettings settings=web.getSettings();settings.setJavaScriptEnabled(true);
        settings.setAllowFileAccess(false);settings.setAllowContentAccess(false);
        settings.setDomStorageEnabled(false);settings.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        web.setBackgroundColor(Color.parseColor(Store.prefs(this).getBoolean("dark",true)?"#121212":"#F7F4ED"));
        web.addJavascriptInterface(new Bridge(),"Orion");
        web.setWebViewClient(new WebViewClient(){
            @Override public boolean shouldOverrideUrlLoading(WebView view,WebResourceRequest request){return true;}
            @Override public boolean shouldOverrideUrlLoading(WebView view,String url){return true;}
        });
        web.loadUrl("file:///android_asset/index.html");
    }
    public final class Bridge {
        @JavascriptInterface public String snapshot() {
            try {
                JSONObject out=new JSONObject();
                out.put("active",AlertService.active);
                out.put("status",AlertService.active?Store.prefs(MainActivity.this).getString("status","Connecting"):"Offline");
                out.put("state",Store.state(MainActivity.this));out.put("inbox",Store.inbox(MainActivity.this));
                out.put("dark",Store.prefs(MainActivity.this).getBoolean("dark",true));
                out.put("stale",Store.prefs(MainActivity.this).getInt("stale",300));
                out.put("server",Store.server(MainActivity.this));out.put("topic",Store.topic(MainActivity.this));
                out.put("token",Store.token(MainActivity.this));
                android.content.SharedPreferences p=Store.prefs(MainActivity.this);
                out.put("commandTopic",p.getString("commandTopic",""));out.put("commandToken",p.getString("commandToken",""));out.put("commandConfirmed",p.getBoolean("commandConfirmed",false));
                out.put("commandState",p.getString("commandState",""));out.put("commandTime",p.getLong("commandTime",0));out.put("commandId",p.getString("commandId",""));return out.toString();
            } catch(JSONException e){return "{\"error\":\"Could not read saved app data\"}";}
        }
        @JavascriptInterface public boolean theme(boolean dark) {
            boolean ok=Store.prefs(MainActivity.this).edit().putBoolean("dark",dark).commit();
            if(ok)runOnUiThread(()->bars(dark));return ok;
        }
        @JavascriptInterface public void toggleLive() { runOnUiThread(()->toggleReceiver()); }
        @JavascriptInterface public synchronized String sendBotCommand(String command) {
            String action=command==null?"":command.trim().toUpperCase(java.util.Locale.ROOT);
            if(!action.equals("RUN")&&!action.equals("STOP"))return commandResult(false,"Only explicit RUN or STOP commands are allowed.",null);
            android.content.SharedPreferences p=Store.prefs(MainActivity.this);
            String commandTopic=p.getString("commandTopic","").trim(),commandToken=p.getString("commandToken","").trim();
            if(commandTopic.isEmpty()||!commandTopic.matches("[A-Za-z0-9_-]{1,128}"))return commandResult(false,"Configure a valid, separate EA command topic first.",null);
            if(commandTopic.equals(Store.topic(MainActivity.this)))return commandResult(false,"The EA command topic must differ from the alert topic.",null);
            if(commandToken.isEmpty())return commandResult(false,"A command access token is required.",null);
            if(!p.getBoolean("commandConfirmed",false))return commandResult(false,"Confirm that the command topic is access-controlled before sending.",null);
            String controller=p.getString("controllerId","");
            if(controller.isEmpty())controller=UUID.randomUUID().toString();
            String id=UUID.randomUUID().toString();long sequence=p.getLong("commandSequence",0L)+1L;long now=System.currentTimeMillis()/1000L;
            if(sequence<=0||sequence>999999999999999L)return commandResult(false,"Command sequence exhausted; configure a new controller.",null);
            if(!p.edit().putString("controllerId",controller).putLong("commandSequence",sequence).commit())return commandResult(false,"Could not reserve a safe command sequence.",null);
            try {
                JSONObject body=new JSONObject();body.put("type","bot_command");body.put("action",action);body.put("command_id",id);body.put("sequence",sequence);body.put("requested_at",now);body.put("controller_id",controller);
                byte[] bytes=body.toString().getBytes(StandardCharsets.UTF_8);
                URL url=new URL(Store.server(MainActivity.this)+"/"+commandTopic);HttpURLConnection c=(HttpURLConnection)url.openConnection();
                try {
                    c.setRequestMethod("POST");c.setConnectTimeout(7000);c.setReadTimeout(7000);c.setInstanceFollowRedirects(false);
                    c.setRequestProperty("Content-Type","text/plain; charset=utf-8");c.setRequestProperty("Title","OrionBeastFx EA control");c.setRequestProperty("Authorization","Bearer "+commandToken);
                    c.setDoOutput(true);c.setFixedLengthStreamingMode(bytes.length);try(OutputStream os=c.getOutputStream()){os.write(bytes);}
                    int status=c.getResponseCode();if(status<200||status>=300)return commandResult(false,"ntfy rejected the command (HTTP "+status+"). Check the server and command token.",null);
                } finally { c.disconnect(); }
                boolean saved=p.edit().putLong("commandSequence",sequence).putString("commandState",action+"_REQUESTED").putLong("commandTime",now).putString("commandId",id).commit();
                return commandResult(true,saved?"ntfy accepted the request; this does not confirm EA execution.":"ntfy accepted the request, but the app could not save its local status.",id);
            } catch(Exception ex) { return commandResult(false,"Could not reach the command server. No EA execution is confirmed.",null); }
        }
        private String commandResult(boolean ok,String message,String id) {
            JSONObject result=new JSONObject();try{result.put("ok",ok);result.put(ok?"message":"error",message);if(id!=null)result.put("commandId",id);return result.toString();}catch(JSONException e){return "{\"ok\":false,\"error\":\"Command result unavailable\"}";}
        }
        @JavascriptInterface public String saveSettings(String payload) {
            if(AlertService.active)return "Stop LIVE before changing the connection.";
            try {
                JSONObject p=new JSONObject(payload);String s=p.getString("server").trim().replaceAll("/+$","");
                String t=p.getString("topic").trim(),token=p.optString("token").trim();int stale=p.getInt("stale");
                String commandTopic=p.optString("commandTopic","").trim(),commandToken=p.optString("commandToken","").trim();boolean commandConfirmed=p.optBoolean("commandConfirmed",false);
                URI u=new URI(s);
                if(!"https".equals(u.getScheme())||u.getHost()==null||u.getUserInfo()!=null||u.getQuery()!=null||u.getFragment()!=null) return "Enter a valid HTTPS server URL.";
                if(!t.matches("[A-Za-z0-9_-]{1,128}"))return "Topic must contain 1–128 letters, numbers, underscores or hyphens.";
                if(token.contains("\n")||token.contains("\r")||commandToken.contains("\n")||commandToken.contains("\r"))return "Invalid access token.";
                if(!commandTopic.isEmpty()&&!commandTopic.matches("[A-Za-z0-9_-]{1,128}"))return "Command topic must contain 1–128 letters, numbers, underscores or hyphens.";
                if(!commandTopic.isEmpty()&&commandTopic.equals(t))return "Use a separate command topic, not the alert topic.";
                if(!commandTopic.isEmpty()&&commandToken.isEmpty())return "Enter a command token before enabling EA controls.";
                if(!commandTopic.isEmpty()&&!commandConfirmed)return "Confirm that the command topic is access-controlled.";
                if(commandTopic.isEmpty()){commandToken="";commandConfirmed=false;}
                if(stale<30||stale>86400)return "Stale threshold must be 30–86400 seconds.";
                android.content.SharedPreferences previous=Store.prefs(MainActivity.this);
                if(!s.equals(Store.server(MainActivity.this))||!t.equals(Store.topic(MainActivity.this))||!commandTopic.equals(previous.getString("commandTopic",""))) {
                    if(!previous.edit().remove("commandState").remove("commandTime").remove("commandId").commit())return "Could not reset the previous control channel status.";
                }
                boolean ok=Store.prefs(MainActivity.this).edit().putString("server",s).putString("topic",t).putString("token",token).putInt("stale",stale).putString("commandTopic",commandTopic).putString("commandToken",commandToken).putBoolean("commandConfirmed",commandConfirmed).commit();
                return ok?"":"Could not save settings to this device.";
            }catch(Exception e){return "Check the server, topic and stale threshold.";}
        }
    }
    private void toggleReceiver() {
        if(AlertService.active){stopService(new Intent(this,AlertService.class));return;}
        if(Build.VERSION.SDK_INT>=33&&checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED){
            requestPermissions(new String[]{android.Manifest.permission.POST_NOTIFICATIONS},10);return;
        }
        try{startForegroundService(new Intent(this,AlertService.class));}
        catch(Exception e){Toast.makeText(this,"Could not start receiver: "+e.getMessage(),Toast.LENGTH_LONG).show();}
    }
    @Override public void onRequestPermissionsResult(int request,String[] permissions,int[] results){
        super.onRequestPermissionsResult(request,permissions,results);
        if(request==10){if(results.length>0&&results[0]==PackageManager.PERMISSION_GRANTED)toggleReceiver();
        else Toast.makeText(this,"Notification permission is required to receive alerts.",Toast.LENGTH_LONG).show();}
    }
    @Override public void onBackPressed(){if(web!=null)web.evaluateJavascript("window.goHome && window.goHome()",null);else super.onBackPressed();}
    @Override protected void onDestroy(){if(web!=null){web.removeJavascriptInterface("Orion");web.destroy();}super.onDestroy();}
}
