package com.orionbeastfx.alerts;
import android.app.*;
import android.content.*;
import android.content.pm.ServiceInfo;
import android.os.*;
import java.io.*;
import java.net.*;
import org.json.*;

public class AlertService extends Service {
    private static final String LIVE="connection",ALERTS="ea_alerts";
    static volatile boolean active=false;
    private volatile boolean running=false;
    private volatile HttpURLConnection connection;
    private Thread worker;
    private NotificationManager notifications;
    public IBinder onBind(Intent i){return null;}
    public void onCreate(){
        super.onCreate();notifications=getSystemService(NotificationManager.class);
        notifications.createNotificationChannel(new NotificationChannel(LIVE,"Receiver status",NotificationManager.IMPORTANCE_LOW));
        NotificationChannel ch=new NotificationChannel(ALERTS,"EA alerts",NotificationManager.IMPORTANCE_HIGH);ch.enableVibration(true);notifications.createNotificationChannel(ch);
    }
    private PendingIntent open(){return PendingIntent.getActivity(this,0,new Intent(this,MainActivity.class),PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE);}
    private Notification live(String message){
        PendingIntent stop=PendingIntent.getService(this,1,new Intent(this,AlertService.class).setAction("STOP"),PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE);
        return new Notification.Builder(this,LIVE).setSmallIcon(R.drawable.ic_orion).setContentTitle("OrionBeastFx receiver").setContentText(message).setContentIntent(open()).setOngoing(true).addAction(new Notification.Action.Builder(null,"Stop",stop).build()).build();
    }
    public int onStartCommand(Intent intent,int flags,int id){
        if(intent!=null&&"STOP".equals(intent.getAction())){stopSelf();return START_NOT_STICKY;}
        if(Build.VERSION.SDK_INT>=34)startForeground(1,live("Connecting…"),ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE);else startForeground(1,live("Connecting…"));
        if(running)return START_NOT_STICKY;
        running=true;active=true;
        final String server=Store.server(this),topic=Store.topic(this),token=Store.token(this),scope=Store.scope(this);
        worker=new Thread(()->listen(server,topic,token,scope),"ntfy-receiver");worker.start();return START_NOT_STICKY;
    }
    private void update(String s){Store.status(this,s);if(running)notifications.notify(1,live(s));}
    private void listen(String server,String topic,String token,String scope){
        long delay=2000;
        String cursor=Store.prefs(this).getString("cursor:"+scope,"");
        String since=cursor.isEmpty()?Long.toString(System.currentTimeMillis()/1000):cursor;
        while(running){
            HttpURLConnection c=null;
            try{
                update("Connecting");
                URL url=new URL(server+"/"+topic+"/json?since="+URLEncoder.encode(since,"UTF-8"));
                c=(HttpURLConnection)url.openConnection();connection=c;
                c.setConnectTimeout(15000);c.setReadTimeout(90000);c.setInstanceFollowRedirects(false);
                c.setRequestProperty("Accept","application/x-ndjson");if(!token.isEmpty())c.setRequestProperty("Authorization","Bearer "+token);
                int code=c.getResponseCode();if(code!=200)throw new IOException("HTTP "+code);
                update("Connected");delay=2000;
                try(BufferedReader reader=new BufferedReader(new InputStreamReader(c.getInputStream(),"UTF-8"))){
                    String line;
                    while(running&&(line=reader.readLine())!=null){
                        if(line.trim().isEmpty())continue;
                        JSONObject m=new JSONObject(line);if(!"message".equals(m.optString("event")))continue;
                        if(Store.save(this,m,scope))notifyAlert(m);
                        since=m.getString("id");
                    }
                }
                if(running)update("Reconnecting");
            }catch(Exception e){if(running)update("Retrying · "+e.getClass().getSimpleName()+": "+String.valueOf(e.getMessage()));}
            finally{if(c!=null)c.disconnect();connection=null;}
            if(running){try{Thread.sleep(delay);}catch(InterruptedException e){break;}delay=Math.min(60000,delay*2);}
        }
    }
    private void notifyAlert(JSONObject m){
        // Structured state/summary traffic is silent; ordinary signal messages notify.
        try{String type=new JSONObject(m.optString("message")).optString("type");if(type.equals("symbol")||type.equals("snapshot")||type.equals("summary")||type.equals("heartbeat"))return;}catch(JSONException ignored){}
        if(Build.VERSION.SDK_INT>=33&&checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS)!=android.content.pm.PackageManager.PERMISSION_GRANTED)return;
        Notification n=new Notification.Builder(this,ALERTS).setSmallIcon(R.drawable.ic_orion).setContentTitle(m.optString("title","OrionBeastFx · EA alert")).setContentText(m.optString("message")).setStyle(new Notification.BigTextStyle().bigText(m.optString("message"))).setContentIntent(open()).setAutoCancel(true).setVisibility(Notification.VISIBILITY_PRIVATE).build();
        notifications.notify(m.optString("id"),2,n);
    }
    public void onDestroy(){running=false;active=false;if(worker!=null)worker.interrupt();HttpURLConnection c=connection;if(c!=null)c.disconnect();Store.status(this,"Offline");stopForeground(STOP_FOREGROUND_REMOVE);super.onDestroy();}
}
