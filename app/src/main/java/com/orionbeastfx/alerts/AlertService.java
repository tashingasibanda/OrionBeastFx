package com.orionbeastfx.alerts;
import android.app.*;
import android.content.*;
import android.content.pm.ServiceInfo;
import android.os.*;
import java.io.*;
import java.net.*;
import java.util.*;
import org.json.*;

public class AlertService extends Service {
    private static final String LIVE="connection", ALERTS="ea_alerts";
    private volatile boolean running=false;
    private volatile HttpURLConnection connection;
    private Thread worker;
    private String currentTopic;
    private NotificationManager notifications;
    public IBinder onBind(Intent i) { return null; }
    public void onCreate() {
        super.onCreate(); notifications=getSystemService(NotificationManager.class);
        notifications.createNotificationChannel(new NotificationChannel(LIVE,"Receiver status",NotificationManager.IMPORTANCE_LOW));
        NotificationChannel alerts=new NotificationChannel(ALERTS,"EA trading alerts",NotificationManager.IMPORTANCE_HIGH);
        alerts.enableVibration(true); alerts.setDescription("Messages published to your configured ntfy topic"); notifications.createNotificationChannel(alerts);
    }
    private PendingIntent openApp() { return PendingIntent.getActivity(this,0,new Intent(this,MainActivity.class),PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE); }
    private Notification live(String text) {
        PendingIntent stop=PendingIntent.getService(this,1,new Intent(this,AlertService.class).setAction("STOP"),PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE);
        return new Notification.Builder(this,LIVE).setSmallIcon(com.orionbeastfx.alerts.R.drawable.ic_orion).setContentTitle("Orion Beast FX receiver").setContentText(text).setContentIntent(openApp()).setOngoing(true).addAction(new Notification.Action.Builder(null,"Stop",stop).build()).build();
    }
    public int onStartCommand(Intent intent,int flags,int id) {
        if (intent!=null && "STOP".equals(intent.getAction())) { stopSelf(); return START_NOT_STICKY; }
        String requested=Store.topic(this);
        if (Build.VERSION.SDK_INT>=34) startForeground(1,live("Connecting…"),ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE);
        else startForeground(1,live("Connecting…"));
        if (running) {
            if (!requested.equals(currentTopic)) { Store.status(this,"Stop receiving before changing topics, then tap Start again."); }
            return START_STICKY;
        }
        running=true; currentTopic=requested;
        worker=new Thread(() -> listen(currentTopic),"ntfy-receiver"); worker.start(); return START_STICKY;
    }
    private void update(String s) { Store.status(this,s); if(running) notifications.notify(1,live(s)); }
    private void listen(String topic) {
        long delay=2000;
        Set<String> seen=new LinkedHashSet<>();
        String cursor=Store.prefs(this).getString("cursor:"+topic,"");
        // First connection starts now; reconnects recover from the last received ID or start time.
        String since=cursor.isEmpty()?Long.toString(System.currentTimeMillis()/1000):cursor;
        JSONArray history=Store.inbox(this);
        for(int i=0;i<history.length();i++) { JSONObject m=history.optJSONObject(i); if(m!=null) seen.add(m.optString("id")); }
        while(running) {
            HttpURLConnection c=null;
            try {
                update("Connecting to "+topic+"…");
                URL url=new URL("https://ntfy.sh/"+topic+"/json?since="+URLEncoder.encode(since,"UTF-8"));
                c=(HttpURLConnection)url.openConnection(); connection=c;
                c.setConnectTimeout(15000); c.setReadTimeout(90000); c.setInstanceFollowRedirects(false);
                c.setRequestProperty("Accept","application/x-ndjson");
                int code=c.getResponseCode();
                if(code!=200) throw new IOException("Server returned HTTP "+code);
                update("Listening • "+topic); delay=2000;
                try(BufferedReader reader=new BufferedReader(new InputStreamReader(c.getInputStream(),"UTF-8"))) {
                    String line;
                    while(running && (line=reader.readLine())!=null) {
                        if(line.trim().isEmpty()) continue;
                        JSONObject m=new JSONObject(line);
                        if(!"message".equals(m.optString("event"))) continue;
                        String messageId=m.getString("id");
                        if(seen.contains(messageId)) continue;
                        notifyAlert(m); Store.save(this,m,topic); since=messageId; seen.add(messageId);
                        if(seen.size()>500) { Iterator<String> it=seen.iterator(); it.next(); it.remove(); }
                    }
                }
                if(running) update("Connection ended — reconnecting…");
            } catch(Exception e) {
                if(running) update("Retrying: "+e.getClass().getSimpleName()+" — "+String.valueOf(e.getMessage()));
            } finally { if(c!=null)c.disconnect(); connection=null; }
            if(running) { try { Thread.sleep(delay); } catch(InterruptedException e) { break; } delay=Math.min(60000,delay*2); }
        }
    }
    private void notifyAlert(JSONObject m) {
        String title=m.optString("title","Orion Beast FX • EA alert"), body=m.optString("message","");
        Notification n=new Notification.Builder(this,ALERTS).setSmallIcon(com.orionbeastfx.alerts.R.drawable.ic_orion).setContentTitle(title).setContentText(body).setStyle(new Notification.BigTextStyle().bigText(body)).setContentIntent(openApp()).setAutoCancel(true).setCategory(Notification.CATEGORY_MESSAGE).setVisibility(Notification.VISIBILITY_PRIVATE).build();
        notifications.notify(m.optString("id"),2,n);
    }
    public void onDestroy() {
        running=false; if(worker!=null)worker.interrupt(); HttpURLConnection c=connection; if(c!=null)c.disconnect();
        Store.status(this,"Stopped"); stopForeground(STOP_FOREGROUND_REMOVE); super.onDestroy();
    }
}
