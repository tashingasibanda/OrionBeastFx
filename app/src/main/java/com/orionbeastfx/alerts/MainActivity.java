package com.orionbeastfx.alerts;
import android.app.*;
import android.os.*;
import android.content.*;
import android.graphics.Color;
import android.widget.*;
import org.json.*;
import java.text.DateFormat;
import java.util.Date;

public class MainActivity extends Activity {
    private LinearLayout body;
    private EditText topic;
    private TextView status;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private final Runnable refresh = new Runnable() { public void run() { render(); handler.postDelayed(this, 2000); } };
    private TextView text(String s, int size, int color) {
        TextView t = new TextView(this); t.setText(s); t.setTextSize(size); t.setTextColor(color); t.setPadding(0,12,0,12); return t;
    }
    public void onCreate(Bundle saved) {
        super.onCreate(saved);
        LinearLayout root = new LinearLayout(this); root.setOrientation(1); root.setPadding(32,32,32,16); root.setBackgroundColor(Color.rgb(10,18,30));
        root.addView(text("ORION BEAST FX", 28, Color.rgb(56,230,189)));
        root.addView(text("EA NOTIFICATION RECEIVER\nServer: https://ntfy.sh", 14, Color.LTGRAY));
        topic = new EditText(this); topic.setSingleLine(true); topic.setTextColor(Color.WHITE); topic.setText(Store.topic(this)); topic.setHint("Topic"); root.addView(topic);
        Button start = new Button(this); start.setText("START RECEIVING ALERTS"); root.addView(start);
        Button stop = new Button(this); stop.setText("STOP RECEIVING"); root.addView(stop);
        status = text("",14,Color.rgb(56,230,189)); root.addView(status);
        root.addView(text("Public topics are not private. Anyone who knows this topic may read or publish alerts. Verify every signal; this app does not trade.",12,Color.LTGRAY));
        root.addView(text("RECENT ALERTS",18,Color.WHITE));
        ScrollView scroll = new ScrollView(this); body = new LinearLayout(this); body.setOrientation(1); scroll.addView(body); root.addView(scroll,new LinearLayout.LayoutParams(-1,0,1));
        setContentView(root);
        start.setOnClickListener(v -> {
            String t = topic.getText().toString().trim();
            if (!t.matches("[A-Za-z0-9_-]{1,64}")) { topic.setError("Use 1–64 letters, digits, underscore or dash"); return; }
            Store.prefs(this).edit().putString("topic",t).apply();
            if (Build.VERSION.SDK_INT>=33 && checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS)!=android.content.pm.PackageManager.PERMISSION_GRANTED) {
                requestPermissions(new String[]{android.Manifest.permission.POST_NOTIFICATIONS},10); return;
            }
            begin();
        });
        stop.setOnClickListener(v -> { stopService(new Intent(this,AlertService.class)); Store.status(this,"Stopped"); render(); });
    }
    private void begin() {
        NotificationManager nm = getSystemService(NotificationManager.class);
        if (!nm.areNotificationsEnabled()) { new AlertDialog.Builder(this).setMessage("Notifications are disabled. Enable them in Android Settings for Orion Beast FX, then tap Start.").setPositiveButton("OK",null).show(); return; }
        startForegroundService(new Intent(this,AlertService.class));
    }
    public void onRequestPermissionsResult(int request, String[] p, int[] results) {
        super.onRequestPermissionsResult(request,p,results);
        if (request==10 && results.length>0 && results[0]==android.content.pm.PackageManager.PERMISSION_GRANTED) begin();
        else Toast.makeText(this,"Notification permission is needed for EA alerts.",Toast.LENGTH_LONG).show();
    }
    protected void onResume() { super.onResume(); handler.post(refresh); }
    protected void onPause() { handler.removeCallbacks(refresh); super.onPause(); }
    private void render() {
        status.setText(Store.prefs(this).getString("status","Stopped — tap Start to subscribe")); body.removeAllViews();
        JSONArray messages = Store.inbox(this);
        if (messages.length()==0) body.addView(text("No alerts yet. Start receiving, then wait for your EA to publish to the same topic.",15,Color.LTGRAY));
        for (int i=0;i<messages.length();i++) {
            JSONObject m = messages.optJSONObject(i); if (m==null) continue;
            String time = DateFormat.getDateTimeInstance().format(new Date(m.optLong("time")*1000L));
            body.addView(text(m.optString("title","EA alert"),18,Color.rgb(56,230,189)));
            body.addView(text(m.optString("message"),16,Color.WHITE));
            body.addView(text(time+" • "+m.optString("topic"),11,Color.GRAY));
        }
    }
}
