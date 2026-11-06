package com.orionbeastfx.alerts;
import android.content.*;
import org.json.*;
final class Store {
    static SharedPreferences prefs(Context c) { return c.getSharedPreferences("orion",0); }
    static String topic(Context c) { return prefs(c).getString("topic","OrionBeastFx"); }
    static String server(Context c) { return prefs(c).getString("server","https://ntfy.sh"); }
    static String token(Context c) { return prefs(c).getString("token",""); }
    static String scope(Context c) { return server(c)+"/"+topic(c); }
    static JSONObject state(Context c) { try{return new JSONObject(prefs(c).getString("state:"+scope(c),"{}"));}catch(JSONException e){return new JSONObject();} }
    static JSONArray inbox(Context c) { try{return new JSONArray(prefs(c).getString("inbox:"+scope(c),"[]"));}catch(JSONException e){return new JSONArray();} }
    static synchronized boolean save(Context c,JSONObject m,String scope) throws JSONException {
        SharedPreferences p=prefs(c);
        JSONArray old=new JSONArray(p.getString("inbox:"+scope,"[]"));
        String id=m.getString("id");
        for(int i=0;i<old.length();i++) if(id.equals(old.getJSONObject(i).optString("id"))) return false;
        JSONObject state=new JSONObject(p.getString("state:"+scope,"{}"));
        JSONObject stored=new JSONObject(m.toString()); String body=m.optString("message","").trim();
        if(body.startsWith("{")) {
            try { state=EventReducer.apply(state,new JSONObject(body),m.optLong("time",System.currentTimeMillis()/1000)); stored.put("parsed",true); }
            catch(JSONException ex) {stored.put("parse_error",ex.getMessage());}
        }
        JSONArray next=new JSONArray();next.put(stored);
        for(int i=0;i<Math.min(old.length(),299);i++) next.put(old.getJSONObject(i));
        if(!p.edit().putString("inbox:"+scope,next.toString()).putString("state:"+scope,state.toString()).putString("cursor:"+scope,id).commit()) throw new JSONException("Could not save message to device");
        return true;
    }
    static void status(Context c,String value) { prefs(c).edit().putString("status",value).apply(); }
}
