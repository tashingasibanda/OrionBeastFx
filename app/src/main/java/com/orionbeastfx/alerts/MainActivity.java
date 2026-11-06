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
                out.put("token",Store.token(MainActivity.this));return out.toString();
            } catch(JSONException e){return "{\"error\":\"Could not read saved app data\"}";}
        }
        @JavascriptInterface public boolean theme(boolean dark) {
            boolean ok=Store.prefs(MainActivity.this).edit().putBoolean("dark",dark).commit();
            if(ok)runOnUiThread(()->bars(dark));return ok;
        }
        @JavascriptInterface public void toggleLive() { runOnUiThread(()->toggleReceiver()); }
        @JavascriptInterface public String saveSettings(String payload) {
            if(AlertService.active)return "Stop LIVE before changing the connection.";
            try {
                JSONObject p=new JSONObject(payload);String s=p.getString("server").trim().replaceAll("/+$","");
                String t=p.getString("topic").trim(),token=p.optString("token").trim();int stale=p.getInt("stale");
                URI u=new URI(s);
                if(!"https".equals(u.getScheme())||u.getHost()==null||u.getUserInfo()!=null||u.getQuery()!=null||u.getFragment()!=null) return "Enter a valid HTTPS server URL.";
                if(!t.matches("[A-Za-z0-9_-]{1,128}"))return "Topic must contain 1–128 letters, numbers, underscores or hyphens.";
                if(token.contains("\n")||token.contains("\r"))return "Invalid access token.";
                if(stale<30||stale>86400)return "Stale threshold must be 30–86400 seconds.";
                boolean ok=Store.prefs(MainActivity.this).edit().putString("server",s).putString("topic",t).putString("token",token).putInt("stale",stale).commit();
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
